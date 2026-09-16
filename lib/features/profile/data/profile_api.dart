import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import 'profile_model.dart';

/// Service API du profil et du score (backend Spring Boot).
class ProfileApi {
  final Dio _dio;

  ProfileApi(this._dio);

  /// Récupère mon profil (`GET /profile`).
  Future<ProfileModel> getProfile() async {
    final response = await _dio.get(ApiConstants.profile);
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Crée/met à jour mon profil (`PUT /profile`).
  /// Seuls les champs non nuls sont envoyés (le backend ignore les nuls,
  /// donc on ne remplace pas les valeurs existantes non modifiées).
  Future<ProfileModel> updateProfile(Map<String, dynamic> fields) async {
    final data = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value != null) data[key] = value;
    });
    final response = await _dio.put(ApiConstants.profile, data: data);
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Mon score le plus récent (`GET /score/current`).
  /// Renvoie null si aucun score n'a encore été calculé (404).
  Future<TrainingScoreModel?> getCurrentScore() async {
    try {
      final response = await _dio.get(ApiConstants.scoreCurrent);
      return TrainingScoreModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Recalcule mon score (`POST /score/recompute`).
  Future<TrainingScoreModel> recomputeScore() async {
    final response = await _dio.post(ApiConstants.scoreRecompute);
    return TrainingScoreModel.fromJson(response.data as Map<String, dynamic>);
  }
}
