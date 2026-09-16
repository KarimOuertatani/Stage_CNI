/// Modèles du signalement de problème.
///
/// Miroir des DTO `admin/dto/CreateProblemReportRequest` et
/// `ProblemReportResponse` côté backend.
///
/// La fonctionnalité sert **les deux rôles** : un adhérent comme un coach
/// peuvent signaler. Le serveur fige le rôle au moment de l'envoi, ce qui
/// indique à l'administration depuis quel espace le problème a été rencontré —
/// « le bouton ne marche pas » n'a pas le même sens côté adhérent et côté
/// coach.
library;

import 'package:flutter/material.dart';

/// Nature du problème.
///
/// La liste est volontairement **courte**. Au-delà de six ou sept choix,
/// personne ne lit et tout le monde prend le premier : une taxonomie fine
/// produit des données moins fiables qu'une taxonomie grossière.
enum ProblemCategory {
  bug('BUG', 'Quelque chose ne marche pas', '🐞',
      'Plantage, écran vide, bouton sans effet'),
  account('ACCOUNT', 'Mon compte', '🔐',
      'Connexion, mot de passe, vérification d\'email'),
  content('CONTENT', 'Une donnée est fausse', '📊',
      'Macros d\'un aliment, vidéo d\'exercice, calcul de score'),
  abuse('ABUSE', 'Un comportement', '⚠️',
      'Propos ou attitude déplacés d\'un coach ou d\'un adhérent'),
  suggestion('SUGGESTION', 'Une idée', '💡',
      'Quelque chose qui manque ou qui pourrait être mieux'),
  other('OTHER', 'Autre chose', '💬', '');

  const ProblemCategory(this.wire, this.label, this.emoji, this.hint);

  final String wire;
  final String label;
  final String emoji;
  final String hint;

  static ProblemCategory parse(String? raw) =>
      values.firstWhere((c) => c.wire == raw, orElse: () => ProblemCategory.other);
}

/// Avancement du traitement, **tel que l'auteur le voit**.
///
/// C'est la raison d'être de ces états : un signalement envoyé dans le vide
/// donne le sentiment que personne ne lit. La valeur de la fonctionnalité tient
/// autant au retour rendu qu'au traitement lui-même.
enum ProblemStatus {
  newReport('NEW', 'Reçu', 'Ton signalement est arrivé. Il sera examiné.'),
  inProgress('IN_PROGRESS', 'En cours', 'Quelqu\'un s\'en occupe.'),
  resolved('RESOLVED', 'Résolu', 'Le problème a été traité.'),
  closed('CLOSED', 'Clos', 'Examiné, sans suite à donner.');

  const ProblemStatus(this.wire, this.label, this.hint);

  final String wire;
  final String label;
  final String hint;

  static ProblemStatus parse(String? raw) =>
      values.firstWhere((s) => s.wire == raw, orElse: () => ProblemStatus.newReport);
}

/// Couleur associée à un état de traitement.
///
/// Définie ici, à côté du libellé, plutôt que dans l'écran : séparées, elles
/// divergent — un état ajouté plus tard obtiendrait son texte mais garderait
/// la couleur par défaut, et l'écart ne se verrait que sur un cas rare.
Color problemStatusColor(ProblemStatus status, {
  required Color pending,
  required Color active,
  required Color done,
  required Color muted,
}) => switch (status) {
  ProblemStatus.newReport => pending,
  ProblemStatus.inProgress => active,
  ProblemStatus.resolved => done,
  ProblemStatus.closed => muted,
};

/// Un signalement, vu par son auteur.
class ProblemReport {
  final String id;
  final ProblemCategory category;
  final String subject;
  final String description;
  final String? attachmentUrl;
  final ProblemStatus status;

  /// Réponse écrite par l'équipe FitForge. `null` tant qu'il n'y en a pas.
  ///
  /// C'est ce qui ferme la boucle : sans elle, le statut changerait sans que
  /// personne ne sache pourquoi.
  final String? adminResponse;

  final DateTime? createdAt;
  final DateTime? handledAt;

  const ProblemReport({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    this.attachmentUrl,
    this.adminResponse,
    this.createdAt,
    this.handledAt,
  });

  factory ProblemReport.fromJson(Map<String, dynamic> json) => ProblemReport(
    id: json['id'] as String,
    category: ProblemCategory.parse(json['category'] as String?),
    subject: json['subject'] as String? ?? '',
    description: json['description'] as String? ?? '',
    attachmentUrl: json['attachmentUrl'] as String?,
    status: ProblemStatus.parse(json['status'] as String?),
    adminResponse: json['adminResponse'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
    handledAt: json['handledAt'] != null
        ? DateTime.tryParse(json['handledAt'] as String)
        : null,
  );
}
