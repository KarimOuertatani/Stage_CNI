/// Recherche et filtrage du catalogue d'exercices.
///
/// ## Pourquoi côté application et non côté serveur
///
/// Le catalogue entier (220 exercices) est déjà chargé en mémoire au démarrage
/// par `workoutProvider`. Filtrer localement rend la recherche **instantanée à
/// chaque frappe** — pas d'aller-retour réseau, pas de « debounce » à régler,
/// pas de résultats qui arrivent dans le désordre quand deux requêtes se
/// croisent. C'est ce qui sépare une recherche agréable d'une recherche qu'on
/// abandonne.
///
/// Le serveur sait faire la même chose (`GET /exercises?q=&level=`) : cet
/// endpoint reste la référence, et deviendra le chemin normal le jour où le
/// catalogue dépassera ce qu'on peut raisonnablement garder en mémoire.
///
/// ## Pourquoi une classe et pas des variables d'écran
///
/// Trois écrans cherchent dans le catalogue (bibliothèque, liste par zone,
/// sélecteur d'exercice d'un programme). Une seule définition de « ce que
/// cherche l'adhérent », un seul endroit où corriger le classement.
library;

import 'workout_model.dart';

/// Critère de tri des résultats.
enum ExerciseSort {
  /// Les plus proches de la recherche d'abord. Sans texte saisi : ordre
  /// alphabétique (il n'y a alors rien à quoi être « pertinent »).
  pertinence('Pertinence'),
  alphabetique('A → Z'),

  /// Du plus accessible au plus technique — l'ordre dans lequel on progresse.
  niveau('Niveau'),
  duree('Durée');

  final String label;
  const ExerciseSort(this.label);
}

