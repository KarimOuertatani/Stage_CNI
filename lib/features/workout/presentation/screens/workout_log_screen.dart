import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/last_performance.dart';
import '../../data/workout_log_args.dart';
import '../../data/workout_model.dart';
import '../providers/workout_provider.dart';
import '../providers/active_session_provider.dart';
import '../widgets/exercise_detail_sheet.dart';
import '../widgets/exercise_visuals.dart';
import '../../../../core/widgets/screen_background.dart';

/// Écran de logging de séance — l'écran le plus utilisé de l'app.
///
/// Objectif : friction minimale. Steppers reps/charge à gros boutons,
/// validation de série en un tap (haptique + animation), minuteur de repos
/// automatique, RPE en fin de séance.
///
/// ## Trois choses qu'il ne savait pas faire
///
/// 1. **Revoir l'exercice.** Aucun accès à la vidéo ni aux instructions depuis
///    ici : un doute sur la position obligeait à quitter l'écran — et à perdre
///    le chrono, le repos et les séries validées. La vignette du titre ouvre
///    désormais la fiche en feuille modale, par-dessus, sans rien interrompre.
/// 2. **Respecter le programme.** L'écran ouvrait 4 × 10 à 20 kg pour tout le
///    monde, en ignorant la prescription du programme d'où l'on venait.
/// 3. **Se souvenir.** Rien ne rappelait la dernière performance sur
///    l'exercice, alors qu'elle est la seule référence utile au moment de
///    charger la barre.
///
/// Les valeurs de départ suivent donc un ordre de priorité explicite :
/// **prescription du programme → dernière performance → valeurs par défaut**.
/// Le programme d'abord parce qu'il est une intention (progresser), la dernière
/// séance ensuite parce qu'elle est un constat.
class WorkoutLogScreen extends ConsumerStatefulWidget {
  final String exerciseId;

  /// Contexte de programme, quand l'écran est ouvert depuis une séance.
  final WorkoutLogArgs? args;

  const WorkoutLogScreen({super.key, required this.exerciseId, this.args});

  @override
  ConsumerState<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _SetEntry {
  int reps;
  double weight;
  bool done = false;

  _SetEntry({required this.reps, required this.weight});
}

class _WorkoutLogScreenState extends ConsumerState<WorkoutLogScreen> {
  final List<_SetEntry> _sets = [];
  int _rpe = 7;

  /// Vrai tant que les séries n'ont pas été ajustées sur la dernière
  /// performance. Elle arrive en asynchrone, après le premier rendu : sans ce
  /// garde-fou, elle écraserait des valeurs déjà modifiées à la main.
  bool _awaitingLastPerformance = true;

  // ── Chrono séance ─────────────────────────────────────────────
  late final DateTime _startedAt;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  // ── Minuteur de repos ─────────────────────────────────────────
  Timer? _restTimer;
  int _restRemaining = 0;

  /// 90 s est la valeur par défaut du logging libre ; un programme qui prescrit
  /// son propre temps de repos l'emporte.
  static const _restFallback = 90;
  int get _restDuration =>
      widget.args?.current?.restSeconds ?? _restFallback;

