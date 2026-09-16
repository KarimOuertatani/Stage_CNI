import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/food_model.dart' show MacroPreview;
import '../../data/meal_model.dart';
import '../../data/meal_photo_models.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/analyzed_food_card.dart';
import '../widgets/macro_chip.dart';
import '../widgets/meal_type_chips.dart';
import '../../../../core/widgets/screen_background.dart';

/// Ajout d'un repas **à la voix**.
///
/// Le geste le plus court du module nutrition : l'adhérent appuie, dit
/// « ce midi j'ai mangé deux œufs et une tranche de pain complet », relâche.
///
/// Quatre temps dans un seul écran :
/// 1. **Parler** — un appui maintenu, comme un message vocal ;
/// 2. **Analyser** — le backend transcrit et convertit les unités parlées en
///    grammes ;
/// 3. **Vérifier la transcription** — affichée en tête des résultats, et
///    **modifiable** : c'est le seul moyen de rattraper un mot mal entendu ;
/// 4. **Ajuster et confirmer** — identique à l'analyse de photo.
///
/// > **Rien n'est enregistré tant que l'adhérent n'a pas validé.** L'analyse
/// > est une proposition ; l'écriture passe par le chemin habituel
/// > (`POST /nutrition/from-food`), un appel par aliment retenu.
class MealVoiceScreen extends ConsumerStatefulWidget {
  const MealVoiceScreen({super.key});

  @override
  ConsumerState<MealVoiceScreen> createState() => _MealVoiceScreenState();
}

enum _Step { record, analyzing, results }

class _MealVoiceScreenState extends ConsumerState<MealVoiceScreen> {
  /// Sous cette durée, l'enregistrement est un appui involontaire : rien à
  /// analyser, et l'envoyer coûterait un appel pour rien.
  static const int _minSeconds = 1;

  /// Au-delà, on coupe : une description de repas tient en quelques secondes,
  /// et le quota d'analyse n'est pas illimité.
  static const int _maxSeconds = 60;

  final AudioRecorder _recorder = AudioRecorder();

  _Step _step = _Step.record;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _recordPath;

  VoiceAnalysis? _analysis;
  String? _error;

  /// Mode saisie écrite : repli quand l'audio échoue, et chemin de correction.
  bool _typing = false;
  final TextEditingController _text = TextEditingController();

  MealType _mealType = MealType.lunch;

  /// Quantité retenue par aliment (clé -> grammes), initialisée à l'estimation.
  final Map<String, double> _grams = {};

  /// Aliments cochés. Un aliment non retrouvé au catalogue ne peut pas l'être.
  final Set<String> _selected = {};

