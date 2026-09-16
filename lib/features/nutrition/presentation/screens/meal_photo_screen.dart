import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/food_model.dart' show MacroPreview;
import '../../data/meal_model.dart';
import '../../data/meal_photo_models.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/analyzed_food_card.dart';
import '../widgets/macro_chip.dart';
import '../widgets/meal_type_chips.dart';
import '../../../../core/widgets/screen_background.dart';

/// Analyse d'une photo de repas.
///
/// Parcours en trois temps, dans un seul écran :
/// 1. **Choisir** une photo (appareil ou galerie) ;
/// 2. **Analyser** — le backend interroge Gemini puis retrouve les macros ;
/// 3. **Ajuster et confirmer** — l'adhérent corrige les quantités estimées,
///    décoche ce qu'il ne veut pas, puis valide.
///
/// > **Rien n'est enregistré tant que l'adhérent n'a pas validé.** L'analyse
/// > est une proposition ; l'écriture passe par le chemin habituel
/// > (`POST /nutrition/from-food`), un appel par aliment retenu. Une estimation
/// > automatique ne doit jamais s'imposer au journal de quelqu'un.
class MealPhotoScreen extends ConsumerStatefulWidget {
  const MealPhotoScreen({super.key});

  @override
  ConsumerState<MealPhotoScreen> createState() => _MealPhotoScreenState();
}

enum _Step { pick, analyzing, results }

class _MealPhotoScreenState extends ConsumerState<MealPhotoScreen> {
  _Step _step = _Step.pick;

  File? _photo;
  PhotoAnalysis? _analysis;
  String? _error;

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
    _cancelToken?.cancel();
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

  // ── Étape 1 : choisir une photo ─────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // On compresse avant l'envoi : inutile de faire transiter 8 Mo pour
        // une analyse qui n'a besoin que de reconnaître des aliments.
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _photo = File(picked.path);
        _error = null;
      });
      await _analyze();
    } catch (e) {
      if (mounted) setState(() => _error = 'Photo indisponible : $e');
    }
  }

  // ── Étape 2 : analyser ──────────────────────────────────────────

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) return;

    setState(() {
      _step = _Step.analyzing;
      _error = null;
    });

    _cancelToken = CancelToken();
    try {
      final analysis = await ref
          .read(nutritionApiProvider)
          .analyzePhoto(
            photo.path,
            filename: photo.uri.pathSegments.last,
            cancelToken: _cancelToken,
          );
      if (!mounted) return;

      setState(() {
        _analysis = analysis;
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
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || !mounted) return;
      setState(() {
        _error = _messageFrom(e);
        _step = _Step.pick;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFrom(e);
        _step = _Step.pick;
      });
    }
  }

  /// Message lisible : on privilégie celui renvoyé par le backend (quota,
  /// analyse non configurée, image refusée…).
  String _messageFrom(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        return "L'analyse a pris trop de temps. Réessayez avec une photo plus nette.";
      }
      return "L'analyse a échoué. Vérifiez votre connexion.";
    }
    return e.toString();
  }

  // ── Étape 3 : confirmer ─────────────────────────────────────────

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
        title: const Text('Analyser une photo'),
        actions: [
          if (_step == _Step.results)
            IconButton(
              tooltip: 'Reprendre une photo',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _saving
                  ? null
                  : () => setState(() => _step = _Step.pick),
            ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            child: switch (_step) {
              _Step.pick => _pickStep(),
              _Step.analyzing => _analyzingStep(),
              _Step.results => _resultsStep(),
            },
          ),
        ),
      ),
    );
  }

  // ── Vue : choix de la photo ─────────────────────────────────────

  Widget _pickStep() {
    return SingleChildScrollView(
      key: const ValueKey('pick'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 20),
          ],
          Center(
            child:
                Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.accentGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 26,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.center_focus_strong_rounded,
                        size: 46,
                        color: AppColors.onGradient,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.06, 1.06),
                      duration: 1600.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          const SizedBox(height: 22),
          Text(
            'Photographiez votre assiette',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Les aliments sont identifiés automatiquement, avec une estimation '
            'des quantités et des macros. Vous corrigez avant d\'enregistrer.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Prendre une photo',
            icon: Icons.photo_camera_rounded,
            gradient: AppColors.accentGradient,
            glowColor: AppColors.accent,
            onPressed: () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded, size: 20),
            label: const Text('Choisir dans la galerie'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _TipCard(),
        ],
      ),
    );
  }

  // ── Vue : analyse en cours ──────────────────────────────────────

  Widget _analyzingStep() {
    return Padding(
      key: const ValueKey('analyzing'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_photo != null) _ScanningPhoto(photo: _photo!),
          const SizedBox(height: 30),
          Text('Analyse en cours…', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Identification des aliments, puis recherche de leurs valeurs '
            'nutritionnelles.',
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
        title: 'Aucun aliment détecté',
        message:
            'La photo n\'a pas permis d\'identifier d\'aliment. Essayez une '
            'vue de dessus, bien éclairée, avec les aliments séparés.',
        onRetry: () => setState(() => _step = _Step.pick),
      );
    }

    if (analysis.detectedButNoneMatched) {
      return _EmptyResult(
        key: const ValueKey('nomatch'),
        title: 'Aliments non reconnus',
        message:
            '${analysis.foods.length} aliment(s) repéré(s) sur la photo, mais '
            'aucun n\'a été retrouvé dans la base nutritionnelle. '
            'Utilisez la saisie manuelle pour les enregistrer.',
        onRetry: () => setState(() => _step = _Step.pick),
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
              _PhotoStrip(photo: _photo, analysis: analysis),
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
                    'Aliments détectés (${analysis.foods.length})',
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
//  Photo en cours d'analyse — balayage lumineux
// ═════════════════════════════════════════════════════════════════════

class _ScanningPhoto extends StatefulWidget {
  final File photo;
  const _ScanningPhoto({required this.photo});

  @override
  State<_ScanningPhoto> createState() => _ScanningPhotoState();
}

class _ScanningPhotoState extends State<_ScanningPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(widget.photo, fit: BoxFit.cover),
            // Voile sombre : le balayage doit rester lisible sur une photo
            // claire comme sur une photo foncée.
            Container(color: Colors.black.withValues(alpha: 0.25)),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Align(
                alignment: Alignment(0, -1 + 2 * _ctrl.value),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0),
                        AppColors.accent,
                        AppColors.accent.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.8),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Bandeau photo + compteur
// ═════════════════════════════════════════════════════════════════════

class _PhotoStrip extends StatelessWidget {
  final File? photo;
  final PhotoAnalysis analysis;
  const _PhotoStrip({required this.photo, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(photo!, width: 72, height: 72, fit: BoxFit.cover),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Proposition d\'analyse',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${analysis.matchedCount} aliment(s) reconnu(s) sur '
                '${analysis.foods.length}. Ajustez avant d\'enregistrer.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
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
  final VoidCallback onRetry;

  const _EmptyResult({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
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
              Icons.no_photography_rounded,
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Réessayer avec une autre photo',
            icon: Icons.photo_camera_rounded,
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

/// Conseils de prise de vue — c'est ce qui fait le plus varier la qualité de
/// la détection, bien avant le modèle lui-même.
class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tips = [
      'Cadrez de dessus, l\'assiette entière visible',
      'Séparez les aliments plutôt que de les empiler',
      'Évitez le contre-jour et les ombres dures',
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
                'Pour un meilleur résultat',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final tip in tips)
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
                      tip,
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
