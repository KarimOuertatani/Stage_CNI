import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import 'ai_program_models.dart';
import 'program_models.dart';

/// Service API « Programmes & Séances » (backend Spring Boot).
///
/// Couvre : mes programmes (CRUD), modèles prêts (liste / détail / adoption),
/// séances (ajout / modif / suppression) et exercices placés (ajout / modif /
/// suppression). Toutes les écritures renvoient le [ProgramModel] complet à jour.
class ProgramApi {
  final Dio _dio;

  ProgramApi(this._dio);

  // ── Mes programmes ─────────────────────────────────────────────

  Future<List<ProgramModel>> getMyPrograms() async {
    final res = await _dio.get(ApiConstants.programs);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => ProgramModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProgramModel> getProgram(String id) async {
    final res = await _dio.get('${ApiConstants.programs}/$id');
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProgramModel> createProgram({
    required String title,
    String? description,
    String? goal,
    String? experienceLevel,
    int? durationWeeks,
  }) async {
    final res = await _dio.post(
      ApiConstants.programs,
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'goal': ?goal,
        'experienceLevel': ?experienceLevel,
        'durationWeeks': ?durationWeeks,
        'isTemplate': false,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProgramModel> updateProgram(
    String id, {
    required String title,
    String? description,
    String? goal,
    String? experienceLevel,
    int? durationWeeks,
  }) async {
    final res = await _dio.put(
      '${ApiConstants.programs}/$id',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'goal': ?goal,
        'experienceLevel': ?experienceLevel,
        'durationWeeks': ?durationWeeks,
        'isTemplate': false,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteProgram(String id) async {
    await _dio.delete('${ApiConstants.programs}/$id');
  }

  // ── Génération par l'IA FitForge ───────────────────────────────

  /// Le serveur est-il capable de générer un programme ?
  ///
  /// Faux quand aucune clé Gemini n'est configurée. On préfère masquer
  /// l'entrée plutôt qu'afficher un bouton qui ne mène qu'à une erreur.
  Future<bool> aiAvailable() async {
    final res = await _dio.get(ApiConstants.programAiStatus);
    return (res.data as Map<String, dynamic>)['available'] as bool? ?? false;
  }

  /// Génère un programme complet et le renvoie **déjà enregistré**.
  ///
  /// Long par nature : le serveur compose plusieurs séances avec leurs
  /// exercices, leurs charges et leurs consignes. Les timeouts par défaut du
  /// client (15 s) sont donc relevés pour cet appel — sans quoi l'app
  /// abandonnerait une génération qui allait aboutir, et l'adhérent perdrait
  /// son quota pour rien.
  Future<ProgramModel> generateAiProgram(
    AiProgramBrief brief, {
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.post(
      ApiConstants.programAiGenerate,
      data: brief.toJson(),
      cancelToken: cancelToken,
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Coach : programmes pour un adhérent ────────────────────────

  Future<ProgramModel> createProgramForMember(
    String memberUserId, {
    required String title,
    String? description,
    String? goal,
    String? experienceLevel,
    int? durationWeeks,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.programs}/for-member/$memberUserId',
      data: {
        'title': title,
        'description': ?description,
        'goal': ?goal,
        'experienceLevel': ?experienceLevel,
        'durationWeeks': ?durationWeeks,
        'isTemplate': false,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ProgramModel>> getProgramsForMember(String memberUserId) async {
    final res = await _dio.get(
      '${ApiConstants.programs}/for-member/$memberUserId',
    );
    return (res.data as List<dynamic>)
        .map((e) => ProgramModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Modèles (programmes prêts à l'emploi) ──────────────────────

  Future<List<ProgramModel>> getTemplates() async {
    final res = await _dio.get(ApiConstants.programTemplates);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => ProgramModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProgramModel> getTemplate(String id) async {
    final res = await _dio.get('${ApiConstants.programTemplates}/$id');
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Adopte un modèle → crée une copie personnelle modifiable et la renvoie.
  Future<ProgramModel> adoptTemplate(String id) async {
    final res = await _dio.post('${ApiConstants.programTemplates}/$id/adopt');
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Séances ────────────────────────────────────────────────────

  Future<ProgramModel> addSession(
    String programId, {
    required String title,
    int? dayOfWeek,
    int? orderIndex,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.programs}/$programId/sessions',
      data: {
        'title': title,
        'dayOfWeek': ?dayOfWeek,
        'orderIndex': ?orderIndex,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProgramModel> updateSession(
    String sessionId, {
    required String title,
    int? dayOfWeek,
    int? orderIndex,
  }) async {
    final res = await _dio.put(
      '${ApiConstants.sessions}/$sessionId',
      data: {
        'title': title,
        'dayOfWeek': ?dayOfWeek,
        'orderIndex': ?orderIndex,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProgramModel> deleteSession(String sessionId) async {
    final res = await _dio.delete('${ApiConstants.sessions}/$sessionId');
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Exercices placés dans une séance ───────────────────────────

  Future<ProgramModel> addSessionExercise(
    String sessionId, {
    required String exerciseId,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
    int? restSeconds,
    int? orderIndex,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.sessions}/$sessionId/exercises',
      data: {
        'exerciseId': exerciseId,
        'targetSets': ?targetSets,
        'targetReps': ?targetReps,
        'targetWeightKg': ?targetWeightKg,
        'restSeconds': ?restSeconds,
        'orderIndex': ?orderIndex,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProgramModel> updateSessionExercise(
    String sessionExerciseId, {
    required String exerciseId,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
    int? restSeconds,
    int? orderIndex,
  }) async {
    final res = await _dio.put(
      '${ApiConstants.sessionExercises}/$sessionExerciseId',
      data: {
        'exerciseId': exerciseId,
        'targetSets': ?targetSets,
        'targetReps': ?targetReps,
        'targetWeightKg': ?targetWeightKg,
        'restSeconds': ?restSeconds,
        'orderIndex': ?orderIndex,
      },
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProgramModel> deleteSessionExercise(String sessionExerciseId) async {
    final res = await _dio.delete(
      '${ApiConstants.sessionExercises}/$sessionExerciseId',
    );
    return ProgramModel.fromJson(res.data as Map<String, dynamic>);
  }
}
