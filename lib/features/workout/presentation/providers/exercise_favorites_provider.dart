import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/workout_model.dart';
import 'workout_provider.dart';

/// Les exercices mis en favori par l'adhérent.
///
/// ## Pourquoi les favoris ne sont pas un champ de [WorkoutModel]
///
/// Le catalogue est **partagé** : le même « Développé couché » est servi à tout
/// le monde. Le favori, lui, appartient à l'utilisateur connecté. Le porter sur
/// le modèle d'exercice obligerait à recharger tout le catalogue à chaque
/// changement de compte, et à réécrire 220 objets pour une seule étoile
/// cliquée.
class FavoritesState {
  /// Identifiants favoris — la question posée par chaque carte est « est-ce
  /// que celui-ci en fait partie ? », un ensemble y répond en temps constant.
  final Set<String> ids;

  /// Les exercices favoris dans l'ordre serveur (dernier ajouté en tête), pour
  /// la section « Mes favoris ». Peut rester vide tant que le chargement n'a
  /// pas eu lieu — d'où [loaded].
  final List<WorkoutModel> exercises;

  final bool loaded;

  const FavoritesState({
    this.ids = const {},
    this.exercises = const [],
    this.loaded = false,
  });
}

class ExerciseFavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    Future.microtask(load);
    return const FavoritesState();
  }

  /// Charge la liste depuis le serveur. Un échec laisse l'état vide : une
  /// section « Favoris » absente est préférable à un message d'erreur sur un
  /// écran dont ce n'est pas le sujet.
  Future<void> load() async {
    try {
      final favorites = await ref.read(workoutApiProvider).getFavorites();
      state = FavoritesState(
        ids: {for (final e in favorites) e.id},
        exercises: favorites,
        loaded: true,
      );
    } catch (_) {
      state = const FavoritesState(loaded: true);
    }
  }

  bool isFavorite(String exerciseId) => state.ids.contains(exerciseId);

  /// Ajoute ou retire un favori.
  ///
  /// L'état bascule AVANT l'appel réseau : l'étoile doit répondre au doigt,
  /// pas au serveur. Si l'appel échoue, on revient à l'état précédent — l'app
  /// ne prétend jamais avoir enregistré ce qui ne l'a pas été.
  ///
  /// Renvoie `true` si l'exercice est désormais favori.
  Future<bool> toggle(WorkoutModel exercise) async {
    final wasFavorite = state.ids.contains(exercise.id);
    final previous = state;

    state = FavoritesState(
      ids: wasFavorite
          ? ({...state.ids}..remove(exercise.id))
          : ({...state.ids}..add(exercise.id)),
      exercises: wasFavorite
          ? [
              for (final e in state.exercises)
                if (e.id != exercise.id) e,
            ]
          : [exercise, ...state.exercises],
      loaded: true,
    );

    try {
      final api = ref.read(workoutApiProvider);
      if (wasFavorite) {
        await api.removeFavorite(exercise.id);
      } else {
        await api.addFavorite(exercise.id);
      }
      return !wasFavorite;
    } catch (_) {
      state = previous;
      return wasFavorite;
    }
  }
}

final exerciseFavoritesProvider =
    NotifierProvider<ExerciseFavoritesNotifier, FavoritesState>(
      ExerciseFavoritesNotifier.new,
    );

/// Raccourci pour les widgets qui n'ont besoin que des identifiants : ils ne
/// se reconstruisent alors pas quand seule la liste ordonnée change.
final favoriteIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(exerciseFavoritesProvider).ids,
);
