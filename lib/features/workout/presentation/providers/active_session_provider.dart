import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/workout_model.dart';
import 'workout_provider.dart';

/// Une série réalisée pendant la séance en cours.
class SetDraft {
  final int reps;
  final double weightKg;
  final bool completed;
  const SetDraft({
    required this.reps,
    required this.weightKg,
    required this.completed,
  });
}

/// Un exercice terminé et ajouté à la séance en cours (avec ses séries).
class SessionExerciseDraft {
  final WorkoutModel exercise;
  final List<SetDraft> sets;
  final int rpe;
  const SessionExerciseDraft({
    required this.exercise,
    required this.sets,
    required this.rpe,
  });

  int get completedSets => sets.where((s) => s.completed).length;
  double get volume => sets
      .where((s) => s.completed)
      .fold(0.0, (v, s) => v + s.reps * s.weightKg);
}

/// État d'une séance EN COURS (plusieurs exercices, terminée en une fois).
///
/// Distinction clé : un *exercice* n'est pas une *séance*. On termine chaque
/// exercice (il s'ajoute ici), puis on termine la séance → un seul WorkoutLog
/// contenant toutes les séries de tous les exercices est envoyé au backend.
class ActiveSessionState {
  /// null = aucune séance en cours.
  final DateTime? startedAt;
  final List<SessionExerciseDraft> exercises;

  const ActiveSessionState({this.startedAt, this.exercises = const []});

  bool get isActive => startedAt != null;
  int get exerciseCount => exercises.length;
  int get totalSets => exercises.fold(0, (s, e) => s + e.completedSets);
  double get totalVolume => exercises.fold(0.0, (v, e) => v + e.volume);

  ActiveSessionState copyWith({
    DateTime? startedAt,
    List<SessionExerciseDraft>? exercises,
  }) {
    return ActiveSessionState(
      startedAt: startedAt ?? this.startedAt,
      exercises: exercises ?? this.exercises,
    );
  }
}

class ActiveSessionNotifier extends Notifier<ActiveSessionState> {
  @override
  ActiveSessionState build() => const ActiveSessionState();

  /// Ajoute un exercice terminé à la séance (la démarre si besoin).
  void addExercise(WorkoutModel exercise, List<SetDraft> sets, int rpe) {
    final started = state.startedAt ?? DateTime.now();
    state = ActiveSessionState(
      startedAt: started,
      exercises: [
        ...state.exercises,
        SessionExerciseDraft(exercise: exercise, sets: sets, rpe: rpe),
      ],
    );
  }

  void removeExerciseAt(int index) {
    if (index < 0 || index >= state.exercises.length) return;
    final list = [...state.exercises]..removeAt(index);
    // Plus aucun exercice → la séance n'a plus lieu d'être.
    state = list.isEmpty
        ? const ActiveSessionState()
        : state.copyWith(exercises: list);
  }

  /// Abandonne la séance en cours (rien n'est envoyé au backend).
  void cancel() => state = const ActiveSessionState();

  /// Termine la séance : envoie UN seul WorkoutLog avec toutes les séries de
  /// tous les exercices, recalcule le score et la heatmap, puis réinitialise.
  /// Renvoie `null` en cas de succès, sinon un message d'erreur.
  Future<String?> finish() async {
    if (!state.isActive || state.exercises.isEmpty) {
      return 'Aucun exercice dans la séance.';
    }
    final api = ref.read(workoutApiProvider);

    // Toutes les séries, chacune rattachée à son propre exercice.
    final sets = <Map<String, dynamic>>[];
    for (final ex in state.exercises) {
      var n = 1;
      for (final s in ex.sets) {
        sets.add({
          'exerciseId': ex.exercise.id,
          'setNumber': n++,
          'reps': s.reps,
          'weightKg': s.weightKg,
          'completed': s.completed,
        });
      }
    }

    // RPE de la séance = moyenne des RPE des exercices (borné 1..10).
    final rpe =
        (state.exercises.fold(0, (s, e) => s + e.rpe) / state.exercises.length)
            .round()
            .clamp(1, 10);
    final duration = DateTime.now().difference(state.startedAt!).inMinutes;

    try {
      await api.submitSession(
        performedOn: DateTime.now(),
        durationMinutes: duration,
        rpe: rpe,
        sets: sets,
      );
      await ref.read(profileProvider.notifier).recomputeScore();
      await ref.read(workoutProvider.notifier).refreshIntensities();
      state = const ActiveSessionState(); // séance clôturée
      return null;
    } on DioException catch (e) {
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

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSessionState>(
      ActiveSessionNotifier.new,
    );
