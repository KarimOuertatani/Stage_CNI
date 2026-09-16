import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../../core/constants/api_constants.dart';
import 'coaching_models.dart';
import 'presence_models.dart';

/// Signal « en train d'écrire » reçu d'un interlocuteur.
class TypingSignal {
  final String relationshipId;
  final String userId;
  final bool typing;

  const TypingSignal({
    required this.relationshipId,
    required this.userId,
    required this.typing,
  });

  factory TypingSignal.fromJson(Map<String, dynamic> j) => TypingSignal(
    relationshipId: j['relationshipId'] as String? ?? '',
    userId: j['userId'] as String? ?? '',
    typing: j['typing'] as bool? ?? false,
  );
}

/// Pont WebSocket/STOMP du chat temps réel.
///
/// Une seule connexion porte **trois flux privés**, tous poussés par le serveur
/// sur des files propres à l'utilisateur connecté :
///
/// | Destination | Contenu |
/// |---|---|
/// | `/user/queue/messages` | nouveaux messages |
/// | `/user/queue/presence` | un interlocuteur se connecte / se déconnecte |
/// | `/user/queue/typing`   | un interlocuteur écrit / s'arrête d'écrire |
///
/// L'authentification se fait au CONNECT via `Authorization: Bearer <jwt>`.
/// C'est cette connexion qui **définit** la présence côté serveur : l'ouvrir,
/// c'est se déclarer en ligne ; la fermer (ou fermer l'app, ou perdre le
/// réseau), c'est repasser hors ligne. Aucun code de nettoyage n'est nécessaire.
///
/// Le socket reste une couche de *notification* : l'historique et l'envoi
/// passent par REST, source de vérité. L'UI fonctionne donc même socket coupé.
class ChatSocket {
  final String token;

  /// Nouveau message reçu.
  final void Function(ChatMessage message) onMessage;

  /// Changement de présence d'un interlocuteur.
  final void Function(Presence presence)? onPresence;

  /// Un interlocuteur commence ou arrête d'écrire.
  final void Function(TypingSignal signal)? onTyping;

  /// État de **notre propre** connexion au serveur (à ne pas confondre avec la
  /// présence de l'interlocuteur — c'était la confusion du code précédent).
  final void Function(bool connected)? onStatus;

  StompClient? _client;

  ChatSocket({
    required this.token,
    required this.onMessage,
    this.onPresence,
    this.onTyping,
    this.onStatus,
  });

  bool get isConnected => _client?.connected ?? false;

  void connect() {
    if (_client != null) return;
    _client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) => onStatus?.call(false),
        onWebSocketError: (_) => onStatus?.call(false),
        onStompError: (_) => onStatus?.call(false),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 4),
        heartbeatIncoming: const Duration(seconds: 15),
        heartbeatOutgoing: const Duration(seconds: 15),
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    onStatus?.call(true);

    _subscribe('/user/queue/messages', (json) {
      onMessage(ChatMessage.fromJson(json));
    });

    if (onPresence != null) {
      _subscribe('/user/queue/presence', (json) {
        onPresence!(Presence.fromJson(json));
      });
    }

    if (onTyping != null) {
      _subscribe('/user/queue/typing', (json) {
        onTyping!(TypingSignal.fromJson(json));
      });
    }
  }

  /// Abonnement STOMP tolérant : un corps inattendu est ignoré plutôt que de
  /// faire tomber toute la connexion (le REST garde la cohérence).
  void _subscribe(
    String destination,
    void Function(Map<String, dynamic>) handle,
  ) {
    _client!.subscribe(
      destination: destination,
      callback: (StompFrame f) {
        final body = f.body;
        if (body == null || body.isEmpty) return;
        try {
          handle(jsonDecode(body) as Map<String, dynamic>);
        } catch (_) {
          // Corps illisible : on ignore silencieusement.
        }
      },
    );
  }

  /// Annonce que l'utilisateur écrit (ou s'est arrêté) dans un fil.
  ///
  /// Envoi **best-effort** : si le socket est coupé, le signal est simplement
  /// abandonné. Une frappe n'a aucune valeur différée, il ne faut donc ni la
  /// mettre en file d'attente ni remonter d'erreur.
  void sendTyping(String relationshipId, {required bool typing}) {
    final client = _client;
    if (client == null || !client.connected) return;
    try {
      client.send(
        destination: '/app/typing',
        body: jsonEncode({'relationshipId': relationshipId, 'typing': typing}),
      );
    } catch (_) {
      // Best-effort : jamais d'erreur visible pour un signal éphémère.
    }
  }

  void dispose() {
    _client?.deactivate();
    _client = null;
  }
}
