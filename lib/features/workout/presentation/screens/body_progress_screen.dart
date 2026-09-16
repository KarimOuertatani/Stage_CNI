import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../data/workout_model.dart';
import '../providers/workout_provider.dart';
import '../widgets/body_2d_widget.dart';
import '../widgets/body_3d_widget.dart';
import '../widgets/muscle_detail_sheet.dart';
import '../widgets/muscle_group_3d_mapper.dart'
    show colorFromIntensitySmooth, labelFromIntensity;
import '../../../../core/widgets/screen_background.dart';

/// Écran Progression — vitrine de la visualisation corporelle 2D/3D.
class BodyProgressScreen extends ConsumerStatefulWidget {
  const BodyProgressScreen({super.key});

  @override
  ConsumerState<BodyProgressScreen> createState() => _BodyProgressScreenState();
}

class _BodyProgressScreenState extends ConsumerState<BodyProgressScreen> {
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// true = vue 2D, false = vue 3D. La 3D est la vue par défaut sur mobile
  /// (fonctionnalité signature) ; la 2D sur desktop (pas de moteur 3D).
  late bool _is2D = !_isMobile;

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(workoutProvider);

    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(bottom: false, child: _buildBody(workoutState)),
      ),
    );
  }

  Widget _buildBody(WorkoutState state) {
    if (state.isLoading) {
      return _ProgressSkeleton();
    }

    if (state.errorMessage != null && state.muscleIntensities.isEmpty) {
      return AppErrorState(
        message: 'Impossible de charger vos données d\'entraînement.',
        onRetry: () => ref.read(workoutProvider.notifier).loadInitialData(),
      );
    }

    final intensities = state.muscleIntensities;

    return RefreshIndicator(
      onRefresh: () => ref.read(workoutProvider.notifier).refreshIntensities(),
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Text(
              'PROGRESSION · 7 DERNIERS JOURS',
              style: AppTextStyles.overline.copyWith(
                color: AppColors.accentText,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Votre corps en action',
                    style: AppTextStyles.headingLarge,
                  ),
                ),
                // Accès à l'historique jour par jour des séances réalisées.
                _HistoryButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/workout/history');
                  },
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
            const SizedBox(height: 6),
            Text(
              'Chaque zone s\'illumine selon l\'intensité de vos '
              'entraînements récents.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // ── Bascule 2D / 3D ────────────────────────────────────
            Center(
              child: _ViewToggle(
                is2D: _is2D,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _is2D = value);
                },
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // ── Visualisation corporelle ───────────────────────────
            // Les deux vues restent montées (Offstage) : le modèle GLB
            // n'est chargé qu'une seule fois, la bascule est instantanée.
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  Offstage(
                    offstage: !_is2D,
                    child: AnimatedOpacity(
                      opacity: _is2D ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Body2DWidget(intensities: intensities),
                    ),
                  ),
                  Offstage(
                    offstage: _is2D,
                    child: AnimatedOpacity(
                      opacity: _is2D ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      // Le modèle 3D travaille à la granularité du muscle,
                      // pas du groupe : il consomme la charge détaillée.
                      child: Body3DWidget(
                        effort: state.muscleEffort,
                        height: 520,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 24),

            // ── Résumé de la semaine ───────────────────────────────
            _WeekSummary(intensities: intensities)
                .animate()
                .fadeIn(delay: 250.ms, duration: 450.ms)
                .slideY(begin: 0.06),
            const SizedBox(height: 28),

            // ── Détail par groupe musculaire ───────────────────────
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: AppColors.primaryGlow,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Détail par groupe musculaire',
                  style: AppTextStyles.headingSmall,
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),

            if (intensities.isEmpty)
              const AppEmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'Aucune donnée cette semaine',
                message:
                    'Enregistrez votre première séance pour voir votre corps '
                    's\'illuminer.',
              )
            else
              for (var index = 0; index < intensities.length; index++)
                _MuscleGroupCard(
                      intensity: intensities[index],
                      onTap: () => showMuscleDetailSheet(
                        context,
                        muscleName: intensities[index].group,
                        groupName: intensities[index].group,
                        intensity: intensities[index].intensity,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: (350 + index * 60).ms, duration: 400.ms)
                    .slideY(begin: 0.05),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton d'accès à l'historique des séances
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HistoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: AppColors.accentText,
              ),
              const SizedBox(width: 6),
              Text(
                'Historique',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.accentText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Résumé de la semaine (3 stats)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekSummary extends StatelessWidget {
  final List<MuscleIntensity> intensities;

  const _WeekSummary({required this.intensities});

  @override
  Widget build(BuildContext context) {
    if (intensities.isEmpty) return const SizedBox.shrink();

    final sorted = [...intensities]
      ..sort((a, b) => b.intensity.compareTo(a.intensity));
    final top = sorted.first;
    final resting = intensities.where((e) => e.intensity < 0.3).length;
    final avg =
        intensities.fold<double>(0, (s, e) => s + e.intensity) /
        intensities.length;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 22,
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.local_fire_department_rounded,
              iconColor: colorFromIntensitySmooth(top.intensity),
              value: top.group,
              label: 'Zone la plus active',
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.speed_rounded,
              iconColor: AppColors.accentText,
              value: '${(avg * 100).round()}%',
              label: 'Intensité moyenne',
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.self_improvement_rounded,
              iconColor: AppColors.primaryText,
              value: '$resting',
              label: resting > 1 ? 'Zones au repos' : 'Zone au repos',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 44,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppColors.border,
  );
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
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
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte de groupe musculaire
// ─────────────────────────────────────────────────────────────────────────────

class _MuscleGroupCard extends StatelessWidget {
  final MuscleIntensity intensity;
  final VoidCallback onTap;

  const _MuscleGroupCard({required this.intensity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percentage = (intensity.intensity * 100).round();
    final color = colorFromIntensitySmooth(intensity.intensity);
    final label = labelFromIntensity(intensity.intensity);

    return SolidCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Le nom du groupe est Expanded + ellipsis : « Abdominaux »
                // suivi du badge et du pourcentage débordait sur un écran
                // étroit ou avec une police système agrandie.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        intensity.group,
                        style: AppTextStyles.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    NeonBadge(label: label, color: color, fontSize: 9),
                    const SizedBox(width: 8),
                    Text(
                      '$percentage%',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedProgressBar(
                  value: intensity.intensity,
                  height: 6,
                  color: color,
                  showGlow: intensity.intensity > 0.1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton de chargement
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 220, height: 12, borderRadius: 6),
          const SizedBox(height: 12),
          const ShimmerBox(width: 260, height: 26, borderRadius: 8),
          const SizedBox(height: 20),
          const Center(
            child: ShimmerBox(width: 180, height: 44, borderRadius: 16),
          ),
          const SizedBox(height: 20),
          const ShimmerBox(
            width: double.infinity,
            height: 420,
            borderRadius: 28,
          ),
          const SizedBox(height: 24),
          const ShimmerBox(
            width: double.infinity,
            height: 90,
            borderRadius: 22,
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < 3; i++) ...[
            const ShimmerBox(
              width: double.infinity,
              height: 84,
              borderRadius: 18,
            ),
            const SizedBox(height: 12),
          ],
        ].animate(interval: 60.ms).fadeIn(duration: 300.ms),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bascule 2D / 3D
// ─────────────────────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool is2D;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.is2D, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: '3D',
            icon: Icons.view_in_ar_rounded,
            selected: !is2D,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 4),
          _ToggleChip(
            label: '2D',
            icon: Icons.person_outline,
            selected: is2D,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: selected ? AppColors.primaryGradient : null,
        color: selected ? null : Colors.transparent,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? AppColors.onGradient
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: selected
                        ? AppColors.onGradient
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
