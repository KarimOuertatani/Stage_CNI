import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/exercise_query.dart';
import '../providers/exercise_favorites_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_search.dart';

/// Les exercices qui travaillent un groupe musculaire donné.
///
/// ## D'où l'on arrive ici
///
/// De la silhouette 2D/3D de l'écran Progression. Toucher un muscle y ouvrait
/// une fiche de charge de travail qui se terminait par un conseil — « pensez à
/// l'intégrer à votre prochaine séance » — sans jamais dire **comment**.
/// L'information et l'action vivaient sur deux écrans qui ne se parlaient pas :
/// il fallait mémoriser le muscle, ressortir, ouvrir la bibliothèque et
/// retrouver la bonne zone.
///
/// Le chemin est maintenant direct : muscle touché → ses exercices.
///
/// ## Pourquoi filtrer par groupe et non par muscle exact
///
/// Le modèle 3D nomme des muscles précis (« biceps brachii »), le catalogue
/// range les exercices par groupe (« Bras »). Filtrer sur le nom anatomique
/// exact renverrait souvent zéro résultat — la réponse la plus décevante qui
/// soit après avoir touché son propre corps à l'écran.
class ExercisesByMuscleScreen extends ConsumerStatefulWidget {
  /// Libellé FR du groupe musculaire (« Pectoraux », « Dos », « Bras »…),
  /// tel que porté par `WorkoutModel.muscleGroup`.
  final String muscleGroup;

  const ExercisesByMuscleScreen({super.key, required this.muscleGroup});

  @override
  ConsumerState<ExercisesByMuscleScreen> createState() =>
      _ExercisesByMuscleScreenState();
}

class _ExercisesByMuscleScreenState
    extends ConsumerState<ExercisesByMuscleScreen> {
  ExerciseQuery _query = const ExerciseQuery();

  void _update(ExerciseQuery query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);

    final muscleExercises = [
      for (final e in state.exercises)
        if (e.muscleGroup == widget.muscleGroup) e,
    ];
    final results = _query.apply(muscleExercises, favoriteIds: favoriteIds);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.screenGradient),
        child: SafeArea(
          child: Column(
            children: [
              _header(muscleExercises.length),

              if (state.isLoading && state.exercises.isEmpty)
                const Expanded(
                  child: AppListSkeleton(itemCount: 6, itemHeight: 92),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: ExerciseSearchField(
                    value: _query.text,
                    onChanged: (text) => _update(_query.copyWith(text: text)),
                    hint:
                        'Rechercher en ${widget.muscleGroup.toLowerCase()}…',
                  ),
                ),
                ExerciseFilterBar(
                  query: _query,
                  onChanged: _update,
                  catalog: muscleExercises,
                ),
                ExerciseResultHeader(
                  count: results.length,
                  query: _query,
                  onChanged: _update,
                ),
                Expanded(
                  child: results.isEmpty
                      ? _emptyState(muscleExercises.isEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final exercise = results[index];
                            return ExerciseCard(
                                  workout: exercise,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.push(
                                      '/workout/exercise/${exercise.id}',
                                    );
                                  },
                                )
                                .animate()
                                .fadeIn(
                                  delay: (index < 8 ? index * 30 : 0).ms,
                                  duration: 260.ms,
                                );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(bool groupIsEmpty) {
    if (groupIsEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun exercice',
        message:
            'Aucun exercice du catalogue ne cible ${widget.muscleGroup.toLowerCase()} pour le moment.',
      );
    }
    return AppEmptyState(
      icon: Icons.filter_alt_off_rounded,
      title: 'Aucun résultat',
      message: 'Aucun exercice ne correspond à votre recherche.',
      actionLabel: _query.hasFilters ? 'Retirer les filtres' : null,
      onAction: _query.hasFilters
          ? () => _update(_query.clearedFilters())
          : null,
    );
  }

  Widget _header(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/workout');
              }
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textSecondary,
              size: 26,
            ),
            tooltip: 'Retour',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.muscleGroup, style: AppTextStyles.headingSmall),
                Text(
                  '$total exercice${total > 1 ? 's' : ''} pour cette zone',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
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
