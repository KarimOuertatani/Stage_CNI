import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/ai_coach_api.dart';
import '../../data/ai_coach_models.dart';

/// API du coach IA câblée sur Dio (JWT injecté automatiquement).
final aiCoachApiProvider = Provider<AiCoachApi>(
  (ref) => AiCoachApi(ref.read(dioClientProvider)),
);

/// Le coach IA est-il disponible sur ce serveur ?
///
/// Sert à **masquer l'entrée** du coach quand aucune clé Gemini n'est
/// configurée, plutôt qu'à afficher un bouton qui ne mène qu'à une erreur.
final aiCoachAvailableProvider = FutureProvider<bool>((ref) {
  return ref.read(aiCoachApiProvider).isAvailable();
});

/// État du fil avec le coach IA.
class AiCoachState {
  final List<AiCoachMessage> messages;

  /// Chargement initial du fil.
  final bool isLoading;

  /// Une question est partie, la réponse n'est pas revenue.
  ///
  /// Distinct de [isLoading] : le fil reste affiché et lisible pendant que le
  /// coach réfléchit.
  final bool isThinking;

  final String? errorMessage;

  const AiCoachState({
    this.messages = const [],
    this.isLoading = true,
    this.isThinking = false,
    this.errorMessage,
  });

  bool get isEmpty => messages.isEmpty;

  AiCoachState copyWith({
    List<AiCoachMessage>? messages,
    bool? isLoading,
    bool? isThinking,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiCoachState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isThinking: isThinking ?? this.isThinking,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Fil de discussion avec le coach IA.
///
/// **Affichage optimiste** : la question de l'adhérent apparaît immédiatement,
/// avant l'aller-retour serveur. Attendre la réponse pour l'afficher donnerait
/// l'impression que l'app a raté le tap — sur un échange qui peut prendre
/// plusieurs secondes, c'est intenable.
///
/// En cas d'échec, la question est **retirée** du fil et **rendue au champ de
/// saisie** (voir [failedText]) : elle n'est pas perdue, et l'adhérent n'a pas
/// à la retaper.
class AiCoachNotifier extends Notifier<AiCoachState> {
  CancelToken? _cancelToken;

  /// Texte à remettre dans le champ de saisie après un échec.
  String? failedText;

  @override
  AiCoachState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    Future.microtask(load);
    return const AiCoachState();
  }

  AiCoachApi get _api => ref.read(aiCoachApiProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      state = state.copyWith(messages: await _api.history(), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _message(e));
    }
  }

  /// Envoie une question et ajoute la réponse au fil.
  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.isThinking) return;

    failedText = null;
    final pending = AiCoachMessage.pending(question);
    state = state.copyWith(
      messages: [...state.messages, pending],
      isThinking: true,
      clearError: true,
    );

    _cancelToken = CancelToken();
    try {
      final reply = await _api.ask(question, cancelToken: _cancelToken);
      state = state.copyWith(
        messages: [...state.messages, reply],
        isThinking: false,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      // La question est retirée du fil : la laisser afficher sans réponse
      // ferait croire qu'elle a été reçue.
      failedText = question;
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != pending.id).toList(),
        isThinking: false,
        errorMessage: _message(e),
      );
    }
  }

  /// Efface le fil — le coach repart sans mémoire des échanges précédents.
  Future<void> clear() async {
    try {
      await _api.clear();
      state = state.copyWith(messages: [], clearError: true);
    } catch (e) {
      state = state.copyWith(errorMessage: _message(e));
    }
  }

  void dismissError() => state = state.copyWith(clearError: true);

  /// Message lisible : on privilégie celui renvoyé par le backend (périmètre,
  /// plafond horaire, coach non configuré…).
  String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Le coach met trop de temps à répondre. Réessayez.';
      }
      return 'Impossible de joindre le coach. Vérifiez votre connexion.';
    }
    return e.toString();
  }
}

final aiCoachProvider = NotifierProvider<AiCoachNotifier, AiCoachState>(
  AiCoachNotifier.new,
);
