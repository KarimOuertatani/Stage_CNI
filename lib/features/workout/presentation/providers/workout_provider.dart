import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/body_part_model.dart';
import '../../data/last_performance.dart';
import '../../data/muscle_effort.dart';
import '../../data/workout_api.dart';
import '../../data/workout_model.dart';

class WorkoutState {
  final List<WorkoutModel> exercises;
  final List<MuscleIntensity> muscleIntensities;

  /// Charge par muscle du modèle 3D — granularité fine de [muscleIntensities].
  final MuscleEffort muscleEffort;
  final bool isLoading;
  final String? errorMessage;
  final String selectedMuscleGroup;

  const WorkoutState({
    this.exercises = const [],
    this.muscleIntensities = const [],
    this.muscleEffort = MuscleEffort.empty,
    this.isLoading = false,
    this.errorMessage,
    this.selectedMuscleGroup = 'Tous',
  });

  WorkoutState copyWith({
    List<WorkoutModel>? exercises,
    List<MuscleIntensity>? muscleIntensities,
    MuscleEffort? muscleEffort,
    bool? isLoading,
    String? errorMessage,
    String? selectedMuscleGroup,
  }) {
    return WorkoutState(
      exercises: exercises ?? this.exercises,
      muscleIntensities: muscleIntensities ?? this.muscleIntensities,
      muscleEffort: muscleEffort ?? this.muscleEffort,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedMuscleGroup: selectedMuscleGroup ?? this.selectedMuscleGroup,
    );
  }
}

class WorkoutNotifier extends Notifier<WorkoutState> {
  late final WorkoutApi _workoutApi = ref.read(workoutApiProvider);