  ProgramExerciseTarget? get _target => widget.args?.current;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt));
      }
    });
    _seedSets();
  }

  /// Séries de départ : la prescription du programme si elle existe, sinon
  /// quatre séries neutres que la dernière performance viendra ajuster.
  void _seedSets() {
    final target = _target;
    final count = target?.sets ?? 4;
    final reps = target?.reps ?? 10;
    final weight = target?.weightKg ?? 20;
    for (var i = 0; i < count; i++) {
      _sets.add(_SetEntry(reps: reps, weight: weight));
    }
    // Un programme qui prescrit déjà la charge n'a pas à être corrigé par
    // l'historique : la prescription est la consigne du jour.
    if (target?.weightKg != null && target?.reps != null) {
      _awaitingLastPerformance = false;
    }
  }

  /// Reprend la dernière séance réalisée sur cet exercice.
  ///
  /// N'écrase QUE des valeurs intactes ([_awaitingLastPerformance]) et jamais
  /// une série déjà validée : voir sa saisie changer toute seule est la pire
  /// chose qui puisse arriver dans un carnet d'entraînement.
  void _applyLastPerformance(LastPerformance last) {
    if (!_awaitingLastPerformance || last.sets.isEmpty) return;
    if (_sets.any((s) => s.done)) return;

    setState(() {
      _awaitingLastPerformance = false;
      _sets
        ..clear()
        ..addAll([
          for (final s in last.sets)
            _SetEntry(reps: s.reps ?? 10, weight: s.weightKg ?? 20),
        ]);
      // Le programme fait foi sur le NOMBRE de séries : s'il en demande cinq et
      // que la dernière fois on en a fait quatre, c'est cinq qu'il faut afficher.
      final wanted = _target?.sets;
      if (wanted != null && wanted > _sets.length) {
        final last = _sets.isNotEmpty ? _sets.last : null;
        while (_sets.length < wanted) {
          _sets.add(
            _SetEntry(reps: last?.reps ?? 10, weight: last?.weight ?? 20),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────────

  void _toggleSet(int index) {
    final set = _sets[index];
    setState(() {
      set.done = !set.done;
      // Dès la première série validée, l'historique n'a plus à intervenir.
      _awaitingLastPerformance = false;
    });
    if (set.done) {
      HapticFeedback.mediumImpact();
      // Duplique automatiquement les valeurs sur la série suivante non faite.
      if (index + 1 < _sets.length && !_sets[index + 1].done) {
        _sets[index + 1]
          ..reps = set.reps
          ..weight = set.weight;
      }
      final isLast = _sets.every((s) => s.done);
      if (!isLast) _startRest();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _startRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = _restDuration);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _restRemaining--);
      if (_restRemaining <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _restRemaining = 0);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _restRemaining = 0);
  }

  void _extendRest() {
    HapticFeedback.selectionClick();
    setState(() => _restRemaining += 30);
  }

  void _addSet() {
    HapticFeedback.selectionClick();
    final last = _sets.isNotEmpty ? _sets.last : null;
    setState(() {
      _awaitingLastPerformance = false;
      _sets.add(_SetEntry(reps: last?.reps ?? 10, weight: last?.weight ?? 20));
    });
  }

  void _removeSet(int index) {
    HapticFeedback.selectionClick();
    setState(() => _sets.removeAt(index));
  }

  /// Ouvre la fiche de l'exercice PAR-DESSUS l'écran : le chrono continue, le
  /// repos continue, les séries validées restent validées.
  void _openDetail() {
    HapticFeedback.selectionClick();
    showExerciseDetailSheet(context, exerciseId: widget.exerciseId);
  }

  int get _completedCount => _sets.where((s) => s.done).length;

  double get _totalVolume =>
      _sets.where((s) => s.done).fold(0.0, (sum, s) => sum + s.reps * s.weight);

  /// Termine l'EXERCICE (pas la séance) : ses séries validées sont ajoutées à
  /// la séance en cours, puis on enchaîne — l'exercice suivant du programme
  /// s'il en reste un, sinon retour à l'écran précédent.
  void _finishExercise(WorkoutModel exercise) {
    HapticFeedback.heavyImpact();
    _restTimer?.cancel();

    final sets = <SetDraft>[
      for (final s in _sets)
        SetDraft(reps: s.reps, weightKg: s.weight, completed: s.done),
    ];
    ref.read(activeSessionProvider.notifier).addExercise(exercise, sets, _rpe);

    final args = widget.args;
    final next = args?.next;
    if (next != null) {
      // On REMPLACE l'écran courant : enchaîner huit exercices ne doit pas
      // empiler huit écrans de saisie derrière soi.
      context.pushReplacement(
        '/workout/log/${next.exerciseId}',
        extra: args!.forNext(),
      );
      return;
    }

    final count = ref.read(activeSessionProvider).exerciseCount;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          content: Text(
            'Exercice ajouté à la séance ($count) — terminez la séance depuis l\'onglet Séances.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onGradient,
            ),
          ),
        ),
      );
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/workout');
    }
  }

  String _formatElapsed() {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(exerciseDetailProvider(widget.exerciseId));

    // La dernière performance arrive après coup : on l'applique dès qu'elle
    // est là, sans reconstruire l'écran pour l'attendre.
    ref.listen(lastPerformanceProvider(widget.exerciseId), (_, next) {
      final value = next.value;
      if (value != null) _applyLastPerformance(value);
    });

    return detail.when(
      // Le catalogue peut ne pas être chargé (lien direct, app relancée) :
      // on interroge alors l'exercice à l'unité au lieu d'afficher
      // « Exercice introuvable », qui était un cul-de-sac.
      data: (exercise) => _scaffold(exercise),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        body: ScreenBackground(
          child: SafeArea(
            child: AppErrorState(
              message: 'Impossible de charger cet exercice.',
              onRetry: () =>
                  ref.invalidate(exerciseDetailProvider(widget.exerciseId)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaffold(WorkoutModel exercise) {
    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(exercise),
              _buildRestBanner(),
              Expanded(child: _buildSetsList(exercise)),
              _buildBottomBar(exercise),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(WorkoutModel exercise) {
    final sessionTitle = widget.args?.sessionTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.go('/workout');
            },
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
              size: 26,
            ),
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            tooltip: 'Abandonner',
          ),
          // La vignette est le raccourci principal vers la fiche : c'est la
          // zone qu'on regarde en cherchant « à quoi ça ressemble déjà ? ».
          GestureDetector(
            onTap: _openDetail,
            child: ExerciseThumbnail(exercise: exercise, size: 46),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _openDetail,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      NeonBadge(
                        label: exercise.muscleGroup,
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                      if (sessionTitle != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            sessionTitle,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Bouton explicite en plus de la vignette : tout le monde ne devine
          // pas qu'une image est cliquable, et l'information est trop utile
          // pour dépendre d'une découverte.
          IconButton(
            onPressed: _openDetail,
            icon: Icon(
              Icons.play_circle_outline_rounded,
              color: AppColors.accentText,
              size: 25,
            ),
            tooltip: 'Revoir la démonstration',
          ),
          _ElapsedChip(label: _formatElapsed()),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1);
  }

  Widget _buildRestBanner() {
    final resting = _restRemaining > 0;
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: resting
          ? Container(
                  margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _restRemaining / _restDuration,
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppColors.onGradient.withValues(
                                alpha: 0.25,
                              ),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.onGradient,
                              ),
                            ),
                            Text(
                              '$_restRemaining',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.onGradient,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Repos en cours…',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.onGradient,
                          ),
                        ),
                      ),
                      _RestAction(label: '+30s', onTap: _extendRest),
                      const SizedBox(width: 8),
                      _RestAction(label: 'Passer', onTap: _skipRest),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.3, curve: Curves.easeOutBack)
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _buildSetsList(WorkoutModel exercise) {
    final target = _target;
    final lastAsync = ref.watch(lastPerformanceProvider(widget.exerciseId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        // Objectif du programme et dernière performance : la consigne du jour
        // au-dessus, le repère d'hier en dessous.
        if (target != null && target.hasTargets) ...[
          _TargetBanner(target: target),
          const SizedBox(height: 10),
        ],
        if (lastAsync.value != null) ...[
          _LastPerformanceBanner(last: lastAsync.value!),
          const SizedBox(height: 14),
        ],

        // En-têtes colonnes
        Padding(
          padding: const EdgeInsets.only(left: 52, right: 60, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'RÉPS',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CHARGE (KG)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < _sets.length; i++)
          _SetRow(
                key: ValueKey('set_$i'),
                index: i,
                entry: _sets[i],
                onToggle: () => _toggleSet(i),
                onRepsChanged: (v) => setState(() => _sets[i].reps = v),
                onWeightChanged: (v) => setState(() => _sets[i].weight = v),
                onRemove: _sets.length > 1 ? () => _removeSet(i) : null,
              )
              .animate()
              .fadeIn(delay: (60 * i).ms, duration: 350.ms)
              .slideY(begin: 0.08),
        const SizedBox(height: 4),

        // Ajouter une série
        TextButton.icon(
          onPressed: _addSet,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Ajouter une série'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentText,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 12),

        // RPE
        Text(
          'Effort perçu (RPE)',
          style: AppTextStyles.titleMedium,
        ).animate().fadeIn(delay: 350.ms),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var r = 5; r <= 10; r++)
              _RpeChip(
                value: r,
                selected: _rpe == r,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rpe = r);
                },
              ),
          ],
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 12),

        // Rappel discret vers la fiche, en bas de liste : c'est là qu'on
        // arrive quand on cherche « comment on fait, déjà ? ».
        Center(
          child: TextButton.icon(
            onPressed: _openDetail,
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: Text('Revoir « ${exercise.name} »'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBottomBar(WorkoutModel exercise) {
    final canFinish = _completedCount > 0;
    final next = widget.args?.next;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_completedCount/${_sets.length} séries validées',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              Text(
                'Volume : ${_totalVolume.toStringAsFixed(0)} kg',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            // Le libellé dit ce qui va se passer : dans une séance de
            // programme, valider n'est pas une fin mais un passage.
            label: next == null
                ? 'Terminer l\'exercice'
                : 'Suivant : ${next.exerciseName}',
            icon: next == null
                ? Icons.check_circle_outline_rounded
                : Icons.arrow_forward_rounded,
            onPressed: canFinish ? () => _finishExercise(exercise) : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bandeaux d'information
// ─────────────────────────────────────────────────────────────────────────────

/// Ce que le programme prescrit pour cet exercice, plus la consigne du coach.
class _TargetBanner extends StatelessWidget {
  final ProgramExerciseTarget target;

  const _TargetBanner({required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primary.withValues(alpha: AppColors.isDark ? 0.14 : 0.09),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 16, color: AppColors.primaryText),
              const SizedBox(width: 8),
              Text(
                'Objectif du programme',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
              const Spacer(),
              Text(
                target.summary,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (target.notes != null && target.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 14,
                  color: AppColors.primaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    target.notes!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: -0.08);
  }
}

/// La dernière séance réalisée sur cet exercice : le repère de progression.
class _LastPerformanceBanner extends StatelessWidget {
  final LastPerformance last;

  const _LastPerformanceBanner({required this.last});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 17, color: AppColors.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dernière fois (${last.whenLabel})',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(last.summary, style: AppTextStyles.labelMedium),
              ],
            ),
          ),
          Text(
            '${last.totalVolumeKg.toStringAsFixed(0)} kg',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms);
  }
}

/// Chrono de séance, format tabulaire pour qu'il ne « saute » pas.
class _ElapsedChip extends StatelessWidget {
  final String label;

  const _ElapsedChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: AppColors.accentText),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne de série
// ─────────────────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  final int index;
  final _SetEntry entry;
  final VoidCallback onToggle;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback? onRemove;

  const _SetRow({
    super.key,
    required this.index,
    required this.entry,
    required this.onToggle,
    required this.onRepsChanged,
    required this.onWeightChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final done = entry.done;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: done
            ? AppColors.success.withValues(
                alpha: AppColors.isDark ? 0.08 : 0.10,
              )
            : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.border,
        ),
        boxShadow: done
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.12),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Numéro de série
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.glassWhite,
              border: Border.all(
                color: done
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: AppTextStyles.labelMedium.copyWith(
                color: done ? AppColors.successText : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Steppers
          Expanded(
            child: _Stepper(
              value: entry.reps.toString(),
              enabled: !done,
              onMinus: entry.reps > 1
                  ? () => onRepsChanged(entry.reps - 1)
                  : null,
              onPlus: () => onRepsChanged(entry.reps + 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Stepper(
              value: entry.weight % 1 == 0
                  ? entry.weight.toStringAsFixed(0)
                  : entry.weight.toStringAsFixed(1),
              enabled: !done,
              onMinus: entry.weight > 2.5
                  ? () => onWeightChanged(entry.weight - 2.5)
                  : null,
              onPlus: () => onWeightChanged(entry.weight + 2.5),
            ),
          ),
          const SizedBox(width: 6),

          // Check
          GestureDetector(
            onTap: onToggle,
            onLongPress: onRemove,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? AppColors.successGradient : null,
                color: done ? null : AppColors.glassWhite,
                border: done
                    ? null
                    : Border.all(color: AppColors.border, width: 1.5),
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 24,
                color: done ? const Color(0xFF063018) : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String value;
  final bool enabled;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _Stepper({
    required this.value,
    required this.enabled,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _StepperButton(
              icon: Icons.remove_rounded,
              onTap: enabled ? onMinus : null,
            ),
            // Deux compteurs côte à côte ne laissent qu'une quarantaine de
            // pixels au chiffre : « 10 » et « 75 » passaient à la ligne, un
            // caractère par ligne. `FittedBox` + `softWrap: false` garantissent
            // une seule ligne, réduite si besoin — un compteur de séries doit
            // rester lisible d'un coup d'œil, y compris avec une police
            // système agrandie ou une charge à trois chiffres.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add_rounded,
              onTap: enabled ? onPlus : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 38 et non 42 : les deux boutons mangeaient 84 px sur les ~120 px de
      // large d'un compteur, ne laissant presque rien au chiffre. La zone
      // tactile reste confortable (38 × 46) pour un appui répété.
      width: 38,
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(14),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? AppColors.textDisabled
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RestAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RestAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.onGradient.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onGradient,
            ),
          ),
        ),
      ),
    );
  }
}

class _RpeChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _RpeChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: AppColors.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$value',
          style: AppTextStyles.titleMedium.copyWith(
            color: selected ? AppColors.onGradient : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
