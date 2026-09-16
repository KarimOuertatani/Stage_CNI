import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mémoire des exercices **récemment consultés**.
///
/// ## Pourquoi c'est utile
///
/// Une séance se joue sur cinq ou six exercices, et on y revient d'une séance à
/// l'autre. Sans historique, chacun se retrouve en retraversant « zone du
/// corps → liste → recherche ». Les récents mettent ces cinq exercices à un
/// seul appui, en haut de la bibliothèque.
///
/// ## Pourquoi localement et pas sur le serveur
///
/// Contrairement aux favoris, qui sont un **choix** que l'adhérent veut
/// retrouver sur tous ses appareils, un récent n'est qu'une **trace de
/// navigation**. La synchroniser coûterait une table, un endpoint et un appel
/// réseau à chaque ouverture d'exercice, pour un confort qui se reconstruit
/// tout seul en deux consultations.
///
/// ## Pourquoi `flutter_secure_storage`
///
/// Ce n'est pas un secret et le chiffrement n'apporte rien ici : c'est
/// simplement le seul stockage persistant déjà présent dans le projet (il porte
/// le JWT). Ajouter une dépendance pour mémoriser douze identifiants serait
/// disproportionné — même raisonnement que `SleepPromptStore`.
class RecentExercisesStore {
  RecentExercisesStore._();

  static final RecentExercisesStore instance = RecentExercisesStore._();

  static const _key = 'fitforge_recent_exercises';

  /// Au-delà, ce ne sont plus des « récents » mais un second historique — et la
  /// section prendrait tout l'écran au lieu de tenir sur une ligne défilante.
  static const int maxEntries = 12;

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// Copie mémoire : la bibliothèque se reconstruit à chaque frappe dans le
  /// champ de recherche, on ne relit pas le disque à chaque fois.
  List<String>? _cache;

  /// Les identifiants consultés, du plus récent au plus ancien.
  Future<List<String>> read() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw = await _secure.read(key: _key);
      _cache = raw == null || raw.isEmpty ? const [] : raw.split(',');
    } catch (_) {
      // Stockage indisponible : pas de récents, c'est tout. Une section vide
      // est sans conséquence, une exception au démarrage de l'écran non.
      _cache = const [];
    }
    return _cache!;
  }

  /// Note une consultation. L'exercice remonte en tête s'il y était déjà —
  /// l'ordre reflète la dernière visite, pas la première.
  Future<void> record(String exerciseId) async {
    final current = await read();
    final next = [
      exerciseId,
      for (final id in current)
        if (id != exerciseId) id,
    ];
    if (next.length > maxEntries) next.removeRange(maxEntries, next.length);
    _cache = next;
    try {
      await _secure.write(key: _key, value: next.join(','));
    } catch (_) {
      // La copie mémoire tient pour la session courante, ce qui couvre déjà
      // l'usage principal : retrouver un exercice pendant sa séance.
    }
  }

  /// Efface l'historique — à la déconnexion : le compte suivant sur le même
  /// appareil ne doit pas hériter des exercices du précédent.
  Future<void> clear() async {
    _cache = const [];
    try {
      await _secure.delete(key: _key);
    } catch (_) {
      // Sans conséquence : la copie mémoire est déjà vidée.
    }
  }
}
