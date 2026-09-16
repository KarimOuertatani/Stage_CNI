/// Auteur d'un message du fil avec le coach IA.
enum AiCoachRole { user, assistant }

/// Sujet d'un échange, tel que le coach l'a classé.
///
/// Ce n'est pas décoratif : c'est ce qui permet à l'interface de **signaler
/// visuellement** une demande déclinée ou un conseil portant sur une blessure.
/// L'adhérent voit pourquoi il a reçu ce message-là.
enum AiCoachTopic {
  entrainement,
  nutrition,
  blessure,
  motivation,

  /// Hors du périmètre sportif — la demande a été déclinée.
  horsSujet,
}

/// Un message du fil avec le coach IA.
///
/// Mappé depuis `AiCoachMessageResponse`. Le fil est **privé et unique** par
/// adhérent : aucune route ne prend d'identifiant d'utilisateur, tout est porté
/// par le JWT.
class AiCoachMessage {
  final String id;
  final AiCoachRole role;
  final String content;

  /// Sujet classé par le coach. `null` sur les messages de l'adhérent.
  final AiCoachTopic? topic;

  /// La demande sortait du périmètre sportif et a été déclinée.
  final bool refused;

  final DateTime createdAt;

  const AiCoachMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.topic,
    this.refused = false,
  });

  factory AiCoachMessage.fromJson(Map<String, dynamic> j) => AiCoachMessage(
    id: (j['id'] as String?) ?? '',
    role: _roleFrom(j['role'] as String?),
    content: (j['content'] as String?) ?? '',
    topic: _topicFrom(j['topic'] as String?),
    refused: j['refused'] as bool? ?? false,
    createdAt:
        DateTime.tryParse((j['createdAt'] as String?) ?? '')?.toLocal() ??
        DateTime.now(),
  );

  /// Message local affiché **avant** la réponse du serveur.
  ///
  /// La saisie doit apparaître instantanément : attendre l'aller-retour donne
  /// l'impression que l'app a raté le tap. L'identifiant temporaire est
  /// remplacé au rechargement du fil.
  factory AiCoachMessage.pending(String text) => AiCoachMessage(
    id: 'local-${DateTime.now().microsecondsSinceEpoch}',
    role: AiCoachRole.user,
    content: text,
    createdAt: DateTime.now(),
  );

  bool get isFromCoach => role == AiCoachRole.assistant;

  /// Conseil portant sur une blessure — l'interface l'accompagne d'un rappel.
  bool get isInjuryAdvice => topic == AiCoachTopic.blessure;

  static AiCoachRole _roleFrom(String? raw) =>
      raw == 'ASSISTANT' ? AiCoachRole.assistant : AiCoachRole.user;

  static AiCoachTopic? _topicFrom(String? raw) => switch (raw) {
    'ENTRAINEMENT' => AiCoachTopic.entrainement,
    'NUTRITION' => AiCoachTopic.nutrition,
    'BLESSURE' => AiCoachTopic.blessure,
    'MOTIVATION' => AiCoachTopic.motivation,
    'HORS_SUJET' => AiCoachTopic.horsSujet,
    _ => null,
  };
}
