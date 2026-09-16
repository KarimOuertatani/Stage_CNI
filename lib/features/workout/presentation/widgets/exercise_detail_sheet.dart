import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/workout_model.dart';
import '../providers/exercise_favorites_provider.dart';
import '../providers/workout_provider.dart';
import 'exercise_detail_body.dart';
import 'exercise_visuals.dart';

/// Ouvre la fiche d'un exercice **par-dessus** l'écran courant.
///
/// ## Le problème que ça règle
///
/// Depuis un programme, appuyer sur un exercice menait directement à l'écran de
/// saisie des séries — sans aucun moyen d'y revoir la vidéo ni la position de
/// départ. Un oubli en pleine séance obligeait à sortir de l'écran, rouvrir
/// l'onglet Exercices, retrouver le mouvement dans le catalogue… et à revenir
/// en ayant perdu le chrono de la séance, le minuteur de repos et les séries
/// déjà validées.
///
/// ## Pourquoi une feuille et pas une navigation
///
/// C'est tout l'intérêt : une feuille modale **n'est pas une navigation**.
/// L'écran de saisie reste monté derrière elle, donc rien ne s'arrête — le
/// chrono continue de tourner, le repos continue de décompter, les séries
/// cochées restent cochées. On tire vers le bas, on est revenu à sa série.
///
/// Naviguer vers la fiche plein écran aurait aussi posé un problème de sens :
/// son bouton « S'entraîner » proposerait de commencer un entraînement… déjà
/// commencé.
Future<void> showExerciseDetailSheet(
  BuildContext context, {
  required String exerciseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // La feuille couvre le fond sans l'effacer : le halo de l'écran de séance
    // reste visible, ce qui rappelle qu'on n'a pas quitté sa séance.
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ExerciseDetailSheet(exerciseId: exerciseId),
  );
}

class _ExerciseDetailSheet extends ConsumerWidget {
  final String exerciseId;

  const _ExerciseDetailSheet({required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(exerciseId));

    return DraggableScrollableSheet(
      // 0,82 et non 1 : la lisière d'écran visible en haut dit « il y a
      // quelque chose derrière », ce qu'une feuille plein écran ne dit pas.
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: detail.when(
                  data: (exercise) => _content(
                    context,
                    ref,
                    exercise,
                    scrollController,
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (err, _) => AppErrorState(
                    message: 'Impossible de charger cet exercice.',
                    onRetry: () =>
                        ref.invalidate(exerciseDetailProvider(exerciseId)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    WorkoutModel exercise,
    ScrollController scrollController,
  ) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(exercise.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: levelColor(exercise.level),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  exercise.name,
                  style: AppTextStyles.headingSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(exerciseFavoritesProvider.notifier).toggle(exercise);
                },
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? AppColors.warning : AppColors.textHint,
                ),
                tooltip: isFavorite ? 'Retirer des favoris' : 'Mettre en favori',
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                tooltip: 'Revenir à ma série',
              ),
            ],
          ),
        ),
        Expanded(
          child: ExerciseDetailBody(
            exercise: exercise,
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            // Pas de suggestions ici : on ouvre cette feuille en pleine série
            // pour vérifier une exécution, pas pour changer d'exercice.
            showSimilar: false,
          ),
        ),
      ],
    );
  }
}