  bool _saving = false;
  int _savedCount = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _mealType = _guessMealType();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelToken?.cancel();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Repas proposé par défaut selon l'heure : on évite une sélection à faire
  /// dans 90 % des cas.
  MealType _guessMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 18) return MealType.snack;
    return MealType.dinner;
  }

  // ── Étape 1 : parler ────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      if (!await _recorder.hasPermission()) {
        setState(
          () => _error =
              'Le micro n\'est pas autorisé. Décrivez votre repas par écrit.',
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/repas_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordPath = path;
        _seconds = 0;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        // Coupure automatique : l'adhérent qui oublie de relâcher ne doit pas
        // envoyer trois minutes d'audio.
        if (_seconds >= _maxSeconds) _stopAndAnalyze();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Micro indisponible. Décrivez votre repas par écrit.',
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    HapticFeedback.selectionClick();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _seconds = 0;
      _recordPath = null;
    });
  }

  Future<void> _stopAndAnalyze() async {
    _timer?.cancel();
    final seconds = _seconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recordPath;

    if (!mounted) return;
    setState(() {
      _recording = false;
      _seconds = 0;
      _recordPath = null;
    });

    if (path == null || seconds < _minSeconds) {
      // Appui involontaire : on ne dit rien, on ne dépense rien.
      HapticFeedback.selectionClick();
      return;
    }
    await _analyzeVoice(path);
  }

  // ── Étape 2 : analyser ──────────────────────────────────────────

  Future<void> _analyzeVoice(String path) async {
    setState(() {
      _step = _Step.analyzing;
      _error = null;
    });

    _cancelToken = CancelToken();
    try {
      final analysis = await ref
          .read(nutritionApiProvider)
          .analyzeVoice(
            path,
            filename: File(path).uri.pathSegments.last,
            cancelToken: _cancelToken,
          );
      _applyAnalysis(analysis);
    } catch (e) {
      _handleFailure(e, offerTyping: true);
    }
  }

  Future<void> _analyzeText() async {
    final description = _text.text.trim();
    if (description.length < 3) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _step = _Step.analyzing;
      _error = null;
    });

    _cancelToken = CancelToken();
    try {
      final analysis = await ref
          .read(nutritionApiProvider)
          .analyzeText(description, cancelToken: _cancelToken);
      _applyAnalysis(analysis);
    } catch (e) {
      _handleFailure(e, offerTyping: false);
    }
  }

  void _applyAnalysis(VoiceAnalysis analysis) {
    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      _typing = false;
      // La transcription alimente le champ texte : corriger un mot mal
      // entendu et relancer devient un geste, pas une ressaisie.
      _text.text = analysis.transcript ?? _text.text;
      _grams
        ..clear()
        ..addEntries(
          analysis.foods.map((f) => MapEntry(f.key, f.quantityGrams)),
        );
      _selected
        ..clear()
        // Tout ce qui est exploitable est coché d'emblée : décocher est plus
        // rapide que cocher, et le cas courant est « tout ajouter ».
        ..addAll(analysis.foods.where((f) => f.matched).map((f) => f.key));
      _step = _Step.results;
    });
  }

  /// En cas d'échec de la voie audio, on bascule sur la saisie écrite plutôt
  /// que de laisser l'adhérent devant un message d'erreur sans issue.
  void _handleFailure(Object e, {required bool offerTyping}) {
    if (e is DioException && CancelToken.isCancel(e)) return;
    if (!mounted) return;
    setState(() {
      _error = _messageFrom(e);
      _step = _Step.record;
      if (offerTyping) _typing = true;
    });
  }

  /// Message lisible : on privilégie celui renvoyé par le backend (quota,
  /// analyse non configurée, enregistrement refusé…).
  String _messageFrom(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        return "L'analyse a pris trop de temps. Réessayez plus brièvement.";
      }
      return "L'analyse a échoué. Vérifiez votre connexion.";
    }
    return e.toString();
  }

  // ── Étape 4 : confirmer ─────────────────────────────────────────

  Future<void> _addSelected() async {
    final analysis = _analysis;
    if (analysis == null || _saving) return;

    final chosen = analysis.foods
        .where((f) => _selected.contains(f.key))
        .toList();
    if (chosen.isEmpty) return;

    setState(() {
      _saving = true;
      _savedCount = 0;
    });
    HapticFeedback.mediumImpact();

    final notifier = ref.read(nutritionProvider.notifier);
    final failures = <String>[];

    // Un appel par aliment : c'est le contrat de /from-food, et cela garde le
    // calcul des macros côté serveur pour chaque ligne du journal.
    for (final food in chosen) {
      final error = await notifier.addFoodEntry(
        food: food.toFoodSearchResult(),
        type: _mealType,
        grams: _grams[food.key] ?? food.quantityGrams,
      );
      if (!mounted) return;
      if (error != null) {
        failures.add(food.foodName ?? food.detectedLabel);
      } else {
        setState(() => _savedCount++);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    final added = chosen.length - failures.length;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: failures.isEmpty ? AppColors.card : AppColors.error,
          content: Text(
            failures.isEmpty
                ? '$added aliment${added > 1 ? 's' : ''} ajouté${added > 1 ? 's' : ''} à ${mealTypeLabel(_mealType).toLowerCase()}'
                : '$added ajouté(s), ${failures.length} en échec : ${failures.first}',
          ),
        ),
      );
  }

  // ── Totaux vivants ──────────────────────────────────────────────

  MacroPreview get _total {
    final analysis = _analysis;
    if (analysis == null) {
      return const MacroPreview(calories: 0, protein: 0, carbs: 0, fat: 0);
    }
    var calories = 0;
    var protein = 0.0, carbs = 0.0, fat = 0.0, fiber = 0.0;
    for (final food in analysis.foods) {
      if (!_selected.contains(food.key)) continue;
      final preview = food.previewFor(_grams[food.key] ?? food.quantityGrams);
      calories += preview.calories;
      protein += preview.protein;
      carbs += preview.carbs;
      fat += preview.fat;
      fiber += preview.fiber ?? 0;
    }
    return MacroPreview(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
    );
  }

  // ── Construction ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dire mon repas'),
        actions: [
          if (_step == _Step.results)
            IconButton(
              tooltip: 'Recommencer',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _step = _Step.record;
                      _typing = false;
                    }),
            ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            child: switch (_step) {
              _Step.record => _recordStep(),
              _Step.analyzing => _analyzingStep(),
              _Step.results => _resultsStep(),
            },
          ),
        ),
      ),
    );
  }

  // ── Vue : parler ────────────────────────────────────────────────

  Widget _recordStep() {
    return SingleChildScrollView(
      key: const ValueKey('record'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 20),
          ],
          Text(
            _recording ? 'Je vous écoute…' : 'Dites ce que vous avez mangé',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _recording
                ? 'Relâchez pour analyser, glissez sur la croix pour annuler.'
                : 'Maintenez le micro et parlez normalement. Les quantités '
                      'parlées sont converties en grammes.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _MicButton(
            recording: _recording,
            seconds: _seconds,
            maxSeconds: _maxSeconds,
            onStart: _startRecording,
            onStop: _stopAndAnalyze,
            onCancel: _cancelRecording,
          ),
          const SizedBox(height: 30),
          if (!_recording) ...[
            if (_typing) _textEntry() else _switchToTyping(),
            const SizedBox(height: 24),
            const _ExampleCard(),
          ],
        ],
      ),
    );
  }

  Widget _switchToTyping() {
    return TextButton.icon(
      onPressed: () => setState(() => _typing = true),
      icon: const Icon(Icons.keyboard_rounded, size: 18),
      label: const Text('Écrire plutôt que parler'),
      style: TextButton.styleFrom(foregroundColor: AppColors.accentText),
    );
  }

  Widget _textEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _text,
          label: 'Décrivez votre repas',
          hint: 'ex : deux œufs, une tranche de pain complet et un yaourt',
          accentColor: AppColors.accent,
          maxLines: 3,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Analyser',
          icon: Icons.auto_awesome_rounded,
          gradient: AppColors.accentGradient,
          glowColor: AppColors.accent,
          onPressed: _analyzeText,
        ),
      ],
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.08);
  }

  // ── Vue : analyse en cours ──────────────────────────────────────

  Widget _analyzingStep() {
    return Padding(
      key: const ValueKey('analyzing'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SoundWave(),
          const SizedBox(height: 30),
          Text('Analyse en cours…', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Transcription, puis recherche des valeurs nutritionnelles.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vue : résultats ─────────────────────────────────────────────

  Widget _resultsStep() {
    final analysis = _analysis!;

    if (analysis.isEmpty) {
      return _EmptyResult(
        key: const ValueKey('empty'),
        title: 'Aucun aliment compris',
        transcript: analysis.transcript,
        message: analysis.transcript == null
            ? 'Rien n\'a été entendu. Réessayez dans un endroit plus calme, '
                  'ou décrivez votre repas par écrit.'
            : 'Voici ce qui a été entendu. Corrigez le texte et relancez : '
                  'nommez chaque aliment, par exemple « deux œufs, du riz ».',
        onRetry: () => setState(() {
          _step = _Step.record;
          _typing = analysis.transcript != null;
        }),
      );
    }

    if (analysis.detectedButNoneMatched) {
      return _EmptyResult(
        key: const ValueKey('nomatch'),
        title: 'Aliments non reconnus',
        transcript: analysis.transcript,
        message:
            '${analysis.foods.length} aliment(s) compris, mais aucun n\'a été '
            'retrouvé dans la base nutritionnelle. Essayez des noms plus '
            'génériques, ou utilisez la saisie manuelle.',
        onRetry: () => setState(() {
          _step = _Step.record;
          _typing = true;
        }),
      );
    }

    final total = _total;
    final selectedCount = _selected.length;

    return Column(
      key: const ValueKey('results'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              if (analysis.transcript != null)
                _TranscriptCard(
                  transcript: analysis.transcript!,
                  onEdit: () => setState(() {
                    _step = _Step.record;
                    _typing = true;
                  }),
                ),
              const SizedBox(height: 16),
              _TotalCard(total: total, count: selectedCount),
              const SizedBox(height: 18),
              Text('Ajouter à', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              MealTypeChips(
                selected: _mealType,
                onChanged: (t) => setState(() => _mealType = t),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.restaurant_rounded,
                    size: 15,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Aliments compris (${analysis.foods.length})',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < analysis.foods.length; i++)
                AnalyzedFoodCard(
                      food: analysis.foods[i],
                      grams:
                          _grams[analysis.foods[i].key] ??
                          analysis.foods[i].quantityGrams,
                      selected: _selected.contains(analysis.foods[i].key),
                      onToggle: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          final key = analysis.foods[i].key;
                          if (!_selected.remove(key)) _selected.add(key);
                        });
                      },
                      onGramsChanged: (g) =>
                          setState(() => _grams[analysis.foods[i].key] = g),
                    )
                    .animate()
                    .fadeIn(delay: (i * 60).ms, duration: 280.ms)
                    .slideY(begin: 0.06),
            ],
          ),
        ),
        _confirmBar(selectedCount, total),
      ],
    );
  }

  Widget _confirmBar(int count, MacroPreview total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: PrimaryButton(
          label: _saving
              ? 'Ajout $_savedCount/$count…'
              : count == 0
              ? 'Sélectionnez au moins un aliment'
              : 'Ajouter $count aliment${count > 1 ? 's' : ''} · ${total.calories} kcal',
          icon: Icons.check_rounded,
          gradient: AppColors.accentGradient,
          glowColor: AppColors.accent,
          isLoading: _saving,
          onPressed: (count == 0 || _saving) ? null : _addSelected,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Le bouton micro — appui maintenu
// ═════════════════════════════════════════════════════════════════════

/// Appui **maintenu**, comme un message vocal : le geste est déjà connu de
/// tout le monde, et il rend l'annulation naturelle (on relâche sans avoir
/// rien dit). Pendant l'enregistrement, une croix apparaît à côté pour
/// abandonner franchement.
class _MicButton extends StatelessWidget {
  final bool recording;
  final int seconds;
  final int maxSeconds;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _MicButton({
    required this.recording,
    required this.seconds,
    required this.maxSeconds,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  String get _timeLabel {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Annulation : présente seulement pendant l'enregistrement, pour
            // ne pas encombrer l'écran au repos.
            SizedBox(
              width: 56,
              child: recording
                  ? IconButton(
                      onPressed: onCancel,
                      tooltip: 'Annuler',
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.errorText,
                        size: 26,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(
                          alpha: 0.12,
                        ),
                        minimumSize: const Size(48, 48),
                      ),
                    ).animate().fadeIn(duration: 180.ms).scale()
                  : null,
            ),
            const SizedBox(width: 18),
            GestureDetector(
                  onTapDown: (_) => onStart(),
                  onTapUp: (_) => onStop(),
                  onTapCancel: onStop,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: recording ? 116 : 104,
                    height: recording ? 116 : 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: recording ? 0.55 : 0.35,
                          ),
                          blurRadius: recording ? 34 : 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      size: 46,
                      color: AppColors.onGradient,
                    ),
                  ),
                )
                .animate(
                  target: recording ? 1 : 0,
                  onPlay: (c) => recording ? c.repeat(reverse: true) : null,
                )
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 700.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(width: 18),
            const SizedBox(width: 56),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: recording ? 1 : 0,
          child: Column(
            children: [
              Text(
                _timeLabel,
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.accentText,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (seconds / maxSeconds).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Analyse en cours — ondes sonores
// ═════════════════════════════════════════════════════════════════════

class _SoundWave extends StatefulWidget {
  const _SoundWave();

  @override
  State<_SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<_SoundWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bars = 7;
    return SizedBox(
      height: 72,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(bars, (i) {
            // Décalage de phase par barre : le mouvement se lit comme une
            // onde qui traverse, pas comme sept barres qui clignotent.
            final phase = (_ctrl.value + i / bars) % 1.0;
            final height = 14 + 44 * (0.5 - (phase - 0.5).abs()) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  La transcription
// ═════════════════════════════════════════════════════════════════════

/// Ce que le serveur a entendu, affiché **en tête** des résultats.
///
/// C'est la pièce maîtresse du mode vocal : sans elle, un mot mal compris
/// (« du blé » entendu « du bled ») produit un résultat inexplicable. Avec
/// elle, l'adhérent voit immédiatement d'où vient l'erreur et la corrige.
class _TranscriptCard extends StatelessWidget {
  final String transcript;
  final VoidCallback onEdit;

  const _TranscriptCard({required this.transcript, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.record_voice_over_rounded,
            size: 18,
            color: AppColors.accentText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ce qui a été entendu',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '« $transcript »',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Corriger le texte',
            icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Total vivant
// ═════════════════════════════════════════════════════════════════════

class _TotalCard extends StatelessWidget {
  final MacroPreview total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: AppColors.isDark ? 0.18 : 0.12),
            AppColors.primary.withValues(alpha: AppColors.isDark ? 0.14 : 0.09),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Row(
              key: ValueKey(total.calories),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${total.calories}',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'kcal',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count == 0
                ? 'Aucun aliment sélectionné'
                : '$count aliment${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          MacroChipRow(
            protein: total.protein,
            carbs: total.carbs,
            fat: total.fat,
            fiber: total.fiber,
            compact: false,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  États annexes
// ═════════════════════════════════════════════════════════════════════

class _EmptyResult extends StatelessWidget {
  final String title;
  final String message;
  final String? transcript;
  final VoidCallback onRetry;

  const _EmptyResult({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.transcript,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.mic_off_rounded,
              size: 32,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          if (transcript != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '« $transcript »',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Recommencer',
            icon: Icons.mic_rounded,
            gradient: AppColors.accentGradient,
            glowColor: AppColors.accent,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Exemples de phrases — c'est ce qui fait le plus varier la qualité du
/// résultat, bien avant le modèle lui-même.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard();

  @override
  Widget build(BuildContext context) {
    const examples = [
      'Deux œufs brouillés et une tranche de pain complet',
      'Un bol de riz, du blanc de poulet et des brocolis',
      'Un yaourt nature avec une banane',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                size: 16,
                color: AppColors.accentText,
              ),
              const SizedBox(width: 8),
              Text(
                'Par exemple',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final example in examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textHint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '« $example »',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
