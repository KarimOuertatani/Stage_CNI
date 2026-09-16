import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/workout_model.dart';
import '../providers/exercise_favorites_provider.dart';
import '../providers/recent_exercises_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_detail_body.dart';
import '../../../../core/widgets/screen_background.dart';

/// Écran de détail d'un exercice : vidéo de démonstration (ou image), aperçu,
/// instructions pas-à-pas, conseils, variations et alternatives. Point d'entrée
/// vers le logging de la séance (« S'entraîner »).
///
/// Ouvrir cette fiche est un acte délibéré : c'est ici, et pas au défilement
/// d'une liste, qu'on enregistre la consultation pour la section « Reprendre ».
class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final String exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Après le premier rendu : écrire dans un store au montage ne doit pas
    // retarder l'affichage de la fiche.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentExerciseIdsProvider.notifier).record(widget.exerciseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(exerciseDetailProvider(widget.exerciseId));

    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(
          child: detail.when(
            data: (exercise) => _content(exercise),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => AppErrorState(
              message: "Impossible de charger cet exercice.",
              onRetry: () =>
                  ref.invalidate(exerciseDetailProvider(widget.exerciseId)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(WorkoutModel exercise) {
    return Column(
      children: [
        _header(exercise),
        Expanded(
          child: ExerciseDetailBody(
            exercise: exercise,
            // `pushReplacement` et non `push` : enchaîner cinq alternatives ne
            // doit pas empiler cinq fiches à dépiler une par une pour revenir
            // à la liste.
            onOpenSimilar: (similar) =>
                context.pushReplacement('/workout/exercise/${similar.id}'),
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  Widget _header(WorkoutModel exercise) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(exercise.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
            child: Text(
              exercise.name,
              style: AppTextStyles.headingSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () async {
              HapticFeedback.selectionClick();
              final nowFavorite = await ref
                  .read(exerciseFavoritesProvider.notifier)
                  .toggle(exercise);
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.card,
                    content: Text(
                      nowFavorite
                          ? 'Ajouté à vos favoris ⭐'
                          : 'Retiré de vos favoris',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite ? AppColors.warning : AppColors.textHint,
              size: 25,
            ),
            tooltip: isFavorite ? 'Retirer des favoris' : 'Mettre en favori',
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: PrimaryButton(
        label: "S'entraîner",
        icon: Icons.play_arrow_rounded,
        onPressed: () {
          HapticFeedback.selectionClick();
          context.push('/workout/log/${widget.exerciseId}');
        },
      ),
    );
  }
}
