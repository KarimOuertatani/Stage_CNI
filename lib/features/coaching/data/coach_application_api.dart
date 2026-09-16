import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/constants/api_constants.dart';
import 'coach_application_models.dart';

/// Accès réseau à la candidature du coach connecté.
///
/// Aucune méthode ne prend d'identifiant de coach : le serveur travaille
/// toujours sur le dossier du porteur du JWT. Il n'existe donc aucun moyen,
/// depuis l'application, de consulter ou de modifier le dossier d'un autre.
class CoachApplicationApi {
  final Dio _dio;

  CoachApplicationApi(this._dio);

  /// État courant : statut, pièces déposées, et ce qu'il reste à faire.
  Future<CoachApplication> getMyApplication() async {
    final res = await _dio.get(ApiConstants.coachApplication);
    return CoachApplication.fromJson(res.data as Map<String, dynamic>);
  }

  /// Dépose un justificatif.
  ///
  /// Le serveur renvoie la candidature **entière** et non le seul document
  /// ajouté : déposer une pièce peut faire disparaître une ligne de
  /// `missingRequirements` et rendre le bouton d'envoi actif. Renvoyer le
  /// document seul obligerait l'application à recalculer cet état, donc à
  /// dupliquer la règle de complétude du serveur.
  Future<CoachApplication> uploadDocument({
    required String filePath,
    required CoachDocumentType type,
    String? label,
    String? contentType,
  }) async {
    final form = FormData.fromMap({
      'type': type.wire,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'file': await MultipartFile.fromFile(
        filePath,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ),
    });

    final res = await _dio.post(
      ApiConstants.coachApplicationDocuments,
      data: form,
    );
    return CoachApplication.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachApplication> deleteDocument(String documentId) async {
    final res = await _dio.delete(
      '${ApiConstants.coachApplicationDocuments}/$documentId',
    );
    return CoachApplication.fromJson(res.data as Map<String, dynamic>);
  }

  /// Soumet le dossier à l'examen de l'administration.
  ///
  /// Lève si le dossier est incomplet — le serveur reste seul juge, et son
  /// message est directement affichable.
  Future<CoachApplication> submit() async {
    final res = await _dio.post(ApiConstants.coachApplicationSubmit);
    return CoachApplication.fromJson(res.data as Map<String, dynamic>);
  }
}
