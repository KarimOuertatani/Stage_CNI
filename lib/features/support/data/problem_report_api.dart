import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import 'problem_report_models.dart';

/// Accès réseau aux signalements de l'utilisateur connecté.
///
/// Aucune méthode ne prend d'identifiant : on ne signale qu'en son nom, et on
/// ne consulte que ses propres signalements.
class ProblemReportApi {
  final Dio _dio;

  ProblemReportApi(this._dio);

  Future<List<ProblemReport>> getMyReports() async {
    final res = await _dio.get(ApiConstants.problemReports);
    return (res.data as List<dynamic>)
        .map((e) => ProblemReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Envoie un signalement.
  ///
  /// La plateforme et la version de l'application sont ajoutées **ici**, sans
  /// que l'utilisateur ait à les saisir. Sans elles, chaque signalement de bug
  /// commence par un aller-retour pour demander la version — aller-retour
  /// auquel la plupart des gens ne répondent jamais.
  Future<ProblemReport> create({
    required ProblemCategory category,
    required String subject,
    required String description,
    String? attachmentUrl,
  }) async {
    final res = await _dio.post(
      ApiConstants.problemReports,
      data: {
        'category': category.wire,
        'subject': subject.trim(),
        'description': description.trim(),
        'attachmentUrl': ?attachmentUrl,
        'platform': _platform(),
        'appVersion': _appVersion,
      },
    );
    return ProblemReport.fromJson(res.data as Map<String, dynamic>);
  }

  /// Version affichée dans la console d'administration.
  ///
  /// Codée en dur et alignée sur `pubspec.yaml`. La lire à l'exécution
  /// demanderait `package_info_plus`, une dépendance de plus pour une chaîne
  /// qui ne change qu'à chaque publication — et que l'on met à jour au même
  /// moment que le `pubspec`.
  static const String _appVersion = '1.0.0+1';

  /// Plateforme d'exécution, en clair.
  ///
  /// `Platform` n'existe pas sur le web : le test `kIsWeb` doit passer en
  /// premier, sans quoi l'accès lèverait sur cette cible.
  String _platform() {
    if (kIsWeb) return 'web';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'inconnue';
    }
  }
}
