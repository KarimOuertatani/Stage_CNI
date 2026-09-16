import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/constants/api_constants.dart';
import 'user_model.dart';

/// Service API d'authentification (backend Spring Boot).
///
/// - `register` / `login` renvoient le token JWT (String).
/// - `getMe` renvoie le compte connecté (le token est injecté
///   automatiquement par l'intercepteur Dio).
class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  /// Connexion. Renvoie le token JWT.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    return response.data['token'] as String;
  }

  /// Inscription. La date de naissance est requise par le backend.
  ///
  /// **Ne renvoie plus de token** : le compte est créé désactivé et un code à
  /// 6 chiffres part par email. C'est [verifyEmail] qui délivre le JWT.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required DateTime birthDate,
    String? phoneNumber,
  }) async {
    await _dio.post(
      ApiConstants.register,
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
        // Format ISO attendu par LocalDate côté backend : yyyy-MM-dd
        'birthDate': _formatDate(birthDate),
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );
  }

  /// Inscription d'un COACH (pas de date de naissance requise).
  ///
  /// Même parcours que l'adhérent : compte désactivé, code envoyé par email.
  Future<void> registerCoach({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    String? headline,
    int? yearsExperience,
    List<String> specialties = const [],
  }) async {
    await _dio.post(
      ApiConstants.registerCoach,
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phoneNumber': ?phoneNumber,
        'headline': ?headline,
        'yearsExperience': ?yearsExperience,
        'specialties': specialties,
      },
    );
  }

  /// Valide le code reçu par email et **renvoie le token JWT** : c'est cette
  /// étape qui active le compte et connecte l'utilisateur.
  Future<String> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _dio.post(
      ApiConstants.verifyEmail,
      data: {'email': email, 'code': code},
    );
    return response.data['token'] as String;
  }

  /// Demande un nouveau code (le backend en autorise un par minute).
  Future<void> resendCode(String email) async {
    await _dio.post(ApiConstants.resendCode, data: {'email': email});
  }

  /// Récupère le compte connecté (token injecté par l'intercepteur).
  Future<UserModel> getMe() async {
    final response = await _dio.get(ApiConstants.me);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Envoie une photo de profil (image) et renvoie le compte mis à jour.
  Future<UserModel> updateAvatar(
    String path, {
    String? filename,
    String? contentType,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: filename,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ),
    });
    final response = await _dio.post(ApiConstants.avatar, data: form);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Supprime la photo de profil ; renvoie le compte mis à jour.
  Future<UserModel> removeAvatar() async {
    final response = await _dio.delete(ApiConstants.avatar);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Déconnexion : purement locale (l'API JWT est sans session).
  Future<void> logout() async {}

  /// Formate une date en `yyyy-MM-dd` (format LocalDate du backend).
  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
