/// Modèles du domaine « Programmes & Séances ».
///
/// Mappés depuis le backend Spring Boot :
///  - `ProgramResponse`         → [ProgramModel]
///  - `SessionResponse`         → [SessionModel]
///  - `SessionExerciseResponse` → [SessionExerciseModel]
///  - `ExerciseResponse`        → [ExerciseRef]
///
/// Un **programme** contient des **séances** ; une séance est un **ensemble
/// d'exercices** placés (avec objectifs séries/reps/repos). Les programmes
/// « prêts » (modèles fournis par l'app, ex : Push/Pull/Legs) ont
/// [isTemplate] = true ; les programmes personnels de l'adhérent non.
library;

class ProgramModel {
  final String id;
  final String title;
  final String? description;
  final String? goal; // enum backend FitnessGoal
  final String? experienceLevel; // enum backend ExperienceLevel
  final int? durationWeeks;
  final bool isTemplate;

  /// Auteur si le programme a été créé par un coach (sinon null).
  final String? createdById;
  final String? createdByName;

  /// Programme composé par l'IA FitForge à partir du questionnaire de
  /// l'adhérent et de son profil.
  final bool generatedByAi;

  /// Le mot de l'IA : pourquoi ce découpage, ce volume, ces exercices.
  /// Null pour un programme qui n'a pas été généré.
  final String? aiRationale;

  final List<SessionModel> sessions;

  const ProgramModel({
    required this.id,
    required this.title,
    this.description,
    this.goal,
    this.experienceLevel,
    this.durationWeeks,
    this.isTemplate = false,
    this.createdById,
    this.createdByName,
    this.generatedByAi = false,
    this.aiRationale,
    this.sessions = const [],
  });

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    final rawSessions = (json['sessions'] as List<dynamic>?) ?? const [];
    return ProgramModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Programme',
      description: json['description'] as String?,
      goal: json['goal'] as String?,
      experienceLevel: json['experienceLevel'] as String?,
      durationWeeks: json['durationWeeks'] as int?,
      isTemplate: json['isTemplate'] as bool? ?? false,
      createdById: json['createdById'] as String?,
      createdByName: json['createdByName'] as String?,
      generatedByAi: json['generatedByAi'] as bool? ?? false,
      aiRationale: json['aiRationale'] as String?,
      sessions: rawSessions
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Nombre total d'exercices placés dans tout le programme.
  int get totalExercises =>
      sessions.fold(0, (sum, s) => sum + s.exercises.length);

  int get sessionCount => sessions.length;

  /// Libellé FR de l'objectif (enum backend → français).
  String get goalLabel => goalLabelFr(goal);

  /// Libellé FR du niveau conseillé.
  String get levelLabel => levelLabelFr(experienceLevel);

  /// true si le programme a été composé par un coach (pas par l'adhérent).
  bool get byCoach => createdById != null;

  /// Qui a composé ce programme, en une ligne — ou null si c'est l'adhérent
  /// lui-même. Les deux origines (coach humain, IA) s'affichent au même
  /// endroit et de la même façon : c'est la même information.
  String? get authorLabel {
    if (generatedByAi) return "Créé avec l'IA de FitForge";
    if (byCoach) return 'Créé par ${createdByName ?? 'votre coach'}';
    return null;
  }
}

class SessionModel {
  final String id;
  final String title;
  final int? dayOfWeek; // 1..7 (1 = lundi)
  final int? orderIndex;
  final List<SessionExerciseModel> exercises;

