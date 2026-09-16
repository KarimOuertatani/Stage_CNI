import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/exercise_query.dart';
import '../../data/workout_model.dart';
import '../providers/exercise_favorites_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_search.dart';

/// Liste des exercices d'une zone du corps (ouvre le détail vidéo au tap).
///
/// La zone « Dos » compte à elle seule une quarantaine d'exercices : sans
/// recherche ni filtre, la liste se parcourait au pouce jusqu'à retrouver le
/// bon nom. Le champ et les filtres travaillent **à l'intérieur de la zone**,
/// pas sur tout le catalogue — c'est le sens d'être entré dans « Dos ».
class ExercisesByBodyPartScreen extends ConsumerStatefulWidget {
  /// Code ExerciseDB de la zone (CHEST, BACK…).
  final String bodyPart;

  /// Libellé FR affiché en titre.
  final String labelFr;

  const ExercisesByBodyPartScreen({
    super.key,
    required this.bodyPart,
    required this.labelFr,
  });

  @override
  ConsumerState<ExercisesByBodyPartScreen> createState() =>
      _ExercisesByBodyPartScreenState();
}

class _ExercisesByBodyPartScreenState
    extends ConsumerState<ExercisesByBodyPartScreen> {
  ExerciseQuery _query = const ExerciseQuery();

  void _update(ExerciseQuery query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(
      exercisesByBodyPartProvider(widget.bodyPart),
    );
    final favoriteIds = ref.watch(favoriteIdsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.screenGradient),
        child: SafeArea(
          child: exercisesAsync.when(
            data: (exercises) => _content(exercises, favoriteIds),
            loading: () => Column(
              children: [
                _header(context, null),
                const Expanded(
                  child: AppListSkeleton(itemCount: 6, itemHeight: 92),
                ),
              ],
            ),
            error: (err, _) => Column(
              children: [
                _header(context, null),
                Expanded(
                  child: AppErrorState(
                    message:
                        'Impossible de charger les exercices de cette zone.',
                    onRetry: () => ref.invalidate(
                      exercisesByBodyPartProvider(widget.bodyPart),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<WorkoutModel> exercises, Set<String> favoriteIds) {
    final results = _query.apply(exercises, favoriteIds: favoriteIds);

    return Column(
      children: [
        _header(context, exercises.length),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: ExerciseSearchField(
            value: _query.text,
            onChanged: (text) => _update(_query.copyWith(text: text)),
            hint: 'Rechercher dans ${widget.labelFr.toLowerCase()}…',
          ),
        ),

        ExerciseFilterBar(
          query: _query,
          onChanged: _update,
          catalog: exercises,
        ),

        ExerciseResultHeader(
          count: results.length,
          query: _query,
          onChanged: _update,
        ),

        Expanded(
          child: results.isEmpty
              ? _emptyState(exercises.isEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final exercise = results[index];
                    return ExerciseCard(
                          workout: exercise,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/workout/exercise/${exercise.id}');
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
    );
  }

  Widget _emptyState(bool zoneIsEmpty) {
    if (zoneIsEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun exercice',
        message: 'Aucun exercice pour cette zone pour le moment.',
      );
    }
    return AppEmptyState(
      icon: Icons.filter_alt_off_rounded,
      title: 'Aucun résultat',
      message: _query.hasFilters
          ? 'Aucun exercice de cette zone ne correspond aux filtres actifs.'
          : 'Aucun exercice de cette zone ne porte ce nom.',
      actionLabel: _query.hasFilters ? 'Retirer les filtres' : null,
      onAction: _query.hasFilters
          ? () => _update(_query.clearedFilters())
          : null,
    );
  }

  Widget _header(BuildContext context, int? total) {
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
                Text(widget.labelFr, style: AppTextStyles.headingSmall),
                if (total != null)
                  Text(
                    '$total exercice${total > 1 ? 's' : ''}',
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