/// Table de repli des lettres accentuées vers leur équivalent sans accent.
///
/// Dart n'expose pas la normalisation Unicode (NFD) : sans cette table,
/// « developpe » ne trouverait pas « Développé », et personne ne tape les
/// accents dans un champ de recherche.
const Map<String, String> _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Met un texte sous sa forme comparable : minuscules, sans accents, sans
/// ponctuation parasite. « Développé couché (barre) » → « developpe couche barre ».
String normalizeForSearch(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    final replacement = _diacritics[char];
    if (replacement != null) {
      buffer.write(replacement);
    } else if (RegExp(r'[a-z0-9 ]').hasMatch(char)) {
      buffer.write(char);
    } else {
      // Tirets, apostrophes, parenthèses : remplacés par une espace pour que
      // « pull-up » et « pull up » se trouvent l'un l'autre.
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Ce que l'adhérent cherche : du texte, des filtres, un tri.
class ExerciseQuery {
  /// Texte saisi, tel que tapé (la normalisation se fait au moment de filtrer).
  final String text;

  /// Niveaux retenus. Vide = tous — et non « aucun » : un filtre qu'on vient
  /// de vider doit tout remontrer, pas vider la liste.
  final Set<ExerciseLevel> levels;

  /// Valeurs d'équipement backend retenues (BARRE, HALTERE…). Vide = toutes.
  final Set<String> equipments;

  /// Libellés de type retenus (Force, Cardio, Étirement). Vide = tous.
  final Set<String> types;

  /// Ne garder que les exercices ayant une vidéo de démonstration.
  final bool withVideoOnly;

  /// Ne garder que les favoris.
  final bool favoritesOnly;

  final ExerciseSort sort;

  const ExerciseQuery({
    this.text = '',
    this.levels = const {},
    this.equipments = const {},
    this.types = const {},
    this.withVideoOnly = false,
    this.favoritesOnly = false,
    this.sort = ExerciseSort.pertinence,
  });

  /// Vrai si rien n'est demandé — l'écran affiche alors sa vue par défaut
  /// (grille des zones, liste complète…) plutôt qu'une liste de résultats.
  bool get isEmpty => text.trim().isEmpty && !hasFilters;

  /// Vrai si au moins un filtre est actif (le tri n'en est pas un).
  bool get hasFilters =>
      levels.isNotEmpty ||
      equipments.isNotEmpty ||
      types.isNotEmpty ||
      withVideoOnly ||
      favoritesOnly;

  /// Nombre de filtres actifs — affiché en pastille sur le bouton « Filtres »,
  /// pour qu'un filtre oublié ne passe jamais inaperçu.
  int get activeFilterCount =>
      levels.length +
      equipments.length +
      types.length +
      (withVideoOnly ? 1 : 0) +
      (favoritesOnly ? 1 : 0);

  ExerciseQuery copyWith({
    String? text,
    Set<ExerciseLevel>? levels,
    Set<String>? equipments,
    Set<String>? types,
    bool? withVideoOnly,
    bool? favoritesOnly,
    ExerciseSort? sort,
  }) {
    return ExerciseQuery(
      text: text ?? this.text,
      levels: levels ?? this.levels,
      equipments: equipments ?? this.equipments,
      types: types ?? this.types,
      withVideoOnly: withVideoOnly ?? this.withVideoOnly,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sort: sort ?? this.sort,
    );
  }

  /// Efface les filtres en gardant le texte saisi : « tout effacer » ne doit
  /// pas faire perdre la recherche en cours.
  ExerciseQuery clearedFilters() => ExerciseQuery(text: text, sort: sort);

  /// Bascule une valeur dans un ensemble de filtres (ajout / retrait).
  static Set<T> toggle<T>(Set<T> current, T value) {
    final next = {...current};
    if (!next.remove(value)) next.add(value);
    return next;
  }

  /// Applique la recherche, les filtres et le tri.
  ///
  /// [favoriteIds] ne sert qu'au filtre « favoris » : la liste des favoris vit
  /// dans son propre provider, le modèle d'exercice n'a pas à porter un état
  /// qui dépend de l'utilisateur connecté.
  List<WorkoutModel> apply(
    List<WorkoutModel> exercises, {
    Set<String> favoriteIds = const {},
  }) {
    final needle = normalizeForSearch(text);
    final terms = needle.isEmpty ? const <String>[] : needle.split(' ');

    final matches = <(WorkoutModel, int)>[];
    for (final exercise in exercises) {
      if (levels.isNotEmpty && !levels.contains(exercise.level)) continue;
      if (equipments.isNotEmpty &&
          !equipments.contains(exercise.equipment ?? '')) {
        continue;
      }
      if (types.isNotEmpty && !types.contains(exercise.typeLabel ?? '')) {
        continue;
      }
      if (withVideoOnly && !exercise.hasVideo) continue;
      if (favoritesOnly && !favoriteIds.contains(exercise.id)) continue;

      final score = terms.isEmpty ? 0 : _score(exercise, terms);
      if (score < 0) continue; // un terme n'a été trouvé nulle part
      matches.add((exercise, score));
    }

    matches.sort((a, b) => _compare(a, b, terms.isNotEmpty));
    return [for (final match in matches) match.$1];
  }

  /// Score de pertinence, ou -1 si l'exercice ne correspond pas.
  ///
  /// TOUS les termes doivent correspondre (« developpe couche » ne doit pas
  /// remonter tous les développés). Chaque terme rapporte d'autant plus qu'il
  /// est trouvé tôt et dans un champ important : un mot en début de nom vaut
  /// mieux que le même mot perdu dans les mots-clés.
  static int _score(WorkoutModel exercise, List<String> terms) {
    final name = normalizeForSearch(exercise.name);
    final muscle = normalizeForSearch(exercise.muscleGroup);
    final equipment = normalizeForSearch(exercise.equipmentLabel ?? '');
    final muscles = normalizeForSearch(
      '${exercise.targetMuscles ?? ''} ${exercise.secondaryMuscles ?? ''}',
    );

    var total = 0;
    for (final term in terms) {
      if (name.startsWith(term)) {
        total += 100;
      } else if (RegExp('\\b$term').hasMatch(name)) {
        total += 70; // début d'un mot du nom
      } else if (name.contains(term)) {
        total += 50;
      } else if (muscle.contains(term)) {
        total += 30;
      } else if (equipment.contains(term)) {
        total += 20;
      } else if (muscles.contains(term)) {
        total += 15;
      } else {
        return -1;
      }
    }
    // À score égal, l'exercice avec vidéo est plus utile que celui sans.
    return total + (exercise.hasVideo ? 1 : 0);
  }

  int _compare(
    (WorkoutModel, int) a,
    (WorkoutModel, int) b,
    bool hasText,
  ) {
    switch (sort) {
      case ExerciseSort.pertinence:
        // Sans texte saisi, la « pertinence » n'a pas de sens : on retombe sur
        // l'alphabétique, qui est au moins prévisible.
        if (!hasText) return _byName(a.$1, b.$1);
        final byScore = b.$2.compareTo(a.$2);
        return byScore != 0 ? byScore : _byName(a.$1, b.$1);
      case ExerciseSort.alphabetique:
        return _byName(a.$1, b.$1);
      case ExerciseSort.niveau:
        final byLevel = a.$1.level.index.compareTo(b.$1.level.index);
        return byLevel != 0 ? byLevel : _byName(a.$1, b.$1);
      case ExerciseSort.duree:
        final byDuration = a.$1.durationMinutes.compareTo(b.$1.durationMinutes);
        return byDuration != 0 ? byDuration : _byName(a.$1, b.$1);
    }
  }

  static int _byName(WorkoutModel a, WorkoutModel b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
