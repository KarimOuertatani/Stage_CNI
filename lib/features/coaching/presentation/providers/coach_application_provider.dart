import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/coach_application_api.dart';
import '../../data/coach_application_models.dart';

/// API de la candidature, câblée sur Dio (JWT injecté automatiquement).
final coachApplicationApiProvider = Provider<CoachApplicationApi>(
  (ref) => CoachApplicationApi(ref.read(dioClientProvider)),
);

/// Candidature du coach connecté.
///
/// ⚠️ **Ce provider commande l'accès à tout l'espace coach.** Le routeur le
/// lit pour décider si un coach entre dans son tableau de bord ou reste sur
/// l'écran de son dossier ; le résultat conditionne aussi l'apparition dans
/// l'annuaire côté serveur. Toute action qui change le statut (soumission)
/// doit donc l'invalider — sinon l'application continuerait d'afficher
/// l'ancien état pendant que le serveur en applique un autre.
final coachApplicationProvider = FutureProvider<CoachApplication>((ref) {
  return ref.read(coachApplicationApiProvider).getMyApplication();
});

/// Notifier des actions sur le dossier (dépôt, retrait, soumission).
///
/// Séparé du `FutureProvider` de lecture : celui-ci porte l'état *chargé*,
/// celui-là les *opérations* et leur état d'envoi. Les fusionner ferait
/// repasser tout l'écran en chargement à chaque dépôt de fichier, alors que
/// seule la vignette concernée change.
class CoachApplicationController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  CoachApplicationApi get _api => ref.read(coachApplicationApiProvider);

  /// Recharge la candidature depuis le serveur.
  ///
  /// Les méthodes ci-dessous reçoivent déjà la candidature à jour en réponse,
  /// mais on invalide malgré tout : d'autres écrans (le shell coach, le
  /// routeur) lisent le même provider et doivent voir le même état.
  void _refresh() => ref.invalidate(coachApplicationProvider);

  Future<bool> uploadDocument({
    required String filePath,
    required CoachDocumentType type,
    String? label,
    String? contentType,
  }) async {
    state = const AsyncLoading();
    try {
      await _api.uploadDocument(
        filePath: filePath,
        type: type,
        label: label,
        contentType: contentType,
      );
      state = const AsyncData(null);
      _refresh();
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    state = const AsyncLoading();
    try {
      await _api.deleteDocument(documentId);
      state = const AsyncData(null);
      _refresh();
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> submit() async {
    state = const AsyncLoading();
    try {
      await _api.submit();
      state = const AsyncData(null);
      _refresh();
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final coachApplicationControllerProvider =
    NotifierProvider<CoachApplicationController, AsyncValue<void>>(
      CoachApplicationController.new,
    );
