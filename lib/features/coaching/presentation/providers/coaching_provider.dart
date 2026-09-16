import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/coaching_api.dart';
import '../../data/coaching_models.dart';

/// API coaching câblée sur Dio (JWT injecté automatiquement).
final coachingApiProvider = Provider<CoachingApi>(
  (ref) => CoachingApi(ref.read(dioClientProvider)),
);

// ── Côté adhérent ─────────────────────────────────────────────────────

/// Annuaire des coachs disponibles.
final coachDirectoryProvider = FutureProvider<List<CoachSummary>>((ref) {
  return ref.read(coachingApiProvider).getDirectory();
});

/// Mes suivis / demandes (adhérent).
final myRelationshipsProvider = FutureProvider<List<CoachingRelationship>>((
  ref,
) {
  return ref.read(coachingApiProvider).getMyRelationships();
});

// ── Côté coach ────────────────────────────────────────────────────────

/// Toutes les relations reçues par le coach (demandes + suivis).
final coachRelationshipsProvider = FutureProvider<List<CoachingRelationship>>((
  ref,
) {
  return ref.read(coachingApiProvider).getCoachRelationships();
});

/// Compteurs du tableau de bord coach.
final coachDashboardProvider = FutureProvider<CoachDashboard>((ref) {
  return ref.read(coachingApiProvider).getDashboard();
});

/// Mon profil coach (édition).
final myCoachProfileProvider = FutureProvider<CoachProfile>((ref) {
  return ref.read(coachingApiProvider).getMyCoachProfile();
});

/// Invalide toutes les listes coaching (après une action : demande, accept…).
void invalidateCoachingW(WidgetRef ref) {
  ref.invalidate(coachDirectoryProvider);
  ref.invalidate(myRelationshipsProvider);
  ref.invalidate(coachRelationshipsProvider);
  ref.invalidate(coachDashboardProvider);
}
