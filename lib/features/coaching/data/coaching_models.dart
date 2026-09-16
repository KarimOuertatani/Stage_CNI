/// Modèles du domaine « Coaching » (coachs, suivis, chat).
///
/// Mappés depuis le backend : CoachSummaryResponse, CoachProfileResponse,
/// CoachingRelationshipResponse, ChatMessageResponse, PersonRef.
library;

// ── Coach : résumé (annuaire) ─────────────────────────────────────────

class CoachSummary {
  final String userId;
  final String profileId;
  final String fullName;
  final String? avatarUrl;
  final String? headline;
  final String? city;
  final int? yearsExperience;
  final List<String> specialties; // enums backend
  final double ratingAverage;
  final int ratingCount;
  final bool acceptingClients;

  const CoachSummary({
    required this.userId,
    required this.profileId,
    required this.fullName,
    this.avatarUrl,
    this.headline,
    this.city,
    this.yearsExperience,
    this.specialties = const [],
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.acceptingClients = true,
  });

  factory CoachSummary.fromJson(Map<String, dynamic> j) => CoachSummary(
    userId: j['userId'] as String,
    profileId: j['profileId'] as String? ?? '',
    fullName: j['fullName'] as String? ?? '',
    avatarUrl: j['avatarUrl'] as String?,
    headline: j['headline'] as String?,
    city: j['city'] as String?,
    yearsExperience: j['yearsExperience'] as int?,
    specialties:
        (j['specialties'] as List<dynamic>?)?.cast<String>() ?? const [],
    ratingAverage: (j['ratingAverage'] as num?)?.toDouble() ?? 0,
    ratingCount: j['ratingCount'] as int? ?? 0,
    acceptingClients: j['acceptingClients'] as bool? ?? true,
  );

  String get initials => _initialsFrom(fullName);
}

// ── Coach : profil complet ────────────────────────────────────────────

class CoachProfile {
  final String userId;
  final String profileId;
  final String fullName;
  final String? avatarUrl;
  final String? headline;
  final String? bio;
  final int? yearsExperience;
  final double? hourlyRate;
  final String? city;
  final bool acceptingClients;
  final double ratingAverage;
  final int ratingCount;
  final List<String> specialties;
  final List<Certification> certifications;
  final List<Education> educations;
  final List<ExperienceItem> experiences;

  /// Statut de la relation du consultant avec ce coach (null = aucune).
  final String? viewerRelationStatus; // PENDING/ACCEPTED/DECLINED/ENDED
  final String? viewerRelationshipId;

  const CoachProfile({
    required this.userId,
    required this.profileId,
    required this.fullName,
    this.avatarUrl,
    this.headline,
    this.bio,
    this.yearsExperience,
    this.hourlyRate,
    this.city,
    this.acceptingClients = true,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.specialties = const [],
    this.certifications = const [],
    this.educations = const [],
    this.experiences = const [],
    this.viewerRelationStatus,
    this.viewerRelationshipId,
  });