  const SessionModel({
    required this.id,
    required this.title,
    this.dayOfWeek,
    this.orderIndex,
    this.exercises = const [],
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final rawExos = (json['exercises'] as List<dynamic>?) ?? const [];
    return SessionModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Séance',
      dayOfWeek: json['dayOfWeek'] as int?,
      orderIndex: json['orderIndex'] as int?,
      exercises: rawExos
          .map((e) => SessionExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Libellé FR du jour prévu (ou null si non défini).
  String? get dayLabel => dayOfWeekLabelFr(dayOfWeek);
}

class SessionExerciseModel {
  final String id;
  final ExerciseRef exercise;
  final int? targetSets;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;
  final int? orderIndex;

  /// Consigne d'exécution pour cet exercice dans cette séance (tempo,
  /// répétitions en réserve, adaptation). Renseignée par les programmes
  /// générés ; nulle sur ceux composés à la main.
  final String? notes;

  const SessionExerciseModel({
    required this.id,
    required this.exercise,
    this.targetSets,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
    this.orderIndex,
    this.notes,
  });

  factory SessionExerciseModel.fromJson(Map<String, dynamic> json) {
    return SessionExerciseModel(
      id: json['id'] as String,
      exercise: ExerciseRef.fromJson(json['exercise'] as Map<String, dynamic>),
      targetSets: json['targetSets'] as int?,
      targetReps: json['targetReps'] as int?,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      restSeconds: json['restSeconds'] as int?,
      orderIndex: json['orderIndex'] as int?,
      notes: json['notes'] as String?,
    );
  }

  /// « 4 × 8 » (séries × répétitions), ou juste l'un des deux si fourni.
  String get setsRepsLabel {
    if (targetSets != null && targetReps != null) {
      return '$targetSets × $targetReps';
    }
    if (targetSets != null) return '$targetSets séries';
    if (targetReps != null) return '$targetReps reps';
    return '—';
  }
}

/// Référence légère vers un exercice du référentiel (dans une séance).
class ExerciseRef {
  final String id;
  final String name;
  final String? primaryMuscle; // enum backend MuscleGroup
  final String? equipment; // enum backend Equipment

  const ExerciseRef({
    required this.id,
    required this.name,
    this.primaryMuscle,
    this.equipment,
  });

  factory ExerciseRef.fromJson(Map<String, dynamic> json) {
    return ExerciseRef(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      primaryMuscle: json['primaryMuscle'] as String?,
      equipment: json['equipment'] as String?,
    );
  }

  String get muscleLabel => muscleLabelFr(primaryMuscle);
}

// ── Helpers d'affichage (enums backend → français) ────────────────────

String goalLabelFr(String? goal) {
  switch (goal) {
    case 'PERTE_POIDS':
      return 'Perte de poids';
    case 'PRISE_MASSE':
      return 'Prise de masse';
    case 'MAINTIEN':
      return 'Maintien';
    case 'FORCE':
      return 'Force';
    case 'ENDURANCE':
      return 'Endurance';
    default:
      return 'Général';
  }
}

String levelLabelFr(String? level) {
  switch (level) {
    case 'DEBUTANT':
      return 'Débutant';
    case 'INTERMEDIAIRE':
      return 'Intermédiaire';
    case 'AVANCE':
      return 'Avancé';
    default:
      return 'Tous niveaux';
  }
}

String? dayOfWeekLabelFr(int? day) {
  switch (day) {
    case 1:
      return 'Lundi';
    case 2:
      return 'Mardi';
    case 3:
      return 'Mercredi';
    case 4:
      return 'Jeudi';
    case 5:
      return 'Vendredi';
    case 6:
      return 'Samedi';
    case 7:
      return 'Dimanche';
    default:
      return null;
  }
}

String muscleLabelFr(String? muscle) {
  switch (muscle) {
    case 'PECTORAUX':
      return 'Pectoraux';
    case 'DOS':
      return 'Dos';
    case 'JAMBES':
      return 'Jambes';
    case 'EPAULES':
      return 'Épaules';
    case 'BICEPS':
      return 'Biceps';
    case 'TRICEPS':
      return 'Triceps';
    case 'ABDOS':
      return 'Abdominaux';
    case 'FESSIERS':
      return 'Fessiers';
    case 'MOLLETS':
      return 'Mollets';
    case 'CARDIO':
      return 'Cardio';
    default:
      return 'Autre';
  }
}

/// Valeurs sélectionnables pour l'objectif d'un programme (création/édition).
const List<({String value, String label})> kGoalOptions = [
  (value: 'PRISE_MASSE', label: 'Prise de masse'),
  (value: 'PERTE_POIDS', label: 'Perte de poids'),
  (value: 'MAINTIEN', label: 'Maintien'),
  (value: 'FORCE', label: 'Force'),
  (value: 'ENDURANCE', label: 'Endurance'),
];

/// Valeurs sélectionnables pour le niveau conseillé.
const List<({String value, String label})> kLevelOptions = [
  (value: 'DEBUTANT', label: 'Débutant'),
  (value: 'INTERMEDIAIRE', label: 'Intermédiaire'),
  (value: 'AVANCE', label: 'Avancé'),
];
