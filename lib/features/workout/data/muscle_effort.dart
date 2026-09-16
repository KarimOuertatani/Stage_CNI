import 'muscle_catalog_3d.dart';

/// Effort réparti **muscle par muscle** à partir des séances réellement
/// enregistrées.
///
/// ── Pourquoi ce fichier existe ────────────────────────────────────────
/// La heatmap raisonnait jusqu'ici sur 6 groupes : un curl biceps allumait
/// tout le bras, une extension de quadriceps toute la jambe. Le modèle 3D
/// anatomique permet mieux, et les données pour le faire existent déjà :
/// chaque exercice porte ses `targetMuscles` / `secondaryMuscles` ExerciseDB,
/// avec un vocabulaire fermé et précis (`BRACHIORADIALIS`, `VASTUS`…).
///
/// On traduit donc chaque série vers les muscles du modèle via
/// [kExerciseDbMuscleMap], au lieu de la reporter en bloc sur son groupe.
class MuscleEffort {
  /// Séries pondérées accumulées par muscle, indexées par **nom de base** du
  /// catalogue 3D (`long_head_of_biceps_brachii`, sans le côté).
  final Map<String, double> setsByMuscle;

  const MuscleEffort(this.setsByMuscle);

  static const MuscleEffort empty = MuscleEffort({});

  /// Saturation de la heatmap : au-delà, le muscle est « au maximum ».
  /// Même repère que l'intensité par groupe, pour que les deux vues se lisent
  /// sur la même échelle.
  static const double fullWeekSets = 15.0;

  /// Une série sur le muscle **cible** compte pour une série pleine.
  static const double targetWeight = 1.0;

  /// Un muscle **secondaire** encaisse une part réduite du stimulus. Sans ce
  /// palier, un développé couché ferait chauffer les triceps autant que les
  /// pectoraux — ce que l'adhérent lirait comme une erreur.
  static const double secondaryWeight = 0.45;

  bool get isEmpty => setsByMuscle.isEmpty;

  /// Intensité 0.0–1.0 d'un muscle, par son nom de base.
  double intensityOf(String base) =>
      ((setsByMuscle[base] ?? 0.0) / fullWeekSets).clamp(0.0, 1.0);

  /// Intensité la plus élevée du corps (teinte du halo d'ambiance).
  double get peakIntensity {
    var max = 0.0;
    for (final sets in setsByMuscle.values) {
      if (sets > max) max = sets;
    }
    return (max / fullWeekSets).clamp(0.0, 1.0);
  }
}

/// Accumulateur : une série d'exercice à la fois.
class MuscleEffortBuilder {
  final Map<String, double> _sets = {};

  /// Ajoute une série de l'exercice décrit par ses muscles ExerciseDB.
  ///
  /// [primaryMuscle] est l'enum backend (`BICEPS`, `JAMBES`…), utilisé
  /// **uniquement** en repli quand ExerciseDB n'a pas renseigné de cible —
  /// l'effort se répartit alors sur les muscles emblématiques du groupe,
  /// faute de mieux.
  void addSet({
    String? targetMuscles,
    String? secondaryMuscles,
    String? primaryMuscle,
  }) {
    final targets = _split(targetMuscles);
    final secondaries = _split(secondaryMuscles);

    if (targets.isEmpty && secondaries.isEmpty) {
      _addAll(_fallbackMuscles(primaryMuscle), MuscleEffort.targetWeight);
      return;
    }
    for (final name in targets) {
      _addAll(kExerciseDbMuscleMap[name], MuscleEffort.targetWeight);
    }
    for (final name in secondaries) {
      _addAll(kExerciseDbMuscleMap[name], MuscleEffort.secondaryWeight);
    }
  }

  MuscleEffort build() => MuscleEffort(Map.unmodifiable(_sets));

  void _addAll(List<String>? bases, double weight) {
    if (bases == null) return;
    // Chaque muscle couvert prend le poids entier : une série de squat
    // travaille les quatre chefs du quadriceps, pas un quart de chacun.
    for (final base in bases) {
      _sets[base] = (_sets[base] ?? 0.0) + weight;
    }
  }

  static List<String> _split(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    return value
        .split(',')
        .map((m) => m.trim().toUpperCase())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Muscles emblématiques d'un groupe backend, pour les rares exercices sans
  /// données ExerciseDB (3 sur 220 au dernier import) et les exercices créés
  /// à la main.
  static List<String>? _fallbackMuscles(String? primaryMuscle) {
    final names = _fallbackByGroup[primaryMuscle];
    if (names == null) return null;
    return [for (final name in names) ...?kExerciseDbMuscleMap[name]];
  }

  static const Map<String, List<String>> _fallbackByGroup = {
    'PECTORAUX': [
      'PECTORALIS MAJOR STERNAL HEAD',
      'PECTORALIS MAJOR CLAVICULAR HEAD',
    ],
    'DOS': ['LATISSIMUS DORSI', 'TRAPEZIUS MIDDLE FIBERS', 'TERES MAJOR'],
    'EPAULES': ['ANTERIOR DELTOID', 'LATERAL DELTOID', 'POSTERIOR DELTOID'],
    'BICEPS': ['BICEPS BRACHII', 'BRACHIALIS'],
    'TRICEPS': ['TRICEPS BRACHII'],
    'ABDOS': ['RECTUS ABDOMINIS', 'OBLIQUES'],
    'JAMBES': ['QUADRICEPS', 'HAMSTRINGS'],
    'FESSIERS': ['GLUTEUS MAXIMUS', 'GLUTEUS MEDIUS'],
    'MOLLETS': ['GASTROCNEMIUS', 'SOLEUS'],
    // CARDIO : aucun muscle ciblé, la heatmap reste au repos.
  };
}