  factory CoachProfile.fromJson(Map<String, dynamic> j) => CoachProfile(
    userId: j['userId'] as String,
    profileId: j['profileId'] as String? ?? '',
    fullName: j['fullName'] as String? ?? '',
    avatarUrl: j['avatarUrl'] as String?,
    headline: j['headline'] as String?,
    bio: j['bio'] as String?,
    yearsExperience: j['yearsExperience'] as int?,
    hourlyRate: (j['hourlyRate'] as num?)?.toDouble(),
    city: j['city'] as String?,
    acceptingClients: j['acceptingClients'] as bool? ?? true,
    ratingAverage: (j['ratingAverage'] as num?)?.toDouble() ?? 0,
    ratingCount: j['ratingCount'] as int? ?? 0,
    specialties:
        (j['specialties'] as List<dynamic>?)?.cast<String>() ?? const [],
    certifications:
        (j['certifications'] as List<dynamic>?)
            ?.map((e) => Certification.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    educations:
        (j['educations'] as List<dynamic>?)
            ?.map((e) => Education.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    experiences:
        (j['experiences'] as List<dynamic>?)
            ?.map((e) => ExperienceItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    viewerRelationStatus: j['viewerRelationStatus'] as String?,
    viewerRelationshipId: j['viewerRelationshipId'] as String?,
  );

  String get initials => _initialsFrom(fullName);
}

class Certification {
  final String? id;
  final String title;
  final String? organization;
  final int? year;
  final String? credentialUrl;

  const Certification({
    this.id,
    required this.title,
    this.organization,
    this.year,
    this.credentialUrl,
  });

  factory Certification.fromJson(Map<String, dynamic> j) => Certification(
    id: j['id'] as String?,
    title: j['title'] as String? ?? '',
    organization: j['organization'] as String?,
    year: j['year'] as int?,
    credentialUrl: j['credentialUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'organization': ?organization,
    'year': ?year,
    'credentialUrl': ?credentialUrl,
  };
}

class Education {
  final String? id;
  final String degree;
  final String? institution;
  final String? fieldOfStudy;
  final int? year;

  const Education({
    this.id,
    required this.degree,
    this.institution,
    this.fieldOfStudy,
    this.year,
  });

  factory Education.fromJson(Map<String, dynamic> j) => Education(
    id: j['id'] as String?,
    degree: j['degree'] as String? ?? '',
    institution: j['institution'] as String?,
    fieldOfStudy: j['fieldOfStudy'] as String?,
    year: j['year'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'degree': degree,
    'institution': ?institution,
    'fieldOfStudy': ?fieldOfStudy,
    'year': ?year,
  };
}

class ExperienceItem {
  final String? id;
  final String title;
  final String? organization;
  final int? startYear;
  final int? endYear;
  final String? description;

  const ExperienceItem({
    this.id,
    required this.title,
    this.organization,
    this.startYear,
    this.endYear,
    this.description,
  });

  factory ExperienceItem.fromJson(Map<String, dynamic> j) => ExperienceItem(
    id: j['id'] as String?,
    title: j['title'] as String? ?? '',
    organization: j['organization'] as String?,
    startYear: j['startYear'] as int?,
    endYear: j['endYear'] as int?,
    description: j['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'organization': ?organization,
    'startYear': ?startYear,
    'endYear': ?endYear,
    'description': ?description,
  };

  String get periodLabel {
    if (startYear == null) return '';
    final end = endYear?.toString() ?? 'Aujourd\'hui';
    return '$startYear – $end';
  }
}

// ── Personne (ref) ────────────────────────────────────────────────────

class PersonRef {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String? headline;

  const PersonRef({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.headline,
  });

  factory PersonRef.fromJson(Map<String, dynamic> j) => PersonRef(
    userId: j['userId'] as String,
    fullName: j['fullName'] as String? ?? '',
    avatarUrl: j['avatarUrl'] as String?,
    headline: j['headline'] as String?,
  );

  String get initials => _initialsFrom(fullName);
}

// ── Relation de suivi ─────────────────────────────────────────────────

class CoachingRelationship {
  final String id;
  final String status; // PENDING/ACCEPTED/DECLINED/ENDED
  final String? requestMessage;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final PersonRef coach;
  final PersonRef member;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const CoachingRelationship({
    required this.id,
    required this.status,
    this.requestMessage,
    this.createdAt,
    this.respondedAt,
    required this.coach,
    required this.member,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory CoachingRelationship.fromJson(Map<String, dynamic> j) =>
      CoachingRelationship(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'PENDING',
        requestMessage: j['requestMessage'] as String?,
        createdAt: _parseDate(j['createdAt']),
        respondedAt: _parseDate(j['respondedAt']),
        coach: PersonRef.fromJson(j['coach'] as Map<String, dynamic>),
        member: PersonRef.fromJson(j['member'] as Map<String, dynamic>),
        lastMessage: j['lastMessage'] as String?,
        lastMessageAt: _parseDate(j['lastMessageAt']),
        unreadCount: j['unreadCount'] as int? ?? 0,
      );

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
}

// ── Message de chat ───────────────────────────────────────────────────

/// Nature d'une piece jointe (aligne sur l'enum backend `MediaKind`).
enum ChatAttachmentKind { image, audio, file }

ChatAttachmentKind? _attachmentKindFrom(String? v) => switch (v) {
  'IMAGE' => ChatAttachmentKind.image,
  'AUDIO' => ChatAttachmentKind.audio,
  'FILE' => ChatAttachmentKind.file,
  _ => null,
};

class ChatMessage {
  final String id;
  final String relationshipId;
  final String senderId;
  final String senderName;
  final String content;

  /// Piece jointe optionnelle (image, vocal, document).
  final String? attachmentUrl;
  final ChatAttachmentKind? attachmentKind;
  final String? attachmentName;
  final int? attachmentSize;
  final int? attachmentDurationSec;

  final DateTime? sentAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.relationshipId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.attachmentUrl,
    this.attachmentKind,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentDurationSec,
    this.sentAt,
    this.readAt,
  });

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get hasText => content.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    relationshipId: j['relationshipId'] as String? ?? '',
    senderId: j['senderId'] as String? ?? '',
    senderName: j['senderName'] as String? ?? '',
    content: j['content'] as String? ?? '',
    attachmentUrl: j['attachmentUrl'] as String?,
    attachmentKind: _attachmentKindFrom(j['attachmentKind'] as String?),
    attachmentName: j['attachmentName'] as String?,
    attachmentSize: (j['attachmentSize'] as num?)?.toInt(),
    attachmentDurationSec: (j['attachmentDurationSec'] as num?)?.toInt(),
    sentAt: _parseDate(j['sentAt']),
    readAt: _parseDate(j['readAt']),
  );
}

// ── Dashboard coach ───────────────────────────────────────────────────

class CoachDashboard {
  final int pendingRequests;
  final int activeClients;
  final int unreadMessages;

  const CoachDashboard({
    this.pendingRequests = 0,
    this.activeClients = 0,
    this.unreadMessages = 0,
  });

  factory CoachDashboard.fromJson(Map<String, dynamic> j) => CoachDashboard(
    pendingRequests: (j['pendingRequests'] as num?)?.toInt() ?? 0,
    activeClients: (j['activeClients'] as num?)?.toInt() ?? 0,
    unreadMessages: (j['unreadMessages'] as num?)?.toInt() ?? 0,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────

DateTime? _parseDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v as String)?.toLocal();

String _initialsFrom(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Toutes les spécialités disponibles (valeur backend + libellé FR).
const List<({String value, String label})> kSpecialties = [
  (value: 'MUSCULATION', label: 'Musculation'),
  (value: 'PERTE_POIDS', label: 'Perte de poids'),
  (value: 'PRISE_MASSE', label: 'Prise de masse'),
  (value: 'FORCE', label: 'Force'),
  (value: 'CROSSFIT', label: 'CrossFit'),
  (value: 'CARDIO_ENDURANCE', label: 'Cardio / Endurance'),
  (value: 'YOGA_MOBILITE', label: 'Yoga / Mobilité'),
  (value: 'NUTRITION', label: 'Nutrition'),
  (value: 'PREPARATION_PHYSIQUE', label: 'Préparation physique'),
  (value: 'REEDUCATION', label: 'Rééducation'),
  (value: 'HALTEROPHILIE', label: 'Haltérophilie'),
  (value: 'FITNESS_FEMININ', label: 'Fitness féminin'),
];

String specialtyLabel(String value) {
  for (final s in kSpecialties) {
    if (s.value == value) return s.label;
  }
  return value;
}

String coachingStatusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'En attente';
    case 'ACCEPTED':
      return 'Suivi actif';
    case 'DECLINED':
      return 'Refusée';
    case 'ENDED':
      return 'Terminé';
    default:
      return status;
  }
}
