import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import 'body_part_model.dart';
import 'last_performance.dart';
import 'muscle_effort.dart';
import 'workout_history_model.dart';
import 'workout_model.dart';

/// Service API entraînement (backend Spring Boot).
class WorkoutApi {
  final Dio _dio;

  WorkoutApi(this._dio);

  /// Récupère tout le référentiel d'exercices (`GET /exercises`).
  Future<List<WorkoutModel>> getExercises() async {
    final response = await _dio.get(ApiConstants.exercises);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => WorkoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Récupère les exercices d'un groupe musculaire (filtre côté client, car
  /// le backend filtre par enum ; on garde le filtrage FR côté écran).
  Future<List<WorkoutModel>> getExercisesByGroup(String group) async {
    final all = await getExercises();
    return all.where((e) => e.muscleGroup == group).toList();
  }

  /// Récupère le détail complet d'un exercice (`GET /exercises/{id}`) : vidéo,
  /// instructions, conseils, variations, images. Sert l'écran de détail quand
  /// la liste n'est pas déjà chargée en mémoire (deep link).
  Future<WorkoutModel> getExercise(String id) async {
    final response = await _dio.get('${ApiConstants.exercises}/$id');
    return WorkoutModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Liste des parties du corps disponibles (`GET /bodyparts`) : libellé FR,
  /// image illustrative et nombre d'exercices. Pour la navigation « par zone ».
  Future<List<BodyPartModel>> getBodyParts() async {
    final response = await _dio.get(ApiConstants.bodyParts);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => BodyPartModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Exercices d'une zone du corps (`GET /exercises?bodyPart=CHEST`). Filtrage
  /// côté serveur sur le champ `bodyPart` (valeurs ExerciseDB en majuscules).
  Future<List<WorkoutModel>> getExercisesByBodyPart(String bodyPart) async {
    final response = await _dio.get(
      ApiConstants.exercises,
      queryParameters: {'bodyPart': bodyPart},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => WorkoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Favoris ────────────────────────────────────────────────────────────

  /// Mes exercices favoris (`GET /exercises/favorites`), le dernier ajouté
  /// en tête.
  Future<List<WorkoutModel>> getFavorites() async {
    final response = await _dio.get('${ApiConstants.exercises}/favorites');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => WorkoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ajoute un exercice aux favoris. Idempotent côté serveur : réémettre
  /// l'appel après une coupure réseau ne crée pas de doublon.
  Future<void> addFavorite(String exerciseId) async {
    await _dio.put('${ApiConstants.exercises}/$exerciseId/favorite');
  }

  /// Retire un exercice des favoris. Idempotent lui aussi.
  Future<void> removeFavorite(String exerciseId) async {
    await _dio.delete('${ApiConstants.exercises}/$exerciseId/favorite');
  }

  // ── Dernière performance ───────────────────────────────────────────────

  /// Ce que l'adhérent a fait la dernière fois sur cet exercice
  /// (`GET /workout-logs/last?exerciseId=`).
  ///
  /// Renvoie `null` s'il ne l'a jamais réalisé — le serveur répond alors 204,
  /// et « jamais fait » est le cas normal du premier jour, pas une erreur.
  Future<LastPerformance?> getLastPerformance(String exerciseId) async {
    final response = await _dio.get(
      '${ApiConstants.workoutLogs}/last',
      queryParameters: {'exerciseId': exerciseId},
    );
    final data = response.data;
    if (data == null || data is! Map<String, dynamic>) return null;
    return LastPerformance.fromJson(data);
  }

  /// Charge d'entraînement des **7 derniers jours**, calculée à partir des
  /// séances réellement enregistrées (`GET /workout-logs?from=&to=`).
  ///
  /// Persistée côté serveur : la heatmap 2D/3D reflète donc l'historique réel
  /// et ne se réinitialise plus au redémarrage de l'app.
  ///
  /// Renvoie **deux granularités**, calculées en un seul passage :
  ///  • par **groupe** (6 zones) pour la silhouette 2D, les cartes et le
  ///    résumé — intensité = séries réalisées sur le groupe / 15 ;
  ///  • par **muscle** pour le modèle 3D anatomique — chaque série est
  ///    ventilée sur les muscles qu'ExerciseDB déclare réellement sollicités
  ///    (voir [MuscleEffortBuilder]).
  Future<MuscleLoad> getMuscleLoad() async {
    final today = DateTime.now();
    final from = today.subtract(const Duration(days: 6));

    final response = await _dio.get(
      ApiConstants.workoutLogs,
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(today)},
    );
    final logs = response.data as List<dynamic>;

    // On part des 6 groupes de la heatmap, tous à 0 (zones au repos visibles).
    final setCounts = <String, int>{for (final g in _heatmapGroups) g: 0};
    final effort = MuscleEffortBuilder();

    for (final log in logs) {
      final sets = (log as Map<String, dynamic>)['sets'] as List<dynamic>?;
      if (sets == null) continue;
      for (final s in sets) {
        final set = s as Map<String, dynamic>;
        if (set['completed'] == false) continue; // série abandonnée
        final exercise = set['exercise'] as Map<String, dynamic>?;
        final primaryMuscle = exercise?['primaryMuscle'] as String?;

        effort.addSet(
          targetMuscles: exercise?['targetMuscles'] as String?,
          secondaryMuscles: exercise?['secondaryMuscles'] as String?,
          primaryMuscle: primaryMuscle,
        );

        final group = _heatmapGroupFromMuscle(primaryMuscle);
        if (group == null) continue; // cardio / non mappé
        setCounts[group] = (setCounts[group] ?? 0) + 1;
      }
    }

    return MuscleLoad(
      groups: _heatmapGroups
          .map(
            (g) => MuscleIntensity(
              group: g,
              intensity: (setCounts[g]! / MuscleEffort.fullWeekSets).clamp(
                0.0,
                1.0,
              ),
            ),
          )
          .toList(),
      muscles: effort.build(),
    );
  }

  /// Les 6 groupes affichés par la visualisation corporelle 2D/3D.
  static const List<String> _heatmapGroups = [
    'Pectoraux',
    'Dos',
    'Épaules',
    'Bras',
    'Abdominaux',
    'Jambes',
  ];

  /// Enum backend `MuscleGroup` -> groupe de la heatmap (ou null si non mappé).
  /// Biceps/triceps -> Bras ; fessiers/mollets -> Jambes ; cardio -> ignoré.
  static String? _heatmapGroupFromMuscle(String? muscle) {
    switch (muscle) {
      case 'PECTORAUX':
        return 'Pectoraux';
      case 'DOS':
        return 'Dos';
      case 'EPAULES':
        return 'Épaules';
      case 'BICEPS':
      case 'TRICEPS':
        return 'Bras';
      case 'ABDOS':
        return 'Abdominaux';
      case 'JAMBES':
      case 'FESSIERS':
      case 'MOLLETS':
        return 'Jambes';
      default:
        return null;
    }
  }

  /// Séances réellement effectuées un jour donné (`GET /workout-logs?from=&to=`).
  /// Utilisé par l'écran Historique pour revoir les exercices d'une journée.
  Future<List<WorkoutLogEntry>> getLogsForDay(DateTime day) async {
    final d = _formatDate(day);
    final response = await _dio.get(
      ApiConstants.workoutLogs,
      queryParameters: {'from': d, 'to': d},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => WorkoutLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Enregistre une séance effectuée (`POST /workout-logs`).
  /// [sets] : liste d'objets { setNumber, reps, weightKg, completed }.
  Future<void> submitWorkoutLog({
    required String exerciseId,
    required DateTime performedOn,
    int? durationMinutes,
    int? rpe,
    required List<Map<String, dynamic>> sets,
  }) async {
    final data = <String, dynamic>{
      'performedOn': _formatDate(performedOn),
      // Chaque série référence l'exercice courant du logging.
      'sets': sets.map((s) => {'exerciseId': exerciseId, ...s}).toList(),
    };
    if (durationMinutes != null) data['durationMinutes'] = durationMinutes;
    if (rpe != null) data['rpe'] = rpe;
    await _dio.post(ApiConstants.workoutLogs, data: data);
  }

  /// Enregistre une **séance complète** : un seul WorkoutLog dont les séries
  /// peuvent porter sur plusieurs exercices (chaque set porte son `exerciseId`).
  Future<void> submitSession({
    required DateTime performedOn,
    int? durationMinutes,
    int? rpe,
    required List<Map<String, dynamic>> sets,
  }) async {
    final data = <String, dynamic>{
      'performedOn': _formatDate(performedOn),
      'sets': sets,
    };
    if (durationMinutes != null) data['durationMinutes'] = durationMinutes;
    if (rpe != null) data['rpe'] = rpe;
    await _dio.post(ApiConstants.workoutLogs, data: data);
  }

  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
