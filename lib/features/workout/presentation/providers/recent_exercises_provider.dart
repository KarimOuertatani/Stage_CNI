import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/recent_exercises_store.dart';
import '../../data/workout_model.dart';
import 'workout_provider.dart';

/// Les exercices récemment consultés, du plus récent au plus ancien.
///
/// L'état ne porte que des **identifiants** : les exercices eux-mêmes vivent
/// dans le catalogue ([workoutProvider]). Dupliquer les objets ici ferait
/// afficher des données périmées le jour où le catalogue est rechargé.
class RecentExercisesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    state = await RecentExercisesStore.instance.read();
  }

  /// Note l'ouverture d'un exercice. Appelé depuis l'écran de détail, et non
  /// depuis la liste : ouvrir la fiche est un acte délibéré, faire défiler une
  /// liste ne l'est pas.
  Future<void> record(String exerciseId) async {
    await RecentExercisesStore.instance.record(exerciseId);
    state = await RecentExercisesStore.instance.read();
  }

  /// Efface l'historique (déconnexion, ou geste explicite de l'adhérent).
  Future<void> clear() async {
    await RecentExercisesStore.instance.clear();
    state = const [];
  }
}

final recentExerciseIdsProvider =
    NotifierProvider<RecentExercisesNotifier, List<String>>(
      RecentExercisesNotifier.new,
    );

/// Les exercices récents résolus depuis le catalogue.
///
/// Les identifiants introuvables sont ignorés silencieusement : un exercice
/// peut avoir disparu du catalogue depuis sa consultation, et ce n'est pas à
/// l'adhérent d'en entendre parler.
final recentExercisesProvider = Provider<List<WorkoutModel>>((ref) {
  final ids = ref.watch(recentExerciseIdsProvider);
  if (ids.isEmpty) return const [];

  final catalog = ref.watch(workoutProvider).exercises;
  if (catalog.isEmpty) return const [];

  final byId = {for (final e in catalog) e.id: e};
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!,
  ];
});