  @override
  WorkoutState build() {
    Future.microtask(loadInitialData);
    return const WorkoutState(isLoading: true);
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true);
    try {
      final exercises = await _workoutApi.getExercises();
      final load = await _workoutApi.getMuscleLoad();
      state = WorkoutState(
        exercises: exercises,
        muscleIntensities: load.groups,
        muscleEffort: load.muscles,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void selectMuscleGroup(String group) {
    state = state.copyWith(selectedMuscleGroup: group);
  }

  /// Enregistre une séance terminée : renforce l'intensité du groupe
  /// musculaire travaillé (borné à 1.0) et met à jour la heatmap corporelle.
  ///
  /// [effort] ∈ [0, 1] — contribution de la séance (volume + RPE).
  void logSession({required String muscleGroup, required double effort}) {
    final updated = <MuscleIntensity>[];
    var found = false;
    for (final mi in state.muscleIntensities) {
      if (mi.group == muscleGroup) {
        found = true;
        updated.add(
          MuscleIntensity(
            group: mi.group,
            intensity: (mi.intensity + effort).clamp(0.0, 1.0),
          ),
        );
      } else {
        updated.add(mi);
      }
    }
    if (!found) {
      updated.add(
        MuscleIntensity(group: muscleGroup, intensity: effort.clamp(0.0, 1.0)),
      );
    }
    state = state.copyWith(muscleIntensities: updated);
  }

  Future<void> refreshIntensities() async {
    try {
      final load = await _workoutApi.getMuscleLoad();
      state = state.copyWith(
        muscleIntensities: load.groups,
        muscleEffort: load.muscles,
      );
    } catch (_) {}
  }

  /// Enregistre la séance effectuée sur le backend puis recalcule le score.
  ///
  /// Renvoie `null` en cas de succès, sinon un message d'erreur : l'écran de
  /// fin de séance l'affiche pour que l'échec d'enregistrement ne soit plus
  /// silencieux (sinon l'historique et la heatmap restent vides sans raison
  /// visible).
  Future<String?> submitLog({
    required String exerciseId,
    required int durationMinutes,
    required int rpe,
    required List<Map<String, dynamic>> sets,
  }) async {
    try {
      await _workoutApi.submitWorkoutLog(
        exerciseId: exerciseId,
        performedOn: DateTime.now(),
        durationMinutes: durationMinutes,
        rpe: rpe,
        sets: sets,
      );
      // La séance compte : on rafraîchit le score (home + profil) et la
      // heatmap musculaire (recalculée depuis les logs réels des 7 j).
      await ref.read(profileProvider.notifier).recomputeScore();
      await refreshIntensities();
      return null;
    } on DioException catch (e) {
      // Détaille l'erreur backend (ex : validation 400) au lieu de l'avaler.
      final status = e.response?.statusCode;
      final body = e.response?.data;
      return 'Enregistrement échoué'
          '${status != null ? ' (HTTP $status)' : ''}'
          '${body != null ? ' : $body' : ' : ${e.message}'}';
    } catch (e) {
      return 'Enregistrement échoué : $e';
    }
  }
}

final workoutApiProvider = Provider<WorkoutApi>(
  (ref) => WorkoutApi(ref.read(dioClientProvider)),
);

final workoutProvider = NotifierProvider<WorkoutNotifier, WorkoutState>(
  WorkoutNotifier.new,
);

/// Détail d'un exercice pour l'écran de démonstration (vidéo + instructions).
///
/// Optimisation : si la bibliothèque est déjà chargée (cas normal — on arrive
/// depuis la liste), on réutilise l'objet en mémoire sans appel réseau. Sinon
/// (deep link, état perdu) on interroge `GET /exercises/{id}`.
final exerciseDetailProvider = FutureProvider.family<WorkoutModel, String>((
  ref,
  id,
) async {
  final loaded = ref.watch(workoutProvider).exercises;
  for (final e in loaded) {
    if (e.id == id) return e;
  }
  return ref.read(workoutApiProvider).getExercise(id);
});

/// Parties du corps disponibles (navigation « Parcourir par zone »).
final bodyPartsProvider = FutureProvider<List<BodyPartModel>>((ref) async {
  return ref.read(workoutApiProvider).getBodyParts();
});

/// Exercices d'une zone du corps donnée (filtrés côté serveur).
final exercisesByBodyPartProvider =
    FutureProvider.family<List<WorkoutModel>, String>((ref, bodyPart) async {
      return ref.read(workoutApiProvider).getExercisesByBodyPart(bodyPart);
    });

/// Ce que l'adhérent a fait la dernière fois sur cet exercice — `null` s'il ne
/// l'a jamais réalisé.
///
/// Une erreur réseau est traitée comme « pas d'historique » plutôt que remontée
/// à l'écran : le bandeau de rappel est un bonus, il ne doit jamais empêcher de
/// s'entraîner.
final lastPerformanceProvider =
    FutureProvider.family<LastPerformance?, String>((ref, exerciseId) async {
      try {
        return await ref.read(workoutApiProvider).getLastPerformance(exerciseId);
      } catch (_) {
        return null;
      }
    });

/// Exercices **proches** de celui-ci : même muscle ciblé, autre exécution.
///
/// Calculé depuis le catalogue déjà en mémoire plutôt que demandé au serveur :
/// la donnée nécessaire (muscles cibles, groupe, matériel) y est déjà, et une
/// suggestion qui met une seconde à s'afficher n'est plus une suggestion.
///
/// Le classement privilégie, dans l'ordre : les muscles cibles réellement
/// partagés, un matériel DIFFÉRENT (c'est tout l'intérêt — « la machine est
/// prise, que faire à la place ? »), puis le même niveau de difficulté.
final similarExercisesProvider =
    Provider.family<List<WorkoutModel>, String>((ref, exerciseId) {
      final catalog = ref.watch(workoutProvider).exercises;
      WorkoutModel? source;
      for (final e in catalog) {
        if (e.id == exerciseId) {
          source = e;
          break;
        }
      }
      if (source == null) return const [];

      final sourceTargets = source.targetMusclesList
          .map((m) => m.toUpperCase())
          .toSet();

      final scored = <(WorkoutModel, int)>[];
      for (final candidate in catalog) {
        if (candidate.id == source.id) continue;
        if (candidate.muscleGroup != source.muscleGroup) continue;

        final shared = candidate.targetMusclesList
            .map((m) => m.toUpperCase())
            .where(sourceTargets.contains)
            .length;

        var score = shared * 10;
        if (candidate.equipment != source.equipment) score += 5;
        if (candidate.level == source.level) score += 3;
        if (candidate.hasVideo) score += 1;
        scored.add((candidate, score));
      }

      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return [for (final s in scored.take(6)) s.$1];
    });
