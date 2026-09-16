import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import 'coaching_models.dart';
import 'presence_models.dart';

/// Service API du domaine coaching (annuaire, profils, suivis, chat).
class CoachingApi {
  final Dio _dio;

  CoachingApi(this._dio);

  // ── Annuaire / profils ─────────────────────────────────────────

  Future<List<CoachSummary>> getDirectory() async {
    final res = await _dio.get(ApiConstants.coaches);
    return (res.data as List<dynamic>)
        .map((e) => CoachSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CoachProfile> getCoachProfile(String coachUserId) async {
    final res = await _dio.get('${ApiConstants.coaches}/$coachUserId');
    return CoachProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachProfile> getMyCoachProfile() async {
    final res = await _dio.get(ApiConstants.coachMe);
    return CoachProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachProfile> upsertMyCoachProfile({
    String? headline,
    String? bio,
    int? yearsExperience,
    double? hourlyRate,
    String? city,
    bool? acceptingClients,
    required List<String> specialties,
    required List<Certification> certifications,
    required List<Education> educations,
    required List<ExperienceItem> experiences,
  }) async {
    final res = await _dio.put(
      ApiConstants.coachMe,
      data: {
        'headline': ?headline,
        'bio': ?bio,
        'yearsExperience': ?yearsExperience,
        'hourlyRate': ?hourlyRate,
        'city': ?city,
        'acceptingClients': ?acceptingClients,
        'specialties': specialties,
        'certifications': certifications.map((c) => c.toJson()).toList(),
        'educations': educations.map((e) => e.toJson()).toList(),
        'experiences': experiences.map((e) => e.toJson()).toList(),
      },
    );
    return CoachProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachDashboard> getDashboard() async {
    final res = await _dio.get(ApiConstants.coachDashboard);
    return CoachDashboard.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Relations de suivi ─────────────────────────────────────────

  Future<CoachingRelationship> requestCoaching(
    String coachUserId,
    String? message,
  ) async {
    final res = await _dio.post(
      '${ApiConstants.coaching}/coaches/$coachUserId/request',
      data: {'message': ?message},
    );
    return CoachingRelationship.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<CoachingRelationship>> getMyRelationships() async {
    final res = await _dio.get('${ApiConstants.coaching}/my');
    return (res.data as List<dynamic>)
        .map((e) => CoachingRelationship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CoachingRelationship>> getCoachRelationships({
    String? status,
  }) async {
    final res = await _dio.get(
      '${ApiConstants.coaching}/requests',
      queryParameters: {'status': ?status},
    );
    return (res.data as List<dynamic>)
        .map((e) => CoachingRelationship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CoachingRelationship> getRelationship(String relationshipId) async {
    final res = await _dio.get('${ApiConstants.coaching}/$relationshipId');
    return CoachingRelationship.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachingRelationship> accept(String relationshipId) async {
    final res = await _dio.post(
      '${ApiConstants.coaching}/$relationshipId/accept',
    );
    return CoachingRelationship.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachingRelationship> decline(String relationshipId) async {
    final res = await _dio.post(
      '${ApiConstants.coaching}/$relationshipId/decline',
    );
    return CoachingRelationship.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachingRelationship> end(String relationshipId) async {
    final res = await _dio.post('${ApiConstants.coaching}/$relationshipId/end');
    return CoachingRelationship.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Chat ───────────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessages(String relationshipId) async {
    final res = await _dio.get(
      '${ApiConstants.coaching}/$relationshipId/messages',
    );
    return (res.data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(
    String relationshipId, {
    String? content,
    String? attachmentUrl,
    ChatAttachmentKind? attachmentKind,
    String? attachmentName,
    int? attachmentSize,
    int? attachmentDurationSec,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.coaching}/$relationshipId/messages',
      data: {
        'content': ?content,
        'attachmentUrl': ?attachmentUrl,
        'attachmentKind': ?_kindToJson(attachmentKind),
        'attachmentName': ?attachmentName,
        'attachmentSize': ?attachmentSize,
        'attachmentDurationSec': ?attachmentDurationSec,
      },
    );
    return ChatMessage.fromJson(res.data as Map<String, dynamic>);
  }

  static String? _kindToJson(ChatAttachmentKind? k) => switch (k) {
    ChatAttachmentKind.image => 'IMAGE',
    ChatAttachmentKind.audio => 'AUDIO',
    ChatAttachmentKind.file => 'FILE',
    null => null,
  };

  Future<void> markRead(String relationshipId) async {
    await _dio.post('${ApiConstants.coaching}/$relationshipId/messages/read');
  }

  // ── Présence ───────────────────────────────────────────────────

  /// État de présence d'un interlocuteur, à l'ouverture d'une conversation.
  ///
  /// Ne sert qu'à afficher le statut **immédiatement** : les changements qui
  /// suivent arrivent par WebSocket, l'app ne sonde jamais.
  Future<Presence> getPresence(String userId) async {
    final res = await _dio.get('/presence/$userId');
    return Presence.fromJson(res.data as Map<String, dynamic>);
  }

  /// Présence de tous mes interlocuteurs — un seul appel pour la liste des
  /// conversations, plutôt qu'une requête par ligne.
  Future<List<Presence>> getPartnersPresence() async {
    final res = await _dio.get('/presence/partners');
    return (res.data as List<dynamic>)
        .map((e) => Presence.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
