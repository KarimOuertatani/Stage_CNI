import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../data/workout_model.dart';
import '../providers/exercise_favorites_provider.dart';
import 'exercise_visuals.dart';

/// Ligne d'exercice de la bibliothèque : vignette, nom, niveau, matériel,
/// et l'étoile de mise en favori.
///
/// ## Ce qui a changé et pourquoi
///
/// La carte affichait une icône de groupe musculaire — la même pour les
/// quarante exercices de dos — et deux estimations (durée, calories) qui ne
/// distinguent rien puisqu'elles sont calculées depuis ce même groupe. À
/// l'écran, quinze lignes rigoureusement identiques sauf le titre.
///
/// Elle affiche maintenant ce qui **différencie** un exercice d'un autre : sa
/// photo, son niveau, son matériel. La durée estimée reste, mais en second
/// plan, à sa juste valeur d'estimation.
class ExerciseCard extends ConsumerWidget {
  final WorkoutModel workout;
  final VoidCallback? onTap;

  /// Bouton favori. Masqué là où il n'a pas de sens — un sélecteur d'exercice
  /// dans lequel on choisit, on ne collectionne pas.
  final bool showFavorite;

  const ExerciseCard({
    super.key,
    required this.workout,
    this.onTap,
    this.showFavorite = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(workout.id);
    final equipment = workout.equipmentLabel;

    return SolidCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12.0),
      borderRadius: 18,
      child: Row(
        children: [
          ExerciseThumbnail(exercise: workout, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                // Wrap et non Row : sur un écran étroit, trois badges plus un
                // nom long débordaient. Ils passent à la ligne au lieu d'être
                // rognés.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NeonBadge(
                      label: workout.muscleGroup,
                      color: AppColors.primary,
                      fontSize: 10,
                    ),
                    NeonBadge(
                      label: workout.level.label,
                      color: levelColor(workout.level),
                      fontSize: 10,
                    ),
                    if (equipment != null)
                      _MutedTag(
                        icon: Icons.fitness_center_rounded,
                        label: equipment,
                      ),
                    _MutedTag(
                      icon: Icons.timer_outlined,
                      label: '${workout.durationMinutes} min',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showFavorite)
            _FavoriteButton(exercise: workout, isFavorite: isFavorite)
          else
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint,
                size: 15,
              ),
            ),
        ],
      ),
    );
  }
}

/// Version compacte, pour les bandes horizontales « Récents » et « Favoris ».
///
/// Format vertical (image au-dessus du nom) et non la ligne habituelle : une
/// bande horizontale doit laisser deviner qu'il y a d'autres cartes à droite,
/// ce que des lignes pleine largeur empêchent.
class ExerciseMiniCard extends StatelessWidget {
  final WorkoutModel exercise;
  final VoidCallback onTap;

  const ExerciseMiniCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: SolidCard(
        onTap: onTap,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: ExerciseThumbnail(exercise: exercise, size: 92)),
            const SizedBox(height: 9),
            Text(
              exercise.name,
              style: AppTextStyles.labelMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: levelColor(exercise.level),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exercise.muscleGroup,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// L'étoile de favori.
///
/// Sa zone tactile fait 44 px : plus petite, elle se déclencherait à la place
/// de l'ouverture de l'exercice une fois sur trois.
class _FavoriteButton extends ConsumerWidget {
  final WorkoutModel exercise;
  final bool isFavorite;

  const _FavoriteButton({required this.exercise, required this.isFavorite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(exerciseFavoritesProvider.notifier).toggle(exercise);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              key: ValueKey(isFavorite),
              size: 24,
              color: isFavorite ? AppColors.warning : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Information secondaire : lisible, mais qui ne rivalise pas avec les badges.
class _MutedTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MutedTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}
