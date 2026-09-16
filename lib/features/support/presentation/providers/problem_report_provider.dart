import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/problem_report_api.dart';
import '../../data/problem_report_models.dart';

final problemReportApiProvider = Provider<ProblemReportApi>(
  (ref) => ProblemReportApi(ref.read(dioClientProvider)),
);

/// Mes signalements, du plus récent au plus ancien.
final myReportsProvider = FutureProvider<List<ProblemReport>>((ref) {
  return ref.read(problemReportApiProvider).getMyReports();
});

/// Envoi d'un signalement.
///
/// Séparé de la lecture : l'écran de rédaction a besoin de connaître l'état
/// de l'envoi (en cours, en échec), pas de recharger la liste. Les fusionner
/// ferait clignoter « Mes signalements » à chaque frappe de bouton.
class ProblemReportController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required ProblemCategory category,
    required String subject,
    required String description,
    String? attachmentUrl,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(problemReportApiProvider)
          .create(
            category: category,
            subject: subject,
            description: description,
            attachmentUrl: attachmentUrl,
          );
      state = const AsyncData(null);
      // La liste doit montrer le nouveau signalement dès qu'on y revient.
      ref.invalidate(myReportsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Message du backend, déjà rédigé pour être lu (« Décris le problème en
  /// 20 caractères au moins… »). Le remplacer par un texte générique perdrait
  /// exactement l'information dont l'utilisateur a besoin pour corriger.
  String errorMessage() {
    final error = state.error;
    if (error == null) return 'Une erreur est survenue';

    final dynamic response = (error as dynamic).response;
    final data = response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return "L'envoi a échoué. Vérifie ta connexion.";
  }
}

final problemReportControllerProvider =
    NotifierProvider<ProblemReportController, AsyncValue<void>>(
      ProblemReportController.new,
    );
