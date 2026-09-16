import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/body_part_model.dart';
import '../../data/exercise_query.dart';
import '../../data/workout_model.dart';
import '../providers/exercise_favorites_provider.dart';
import '../providers/recent_exercises_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/body_part_card.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_search.dart';

/// Vue « Exercices » : le point d'entrée du catalogue.
///
/// ## Deux façons de chercher, pas une
///
/// L'écran ne proposait qu'une **navigation par zone du corps** : jolie, mais
/// c'est le chemin long. Quelqu'un qui sait déjà qu'il cherche le « Développé
/// couché » devait ouvrir « Pectoraux » puis parcourir quarante lignes.
///
/// La recherche est donc au-dessus de tout le reste, toujours visible. Tant
/// qu'elle est vide, l'écran garde sa navigation visuelle — et y ajoute les
/// deux raccourcis qui évitent de chercher tout court : ce qu'on vient de
/// consulter, et ce qu'on a mis en favori. Dès qu'un caractère est saisi ou
/// qu'un filtre est actif, la page bascule en liste de résultats.
class ExerciseLibraryView extends ConsumerStatefulWidget {
  const ExerciseLibraryView({super.key});

  @override
  ConsumerState<ExerciseLibraryView> createState() =>
      _ExerciseLibraryViewState();
}

class _ExerciseLibraryViewState extends ConsumerState<ExerciseLibraryView> {
  ExerciseQuery _query = const ExerciseQuery();

  void _update(ExerciseQuery query) => setState(() => _query = query);

  void _openExercise(WorkoutModel exercise) {
    HapticFeedback.selectionClick();
    context.push('/workout/exercise/${exercise.id}');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(workoutProvider).exercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Recherche : toujours visible, y compris pendant le défilement ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: ExerciseSearchField(
            value: _query.text,
            onChanged: (text) => _update(_query.copyWith(text: text)),
            hint: 'Rechercher un exercice, un muscle…',
          ),
        ).animate().fadeIn(duration: 400.ms),

        ExerciseFilterBar(
          query: _query,
          onChanged: _update,
          catalog: catalog,
        ).animate().fadeIn(delay: 80.ms),

        const SizedBox(height: 4),

        Expanded(
          child: _query.isEmpty
              ? _BrowseView(onOpenExercise: _openExercise)
              : _ResultsView(
                  query: _query,
                  onQueryChanged: _update,
                  onOpenExercise: _openExercise,
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Vue par défaut : raccourcis + navigation par zone
// ─────────────────────────────────────────────────────────────────────────────

class _BrowseView extends ConsumerWidget {
  final void Function(WorkoutModel) onOpenExercise;

  const _BrowseView({required this.onOpenExercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bodyPartsAsync = ref.watch(bodyPartsProvider);
    final recents = ref.watch(recentExercisesProvider);
    final favorites = ref.watch(exerciseFavoritesProvider).exercises;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: _ProgressBanner(
              onTap: () {
                HapticFeedback.selectionClick();
                context.go('/progress');
              },
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05),
        ),

        // « Reprendre » avant « Favoris » : ce qu'on vient de consulter est
        // presque toujours ce qu'on cherche à rouvrir pendant une séance.
        if (recents.isNotEmpty)
          _ShortcutRow(
            title: 'Reprendre',
            icon: Icons.history_rounded,
            exercises: recents,
            onOpen: onOpenExercise,
          ),

        if (favorites.isNotEmpty)
          _ShortcutRow(
            title: 'Mes favoris',
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            exercises: favorites,
            onOpen: onOpenExercise,
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.accessibility_new_rounded,
                  size: 20,
                  color: AppColors.accentText,
                ),
                const SizedBox(width: 8),
                Text('Parcourir par zone', style: AppTextStyles.headingSmall),
              ],
            ),
          ),
        ),

