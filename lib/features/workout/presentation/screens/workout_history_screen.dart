import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../data/workout_history_model.dart';
import '../providers/workout_history_provider.dart';
import '../../../../core/widgets/screen_background.dart';

/// Écran Historique des séances — l'adhérent revoit ce qu'il a réellement fait
/// un jour précis (exercices, séries, charges), avec navigation par jour.
class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Recharge à chaque ouverture : une séance terminée juste avant doit
    // apparaître (le provider persiste sinon un état vide obsolète).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final day = ref.read(workoutHistoryProvider).selectedDay;
      ref.read(workoutHistoryProvider.notifier).loadDay(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des séances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
            onPressed: () => ref
                .read(workoutHistoryProvider.notifier)
                .loadDay(state.selectedDay),
          ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _DateBar(
                state: state,
                onPrev: () =>
                    ref.read(workoutHistoryProvider.notifier).previousDay(),
                onNext: () =>
                    ref.read(workoutHistoryProvider.notifier).nextDay(),
                onToday: () =>
                    ref.read(workoutHistoryProvider.notifier).goToday(),
                onPick: () => _pickDay(context, ref, state),
              ),
              Expanded(child: _buildBody(context, ref, state)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDay(
    BuildContext context,
    WidgetRef ref,
    WorkoutHistoryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDay,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Choisir un jour',
    );
    if (picked != null) {
      ref.read(workoutHistoryProvider.notifier).loadDay(picked);
    }
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    WorkoutHistoryState state,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: AppListSkeleton(itemCount: 3, itemHeight: 160),
      );
    }

    if (state.errorMessage != null && state.entries.isEmpty) {
      return AppErrorState(
        message: 'Impossible de charger l\'historique.',
        onRetry: () => ref
            .read(workoutHistoryProvider.notifier)
            .loadDay(state.selectedDay),
      );
    }

    if (state.entries.isEmpty) {
      return AppEmptyState(
        icon: Icons.history_rounded,
        title: state.isToday
            ? 'Aucune séance aujourd\'hui'
            : 'Aucune séance ce jour-là',
        message:
            'Les séances que vous terminez apparaîtront ici, jour par jour.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _DaySummary(
          state: state,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
        const SizedBox(height: 16),
        for (var i = 0; i < state.entries.length; i++)
          _SessionCard(entry: state.entries[i], index: i)
              .animate()
              .fadeIn(delay: (120 + i * 70).ms, duration: 400.ms)
              .slideY(begin: 0.05),
      ],
    );
  }
}

// ── Résumé du jour ────────────────────────────────────────────────────
class _DaySummary extends StatelessWidget {
  final WorkoutHistoryState state;
  const _DaySummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final sessions = state.entries.length;
    final volume = state.totalVolume;
    final volumeLabel = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)} t'
        : '${volume.round()} kg';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 22,
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.event_available_rounded,
              color: AppColors.accentText,
              value: '$sessions',
              label: sessions > 1 ? 'Séances' : 'Séance',
            ),
          ),
          _divider(),
          Expanded(
            child: _Stat(
              icon: Icons.fitness_center_rounded,
              color: AppColors.primaryText,
              value: '${state.totalExercises}',
              label: 'Exercices',
            ),
          ),
          _divider(),
          Expanded(
            child: _Stat(
              icon: Icons.repeat_rounded,
              color: AppColors.accentText,
              value: '${state.totalSets}',
              label: 'Séries',
            ),
          ),
          _divider(),
          Expanded(
            child: _Stat(
              icon: Icons.scale_rounded,
              color: AppColors.primaryText,
              value: volumeLabel,
              label: 'Volume',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 40,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppColors.border,
  );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Carte d'une séance ────────────────────────────────────────────────
/// Carte de séance repliable : résumé toujours visible (nb d'exercices,
/// séries, volume) + tap pour dérouler la liste complète des exercices.
class _SessionCard extends StatefulWidget {
  final WorkoutLogEntry entry;
  final int index;
  const _SessionCard({required this.entry, required this.index});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  late bool _expanded = widget.index == 0; // la plus récente est déroulée

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final exCount = entry.exercises.length;
    final volume = entry.totalVolume;
    final volumeLabel = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)} t'
        : '${volume.round()} kg';

    return SolidCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : n° de séance + durée + RPE + chevron
          Row(
            children: [
              Container(
                width: 6,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: AppColors.primaryGlow,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Séance ${widget.index + 1}',
                style: AppTextStyles.titleLarge,
              ),
              const Spacer(),
              if (entry.durationMinutes != null && entry.durationMinutes! > 0)
                _MetaChip(
                  icon: Icons.timer_outlined,
                  label: '${entry.durationMinutes} min',
                ),
              if (entry.rpe != null) ...[
                const SizedBox(width: 6),
                _MetaChip(icon: Icons.bolt_rounded, label: 'RPE ${entry.rpe}'),
              ],
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textHint,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Résumé toujours visible
          Text(
            '$exCount exercice${exCount > 1 ? 's' : ''} · ${entry.totalSets} séries · $volumeLabel',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          // Liste complète des exercices (dépliable)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                for (var i = 0; i < entry.exercises.length; i++) ...[
                  _ExerciseBlock(exercise: entry.exercises[i]),
                  if (i != entry.exercises.length - 1)
                    Divider(color: AppColors.border, height: 22),
                ],
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Un exercice + ses séries ──────────────────────────────────────────
class _ExerciseBlock extends StatelessWidget {
  final LoggedExercise exercise;
  const _ExerciseBlock({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            NeonBadge(
              label: exercise.muscleGroup,
              color: AppColors.primary,
              fontSize: 9,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final set in exercise.sets) _SetPill(set: set)],
        ),
      ],
    );
  }
}

class _SetPill extends StatelessWidget {
  final LoggedSet set;
  const _SetPill({required this.set});

  @override
  Widget build(BuildContext context) {
    final done = set.completed;
    final weight = set.weightKg > 0
        ? '${set.weightKg % 1 == 0 ? set.weightKg.toInt() : set.weightKg} kg'
        : 'PDC'; // poids du corps
    final color = done ? AppColors.accent : AppColors.textHint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.glassWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done
              ? AppColors.accent.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${set.setNumber}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 12, color: AppColors.border),
          const SizedBox(width: 6),
          Text(
            '${set.reps} × $weight',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!done) ...[
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 12, color: AppColors.textHint),
          ],
        ],
      ),
    );
  }
}

// ── Barre de navigation par jour (identique à la nutrition) ───────────
class _DateBar extends StatelessWidget {
  final WorkoutHistoryState state;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPick;

  const _DateBar({
    required this.state,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  static const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

  String _label() {
    final d = state.selectedDay;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            enabled: true,
            onTap: () {
              HapticFeedback.selectionClick();
              onPrev();
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onPick();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: AppColors.accentText,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _label(),
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!state.isToday) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onToday();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Aujourd\'hui',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onGradient,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            enabled: !state.isToday,
            onTap: () {
              HapticFeedback.selectionClick();
              onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, color: AppColors.textPrimary),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.glassWhite,
          minimumSize: const Size(42, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}
