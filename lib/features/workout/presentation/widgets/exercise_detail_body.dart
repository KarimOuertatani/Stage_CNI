import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../data/workout_model.dart';
import '../providers/workout_provider.dart';
import 'exercise_video_player.dart';
import 'exercise_visuals.dart';

/// Le contenu pédagogique d'un exercice : vidéo, badges, présentation,
/// instructions, conseils, variations, muscles, exercices proches.
///
/// ## Pourquoi ce corps est un widget à part
///
/// Il s'affiche à **deux endroits** : la fiche plein écran, ouverte depuis la
/// bibliothèque, et la feuille qu'on tire par-dessus l'écran de saisie pendant
/// une séance. Ce sont deux contextes, mais une seule information — et une
/// deuxième copie du même contenu aurait divergé dès la première correction.
///
/// Chaque hôte fournit son propre [controller] : la feuille a besoin de celui
/// de `DraggableScrollableSheet` pour que le geste de glissement continue le
/// défilement au lieu de le bloquer.
class ExerciseDetailBody extends ConsumerWidget {
  final WorkoutModel exercise;
  final ScrollController? controller;
  final EdgeInsets padding;

  /// Affiche la section « À la place, essayez… ». Masquée dans la feuille
  /// ouverte en pleine séance : on y vient pour vérifier une exécution, pas
  /// pour changer d'exercice au milieu de ses séries.
  final bool showSimilar;

  final void Function(WorkoutModel)? onOpenSimilar;

  const ExerciseDetailBody({
    super.key,
    required this.exercise,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
    this.showSimilar = true,
    this.onOpenSimilar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = showSimilar
        ? ref.watch(similarExercisesProvider(exercise.id))
        : const <WorkoutModel>[];

    return ListView(
      controller: controller,
      padding: padding,
      children: [
        _media().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 18),
        _badges().animate().fadeIn(delay: 120.ms),
        const SizedBox(height: 16),
        _stats().animate().fadeIn(delay: 180.ms),
        if (exercise.overview != null &&
            exercise.overview!.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          ExerciseSection(
            title: 'Présentation',
            icon: Icons.info_outline_rounded,
            child: Text(
              exercise.overview!.trim(),
              style: AppTextStyles.bodyMedium,
            ),
          ).animate().fadeIn(delay: 220.ms),
        ],
        if (exercise.instructionSteps.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExerciseSection(
            title: 'Instructions',
            icon: Icons.format_list_numbered_rounded,
            child: _steps(exercise.instructionSteps),
          ).animate().fadeIn(delay: 260.ms),
        ],
        if (exercise.tipsList.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExerciseSection(
            title: 'Conseils',
            icon: Icons.tips_and_updates_outlined,
            child: _bullets(exercise.tipsList, AppColors.accentText),
          ).animate().fadeIn(delay: 300.ms),
        ],
        if (exercise.variationsList.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExerciseSection(
            title: 'Variations',
            icon: Icons.alt_route_rounded,
            child: _bullets(exercise.variationsList, AppColors.primaryText),
          ).animate().fadeIn(delay: 340.ms),
        ],
        _secondaryMuscles(),
        if (similar.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExerciseSection(
            title: 'À la place, essayez…',
            icon: Icons.swap_horiz_rounded,
            child: _similarList(similar),
          ).animate().fadeIn(delay: 420.ms),
        ],
      ],
    );
  }

  // ── Média (vidéo ou image) ─────────────────────────────────────────────
  Widget _media() {
    if (exercise.hasVideo) {
      return ExerciseVideoPlayer(
        videoUrl: exercise.videoUrl!,
        poster: exercise.detailImageUrl,
      );
    }
    final image = ApiConstants.proxiedMedia(exercise.detailImageUrl);
    if (image != null && image.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _mediaPlaceholder(),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    color: AppColors.card,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
          ),
        ),
      );
    }
    return _mediaPlaceholder();
  }

  Widget _mediaPlaceholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(
            Icons.fitness_center_rounded,
            color: AppColors.onGradient,
            size: 56,
          ),
        ),
      ),
    );
  }

  // ── Badges (groupe, niveau, matériel, type) ────────────────────────────
  Widget _badges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NeonBadge(label: exercise.muscleGroup, color: AppColors.primary),
        NeonBadge(
          label: exercise.level.label,
          color: levelColor(exercise.level),
        ),
        if (exercise.equipmentLabel != null)
          NeonBadge(label: exercise.equipmentLabel!, color: AppColors.accent),
        if (exercise.typeLabel != null)
          NeonBadge(label: exercise.typeLabel!, color: AppColors.info),
      ],
    );
  }

  Widget _stats() {
    return Row(
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          label: '${exercise.durationMinutes} min',
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.local_fire_department_outlined,
          label: '${exercise.caloriesBurned} kcal',
        ),
      ],
    );
  }

  Widget _steps(List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onGradient,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(steps[i], style: AppTextStyles.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bullets(List<String> items, Color dotColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(item, style: AppTextStyles.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _secondaryMuscles() {
    final muscles = exercise.secondaryMusclesList.map(titleCase).toList();
    if (muscles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ExerciseSection(
        title: 'Muscles secondaires',
        icon: Icons.accessibility_new_rounded,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in muscles)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  m,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 380.ms);
  }

  /// Les alternatives : même muscle, autre exécution. Répond à la question la
  /// plus banale de la salle — « la machine est prise, je fais quoi ? ».
  Widget _similarList(List<WorkoutModel> similar) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: similar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = similar[index];
          return SizedBox(
            width: 148,
            child: Material(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenSimilar?.call(item);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      ExerciseThumbnail(
                        exercise: item,
                        size: 44,
                        showVideoBadge: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: AppTextStyles.caption,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.equipmentLabel != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.equipmentLabel!,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textHint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Section titrée réutilisable (icône + titre + contenu).
class ExerciseSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const ExerciseSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accentText),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
