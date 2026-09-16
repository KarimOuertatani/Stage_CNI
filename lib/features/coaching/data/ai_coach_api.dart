import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'ai_coach_models.dart';

/// Service API du **coach IA**.
///
/// Le fil est privé et unique par adhérent : aucune méthode ne prend
/// d'identifiant d'utilisateur, tout est porté par le JWT. La clé Gemini ne
/// quitte jamais le serveur — l'app n'appelle que notre backend.
class AiCoachApi {
  final Dio _dio;

  AiCoachApi(this._dio);

  /// Mon fil complet (`GET /coach-ai/messages`), du plus ancien au plus récent.
  Future<List<AiCoachMessage>> history() async {
    final res = await _dio.get(ApiConstants.coachAiMessages);
    return (res.data as List<dynamic>)
        .map((e) => AiCoachMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Le coach IA est-il disponible sur ce serveur ?
  /// (`GET /coach-ai/status`)
  ///
  /// Faux quand aucune clé Gemini n'est configurée. On s'en sert pour **masquer
  /// l'entrée** du coach IA plutôt que d'afficher un bouton qui ne mène qu'à une
  /// erreur.
  ///
  /// En cas d'échec réseau on répond `true` : mieux vaut laisser l'adhérent
  /// essayer et lire un message d'erreur clair que lui cacher une
  /// fonctionnalité qui marche peut-être très bien.
  Future<bool> isAvailable() async {
    try {
      final res = await _dio.get(ApiConstants.coachAiStatus);
      return (res.data as Map<String, dynamic>)['available'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Pose une question (`POST /coach-ai/messages`) et renvoie **la réponse du
  /// coach** — l'app connaît déjà la question.
  ///
  /// Le délai est plus long que la valeur par défaut : le serveur renvoie
  /// l'historique et le profil au modèle avant d'obtenir la réponse.
  Future<AiCoachMessage> ask(String text, {CancelToken? cancelToken}) async {
    final res = await _dio.post(
      ApiConstants.coachAiMessages,
      data: {'text': text},
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return AiCoachMessage.fromJson(res.data as Map<String, dynamic>);
  }

  /// Efface mon fil (`DELETE /coach-ai/messages`) — « nouvelle conversation ».
  Future<void> clear() async {
    await _dio.delete(ApiConstants.coachAiMessages);
  }
}