        ..._bodyPartSlivers(context, ref, bodyPartsAsync),

        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  List<Widget> _bodyPartSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BodyPartModel>> async,
  ) {
    return async.when(
      data: (parts) {
        if (parts.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucune zone disponible',
                message: 'Le catalogue d\'exercices n\'est pas encore chargé.',
                actionLabel: 'Réessayer',
                onAction: () => ref.invalidate(bodyPartsProvider),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              // Largeur MAXIMALE par tuile plutôt qu'un nombre de colonnes
              // figé : le nombre de colonnes s'adapte tout seul (2 sur
              // téléphone, jusqu'à 7 sur une large fenêtre desktop) et les
              // vignettes gardent une taille lisible au lieu de s'étirer.
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.86,
                  ),
              itemCount: parts.length,
              itemBuilder: (context, index) {
                final part = parts[index];
                return BodyPartCard(
                      bodyPart: part,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push(
                          '/workout/bodypart/${Uri.encodeComponent(part.name)}',
                          extra: part.labelFr,
                        );
                      },
                    )
                    .animate()
                    .fadeIn(delay: (index * 40).ms, duration: 320.ms)
                    .slideY(begin: 0.06);
              },
            ),
          ),
        ];
      },
      loading: () => const [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ),
      ],
      error: (err, _) => [
        SliverToBoxAdapter(
          child: AppErrorState(
            message: 'Impossible de charger les zones du corps.',
            onRetry: () => ref.invalidate(bodyPartsProvider),
          ),
        ),
      ],
    );
  }
}

/// Bande horizontale de raccourcis (récents, favoris).
class _ShortcutRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final List<WorkoutModel> exercises;
  final void Function(WorkoutModel) onOpen;

  const _ShortcutRow({
    required this.title,
    required this.icon,
    required this.exercises,
    required this.onOpen,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: iconColor ?? AppColors.accentText),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.headingSmall),
                const SizedBox(width: 8),
                Text(
                  '${exercises.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 186,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: exercises.length,
              itemBuilder: (context, index) => ExerciseMiniCard(
                exercise: exercises[index],
                onTap: () => onOpen(exercises[index]),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Vue résultats
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final ExerciseQuery query;
  final ValueChanged<ExerciseQuery> onQueryChanged;
  final void Function(WorkoutModel) onOpenExercise;

  const _ResultsView({
    required this.query,
    required this.onQueryChanged,
    required this.onOpenExercise,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);

    if (state.isLoading && state.exercises.isEmpty) {
      return const AppListSkeleton(itemCount: 6, itemHeight: 92);
    }

    final results = query.apply(state.exercises, favoriteIds: favoriteIds);

    return Column(
      children: [
        ExerciseResultHeader(
          count: results.length,
          query: query,
          onChanged: onQueryChanged,
        ),
        Expanded(
          child: results.isEmpty
              ? _NoResults(query: query, onChanged: onQueryChanged)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final exercise = results[index];
                    return ExerciseCard(
                          workout: exercise,
                          onTap: () => onOpenExercise(exercise),
                        )
                        // Animation limitée aux premières lignes : au-delà,
                        // le décalage cumulé ferait apparaître les résultats
                        // une seconde après la frappe.
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
}

/// Aucun résultat — avec de quoi en sortir, pas seulement un constat.
class _NoResults extends StatelessWidget {
  final ExerciseQuery query;
  final ValueChanged<ExerciseQuery> onChanged;

  const _NoResults({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Distinguer les deux causes : un filtre trop restrictif se retire d'un
    // tap, une faute de frappe demande de réécrire. Le message ne doit pas
    // renvoyer l'adhérent vers le mauvais geste.
    final blamesFilters = query.hasFilters;
    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'Aucun exercice trouvé',
      message: blamesFilters
          ? 'Aucun exercice ne correspond à la fois à votre recherche et aux filtres actifs.'
          : 'Essayez un autre mot : le nom d\'un mouvement, un muscle ou un matériel.',
      actionLabel: blamesFilters ? 'Retirer les filtres' : null,
      onAction: blamesFilters ? () => onChanged(query.clearedFilters()) : null,
    );
  }
}

/// Bannière gradient vers la visualisation corporelle 3D.
class _ProgressBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _ProgressBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.accessibility_new,
                  size: 130,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.view_in_ar_rounded,
                        color: AppColors.onGradient,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Votre corps en 3D',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.onGradient,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Touchez un muscle pour voir ses exercices.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onGradient.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.onGradient,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
