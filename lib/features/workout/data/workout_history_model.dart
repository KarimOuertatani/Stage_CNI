import 'workout_model.dart';

/// Une série réalisée (lecture seule, pour l'historique).
class LoggedSet {
  final int setNumber;
  final int reps;
  final double weightKg;
  final bool completed;

  const LoggedSet({
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    required this.completed,
  });

  /// Volume de la série (reps × charge). Poids du corps → compte les reps.
  double get volume => reps * (weightKg > 0 ? weightKg : 1);
}

/// Un exercice réalisé dans une séance, avec ses séries regroupées.
class LoggedExercise {
  final String exerciseId;
  final String name;
  final String muscleGroup;
  final List<LoggedSet> sets;

  const LoggedExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    required this.sets,
  });

  int get totalReps => sets.fold(0, (s, e) => s + e.reps);
  double get totalVolume => sets.fold(0.0, (s, e) => s + e.volume);
  int get completedSets => sets.where((s) => s.completed).length;
}

/// Une séance réellement effectuée un jour donné (regroupe ses exercices).
class WorkoutLogEntry {
  final String id;
  final DateTime performedOn;
  final int? durationMinutes;
  final int? rpe;
  final List<LoggedExercise> exercises;

  const WorkoutLogEntry({
    required this.id,
    required this.performedOn,
    this.durationMinutes,
    this.rpe,
    required this.exercises,
  });

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets.length);
  double get totalVolume => exercises.fold(0.0, (s, e) => s + e.totalVolume);

  factory WorkoutLogEntry.fromJson(Map<String, dynamic> json) {
    final rawSets = (json['sets'] as List<dynamic>? ?? const []);

    // Regroupe les séries par exercice, en conservant l'ordre d'apparition.
    final order = <String>[];
    final byExercise = <String, List<LoggedSet>>{};
    final names = <String, String>{};
    final groups = <String, String>{};

    for (final s in rawSets) {
      final set = s as Map<String, dynamic>;
      final ex = set['exercise'] as Map<String, dynamic>?;
      if (ex == null) continue;
      final exId = ex['id'] as String? ?? 'inconnu';
      if (!byExercise.containsKey(exId)) {
        order.add(exId);
        byExercise[exId] = [];
        // Réutilise le mapping du référentiel (nom + libellé FR du groupe).
        final model = WorkoutModel.fromJson(ex);
        names[exId] = model.name;
        groups[exId] = model.muscleGroup;
      }
      byExercise[exId]!.add(
        LoggedSet(
          setNumber: (set['setNumber'] as num?)?.toInt() ?? 0,
          reps: (set['reps'] as num?)?.toInt() ?? 0,
          weightKg: (set['weightKg'] as num?)?.toDouble() ?? 0,
          completed: set['completed'] as bool? ?? true,
        ),
      );
    }

    final exercises = [
      for (final exId in order)
        LoggedExercise(
          exerciseId: exId,
          name: names[exId] ?? 'Exercice',
          muscleGroup: groups[exId] ?? 'Autre',
          sets: byExercise[exId]!
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
        ),
    ];

    return WorkoutLogEntry(
      id: json['id'] as String? ?? '',
      performedOn:
          DateTime.tryParse(json['performedOn'] as String? ?? '') ??
          DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      rpe: (json['rpe'] as num?)?.toInt(),
      exercises: exercises,
    );
  }
}
