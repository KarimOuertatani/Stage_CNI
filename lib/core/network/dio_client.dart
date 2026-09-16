import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_token_store.dart';
import '../constants/api_constants.dart';
import 'api_exception.dart';

/// Client HTTP Dio configuré pour FitForge.
///
/// Gère l'injection du token JWT, le content-type, et la transformation
/// des erreurs Dio en [ApiException].
final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
      headers: {
        'Content-Type': ApiConstants.contentType,
        'Accept': ApiConstants.contentType,
      },
    ),
  );

  // Intercepteur pour ajouter le token JWT automatiquement.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthTokenStore.instance.read();
        if (token != null) {
          options.headers[ApiConstants.authHeader] =
              '${ApiConstants.bearerPrefix}$token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final exception = _mapDioError(error);
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            // On conserve la réponse d'origine pour pouvoir lire le message
            // métier renvoyé par le backend (ApiError.message).
            response: error.response,
            type: error.type,
            error: exception,
            message: exception.message,
          ),
        );
      },
    ),
  );

  return dio;
});

/// Convertit une [DioException] en [ApiException] lisible.
ApiException _mapDioError(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => ApiException.timeout(),
    DioExceptionType.connectionError => ApiException.network(),
    DioExceptionType.badResponse => ApiException.fromStatusCode(
      error.response?.statusCode ?? 500,
    ),
    _ => ApiException.unknown(error.message),
  };
}
