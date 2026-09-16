/// Modèles de la candidature coach.
///
/// Miroir des DTO `coaching/dto/CoachApplicationResponse` et
/// `CoachDocumentResponse` côté backend.
library;

/// État d'une candidature.
///
/// ```
///  inscription ──▶ DRAFT ──soumission──▶ PENDING ──▶ APPROVED
///                    ▲                      │
///                    └────── REJECTED ◀─────┘
/// ```
///
/// Le passage par `PENDING` **gèle** le dossier : pendant l'examen, ni les
/// justificatifs ni le profil ne peuvent changer. Sans ce gel, un coach
/// pourrait remplacer une pièce au moment où l'administrateur la consulte, et
/// la décision porterait sur des documents qui ne sont plus là.
enum CoachApplicationStatus {
  draft,
  pending,
  approved,
  rejected,
  suspended;

  static CoachApplicationStatus parse(String? raw) => switch (raw) {
    'DRAFT' => CoachApplicationStatus.draft,
    'PENDING' => CoachApplicationStatus.pending,
    'APPROVED' => CoachApplicationStatus.approved,
    'REJECTED' => CoachApplicationStatus.rejected,
    'SUSPENDED' => CoachApplicationStatus.suspended,
    // Un statut inconnu est traité comme DRAFT, l'état le plus restrictif :
    // en cas de doute, on n'ouvre pas l'espace coach.
    _ => CoachApplicationStatus.draft,
  };

  /// Vrai quand le coach peut encore modifier son dossier.
  bool get isEditable =>
      this == CoachApplicationStatus.draft || this == CoachApplicationStatus.rejected;

  /// Vrai quand le coach peut réellement exercer (annuaire, demandes, chat).
  bool get isActive => this == CoachApplicationStatus.approved;
}

/// Nature d'un justificatif.
enum CoachDocumentType {
  identity('IDENTITY', 'Pièce d\'identité', '🪪'),
  diploma('DIPLOMA', 'Diplôme', '🎓'),
  certification('CERTIFICATION', 'Certification', '📜'),
  other('OTHER', 'Autre justificatif', '📎');

  const CoachDocumentType(this.wire, this.label, this.emoji);

  /// Valeur transmise au serveur.
  final String wire;
  final String label;
  final String emoji;

  static CoachDocumentType parse(String? raw) => values.firstWhere(
    (t) => t.wire == raw,
    orElse: () => CoachDocumentType.other,
  );
}

/// Un justificatif déposé.
class CoachDocument {
  final String id;
  final CoachDocumentType type;

  /// Ce que le coach affirme que le document montre. Facultatif, mais c'est
  /// l'information que l'administrateur confronte à la photo.
  final String? label;

  final String? originalName;
  final String? contentType;
  final int? sizeBytes;
  final DateTime? uploadedAt;

  const CoachDocument({
    required this.id,
    required this.type,
    this.label,
    this.originalName,
    this.contentType,
    this.sizeBytes,
    this.uploadedAt,
  });

  bool get isImage => contentType?.startsWith('image/') ?? false;
  bool get isPdf => contentType == 'application/pdf';

  /// Ce qu'on affiche sous la vignette : l'intitulé s'il existe, sinon le nom
  /// du fichier, sinon le type. Un « document sans titre » n'aide personne.
  String get displayName => label ?? originalName ?? type.label;

  factory CoachDocument.fromJson(Map<String, dynamic> json) => CoachDocument(
    id: json['id'] as String,
    type: CoachDocumentType.parse(json['type'] as String?),
    label: json['label'] as String?,
    originalName: json['originalName'] as String?,
    contentType: json['contentType'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    uploadedAt: json['uploadedAt'] != null
        ? DateTime.tryParse(json['uploadedAt'] as String)
        : null,
  );
}

/// État complet de la candidature du coach connecté.
class CoachApplication {
  final CoachApplicationStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Motif du refus, **écrit par l'administrateur et affiché tel quel**.
  /// C'est ce qui rend un refus corrigeable.
  final String? rejectionReason;

  final List<CoachDocument> documents;

  /// Ce qu'il manque pour pouvoir soumettre, en phrases directement
  /// affichables.
  ///
  /// ⚠️ Cette liste vient du **serveur**, et l'application ne la recalcule
  /// jamais. Dupliquer la règle de complétude côté client produirait tôt ou
  /// tard l'écran le plus décourageant qui soit : un bouton « Envoyer » actif
  /// que le serveur refuse, sans que le coach puisse comprendre pourquoi.
  final List<String> missingRequirements;

  final bool canSubmit;

  const CoachApplication({
    required this.status,
    required this.documents,
    required this.missingRequirements,
    required this.canSubmit,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  bool get hasIdentityDocument =>
      documents.any((d) => d.type == CoachDocumentType.identity);

  bool get hasProofDocument => documents.any(
    (d) =>
        d.type == CoachDocumentType.diploma ||
        d.type == CoachDocumentType.certification,
  );

  factory CoachApplication.fromJson(Map<String, dynamic> json) => CoachApplication(
    status: CoachApplicationStatus.parse(json['status'] as String?),
    submittedAt: json['submittedAt'] != null
        ? DateTime.tryParse(json['submittedAt'] as String)
        : null,
    reviewedAt: json['reviewedAt'] != null
        ? DateTime.tryParse(json['reviewedAt'] as String)
        : null,
    rejectionReason: json['rejectionReason'] as String?,
    documents: (json['documents'] as List<dynamic>? ?? [])
        .map((e) => CoachDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    missingRequirements: (json['missingRequirements'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    canSubmit: json['canSubmit'] as bool? ?? false,
  );
}
