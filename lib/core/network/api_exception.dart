/// Exception personnalisée pour les erreurs API.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({required this.message, this.statusCode, this.data});

  factory ApiException.fromStatusCode(int code) {
    final message = switch (code) {
      400 => 'Requête invalide',
      401 => 'Non authentifié — veuillez vous reconnecter',
      403 => 'Accès refusé',
      404 => 'Ressource introuvable',
      422 => 'Données invalides',
      429 => 'Trop de requêtes — veuillez patienter',
      500 => 'Erreur serveur interne',
      503 => 'Service temporairement indisponible',
      _ => 'Erreur inattendue ($code)',
    };
    return ApiException(message: message, statusCode: code);
  }

  factory ApiException.network() =>
      const ApiException(message: 'Pas de connexion internet');

  factory ApiException.timeout() =>
      const ApiException(message: 'La requête a expiré — réessayez');

  factory ApiException.unknown([String? detail]) =>
      ApiException(message: detail ?? 'Une erreur inattendue est survenue');

  @override
  String toString() => 'ApiException($statusCode): $message';
}
