/// Le contexte de programme transmis à l'écran de saisie d'une séance.
///
/// ## Ce qui manquait
///
/// Un programme prescrit « 4 × 8 à 60 kg, 120 s de repos ». L'écran de saisie
/// ignorait tout de cette prescription : il ouvrait invariablement 4 séries de
/// 10 répétitions à 20 kg, avec 90 s de repos. L'adhérent devait donc
/// **ressaisir à la main** ce que son coach — ou l'IA — venait tout juste de
/// définir, et le programme se réduisait à une liste de noms d'exercices.
///
/// ## Pourquoi passer toute la séance et pas seulement l'exercice
///
/// Parce qu'une séance s'enchaîne. En connaissant la liste et la position
/// courante, l'écran peut proposer « Exercice suivant » et éviter le
/// aller-retour vers le programme entre chaque mouvement — c'est là que se perd
/// le fil d'une séance.
///
/// Transmis via le `extra` de GoRouter : ces valeurs n'ont de sens que pour
/// cette ouverture précise, elles n'ont pas à vivre dans l'URL ni dans un
/// provider global.
class WorkoutLogArgs {
  /// Titre de la séance du programme (« Push A »), affiché en sous-titre.
  final String? sessionTitle;

  /// Les exercices de la séance, dans l'ordre du programme.
  final List<ProgramExerciseTarget> queue;

  /// Position de l'exercice affiché dans [queue].
  final int index;

  const WorkoutLogArgs({
    this.sessionTitle,
    this.queue = const [],
    this.index = 0,
  });

  /// La prescription de l'exercice affiché, ou null si l'écran a été ouvert
  /// hors programme (depuis la bibliothèque).
  ProgramExerciseTarget? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  bool get hasNext => index + 1 < queue.length;

  ProgramExerciseTarget? get next => hasNext ? queue[index + 1] : null;

  /// Le contexte décalé d'un cran, pour ouvrir l'exercice suivant.
  WorkoutLogArgs forNext() =>
      WorkoutLogArgs(sessionTitle: sessionTitle, queue: queue, index: index + 1);
}

/// Ce que le programme prescrit pour un exercice d'une séance.
class ProgramExerciseTarget {
  final String exerciseId;
  final String exerciseName;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final int? restSeconds;

  /// Consigne du coach pour cet exercice (« garde 2 répétitions en réserve »).
  final String? notes;

  const ProgramExerciseTarget({
    required this.exerciseId,
    required this.exerciseName,
    this.sets,
    this.reps,
    this.weightKg,
    this.restSeconds,
    this.notes,
  });

  /// Vrai si la prescription apporte quelque chose à pré-remplir. Un exercice
  /// ajouté sans objectif ne doit pas afficher un bandeau vide.
  bool get hasTargets =>
      sets != null || reps != null || weightKg != null || restSeconds != null;

  /// « 4 × 8 · 60 kg · 120 s de repos » — les parties absentes sont omises.
  String get summary {
    final parts = <String>[];
    if (sets != null && reps != null) {
      parts.add('$sets × $reps');
    } else if (sets != null) {
      parts.add('$sets séries');
    } else if (reps != null) {
      parts.add('$reps reps');
    }
    if (weightKg != null && weightKg! > 0) {
      parts.add(
        '${weightKg! % 1 == 0 ? weightKg!.toStringAsFixed(0) : weightKg!.toStringAsFixed(1)} kg',
      );
    }
    if (restSeconds != null) parts.add('${restSeconds}s de repos');
    return parts.join(' · ');
  }
}
