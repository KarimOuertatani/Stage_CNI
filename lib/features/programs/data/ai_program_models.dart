/// Le questionnaire de génération, et les listes de choix qui le remplissent.
///
/// Mappé vers le `GenerateProgramRequest` du backend. Le profil de l'adhérent
/// (âge, poids, blessures déclarées, sommeil…) n'est **pas** ici : le serveur
/// le joint tout seul. Ce fichier ne porte que ce qui change la **structure du
/// programme** et que l'adhérent doit pouvoir décider pour ce programme-là,
/// même si son profil dit autre chose.
library;

import 'package:flutter/material.dart';

/// Les réponses de l'adhérent, accumulées au fil de l'assistant.
///
/// Immuable et recopié à chaque réponse ([copyWith]) : une étape ne peut pas
/// modifier en douce une réponse donnée trois écrans plus tôt, et le retour en
/// arrière retrouve exactement l'état précédent.
class AiProgramBrief {
  final String goal; // FitnessGoal
  final String experienceLevel; // ExperienceLevel
  final int daysPerWeek;
  final int sessionMinutes;
  final int? durationWeeks;
  final String location; // WorkoutLocation
  final List<String> equipment; // Equipment[]
  final List<int> preferredDays; // 1 = lundi … 7 = dimanche
  final List<String> focusMuscles; // MuscleGroup[]
  final bool includeCardio;

  // Charges de référence — toutes optionnelles. Un débutant ne les connaît
  // pas, et le programme reste utile sans : il raisonne alors en répétitions.
  final double? benchPressKg;
  final double? squatKg;
  final double? deadliftKg;
  final int? maxPullUps;

  final String? constraints;

  const AiProgramBrief({
    this.goal = 'PRISE_MASSE',
    this.experienceLevel = 'DEBUTANT',
    this.daysPerWeek = 3,
    this.sessionMinutes = 60,
    this.durationWeeks = 8,
    this.location = 'SALLE',
    this.equipment = const [],
    this.preferredDays = const [],
    this.focusMuscles = const [],
    this.includeCardio = false,
    this.benchPressKg,
    this.squatKg,
    this.deadliftKg,
    this.maxPullUps,
    this.constraints,
  });

  AiProgramBrief copyWith({
    String? goal,
    String? experienceLevel,
    int? daysPerWeek,
    int? sessionMinutes,
    int? durationWeeks,
    String? location,
    List<String>? equipment,
    List<int>? preferredDays,
    List<String>? focusMuscles,
    bool? includeCardio,
    double? benchPressKg,
    double? squatKg,
    double? deadliftKg,
    int? maxPullUps,
    String? constraints,
    bool clearLifts = false,
  }) {
    return AiProgramBrief(
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      location: location ?? this.location,
      equipment: equipment ?? this.equipment,
      preferredDays: preferredDays ?? this.preferredDays,
      focusMuscles: focusMuscles ?? this.focusMuscles,
      includeCardio: includeCardio ?? this.includeCardio,
      benchPressKg: clearLifts ? null : (benchPressKg ?? this.benchPressKg),
      squatKg: clearLifts ? null : (squatKg ?? this.squatKg),
      deadliftKg: clearLifts ? null : (deadliftKg ?? this.deadliftKg),
      maxPullUps: clearLifts ? null : (maxPullUps ?? this.maxPullUps),
      constraints: constraints ?? this.constraints,
    );
  }

  /// Corps de la requête. Les champs vides sont **omis** plutôt qu'envoyés à
  /// null : côté serveur, « non communiqué » et « nul » ne se traitent pas
  /// pareil — sans charge de référence, l'IA a pour consigne de ne proposer
  /// aucun poids chiffré.
  Map<String, dynamic> toJson() {
    return {
      'goal': goal,
      'experienceLevel': experienceLevel,
      'daysPerWeek': daysPerWeek,
      'sessionMinutes': sessionMinutes,
      'durationWeeks': ?durationWeeks,
      'location': location,
      'equipment': equipment,
      'preferredDays': preferredDays,
      'focusMuscles': focusMuscles,
      'includeCardio': includeCardio,
      'benchPressKg': ?benchPressKg,
      'squatKg': ?squatKg,
      'deadliftKg': ?deadliftKg,
      'maxPullUps': ?maxPullUps,
      if (constraints != null && constraints!.trim().isNotEmpty)
        'constraints': constraints!.trim(),
    };
  }

  /// true si au moins une charge de référence a été renseignée.
  bool get hasLifts =>
      benchPressKg != null ||
      squatKg != null ||
      deadliftKg != null ||
      maxPullUps != null;
}

// ── Listes de choix ───────────────────────────────────────────────────
//
// Chaque option porte son icône : dans un assistant, on choisit d'abord avec
// l'œil. Une liste de sept libellés identiques oblige à tout lire ; sept
// pictogrammes se balaient d'un regard.

typedef AiOption = ({String value, String label, String hint, IconData icon});

const List<AiOption> kAiGoalOptions = [
  (
    value: 'PRISE_MASSE',
    label: 'Prise de masse',
    hint: 'Gagner du muscle et du volume',
    icon: Icons.fitness_center_rounded,
  ),
  (
    value: 'PERTE_POIDS',
    label: 'Perte de poids',
    hint: 'Sécher, perdre du gras',
    icon: Icons.local_fire_department_rounded,
  ),
  (
    value: 'FORCE',
    label: 'Force',
    hint: 'Soulever plus lourd',
    icon: Icons.bolt_rounded,
  ),
  (
    value: 'ENDURANCE',
    label: 'Endurance',
    hint: 'Tenir plus longtemps',
    icon: Icons.directions_run_rounded,
  ),
  (
    value: 'MAINTIEN',
    label: 'Maintien',
    hint: 'Garder la forme, rester régulier',
    icon: Icons.favorite_rounded,
  ),
];

const List<AiOption> kAiLevelOptions = [
  (
    value: 'DEBUTANT',
    label: 'Débutant',
    hint: "Moins d'un an de pratique régulière",
    icon: Icons.eco_rounded,
  ),
  (
    value: 'INTERMEDIAIRE',
    label: 'Intermédiaire',
    hint: '1 à 3 ans, technique acquise',
    icon: Icons.trending_up_rounded,
  ),
  (
    value: 'AVANCE',
    label: 'Avancé',
    hint: 'Plus de 3 ans, progression fine',
    icon: Icons.military_tech_rounded,
  ),
];

const List<AiOption> kAiLocationOptions = [
  (
    value: 'SALLE',
    label: 'En salle',
    hint: 'Machines, barres, poulies',
    icon: Icons.storefront_rounded,
  ),
  (
    value: 'MAISON',
    label: 'À la maison',
    hint: 'Ce que j’ai chez moi',
    icon: Icons.home_rounded,
  ),
  (
    value: 'EXTERIEUR',
    label: 'En extérieur',
    hint: 'Parc, street workout',
    icon: Icons.park_rounded,
  ),
];

const List<AiOption> kAiEquipmentOptions = [
  (
    value: 'BARRE',
    label: 'Barre',
    hint: '',
    icon: Icons.horizontal_rule_rounded,
  ),
  (
    value: 'HALTERE',
    label: 'Haltères',
    hint: '',
    icon: Icons.fitness_center_rounded,
  ),
  (
    value: 'MACHINE',
    label: 'Machines',
    hint: '',
    icon: Icons.precision_manufacturing_rounded,
  ),
  (value: 'POULIE', label: 'Poulies', hint: '', icon: Icons.cable_rounded),
  (
    value: 'KETTLEBELL',
    label: 'Kettlebell',
    hint: '',
    icon: Icons.sports_gymnastics_rounded,
  ),
  (
    value: 'ELASTIQUE',
    label: 'Élastiques',
    hint: '',
    icon: Icons.waves_rounded,
  ),
  (
    value: 'POIDS_CORPS',
    label: 'Poids du corps',
    hint: '',
    icon: Icons.accessibility_new_rounded,
  ),
];

/// Groupes musculaires proposés en « zones à prioriser ».
///
/// `CARDIO` n'y figure pas : ce n'est pas une zone du corps, et le cardio se
/// décide par sa propre question.
const List<({String value, String label})> kAiFocusOptions = [
  (value: 'PECTORAUX', label: 'Pectoraux'),
  (value: 'DOS', label: 'Dos'),
  (value: 'JAMBES', label: 'Jambes'),
  (value: 'EPAULES', label: 'Épaules'),
  (value: 'BICEPS', label: 'Biceps'),
  (value: 'TRICEPS', label: 'Triceps'),
  (value: 'ABDOS', label: 'Abdominaux'),
  (value: 'FESSIERS', label: 'Fessiers'),
  (value: 'MOLLETS', label: 'Mollets'),
];

/// Jours de la semaine, en initiales — un calendrier tient alors sur une ligne
/// même sur un petit écran.
const List<({int value, String short, String label})> kAiWeekDays = [
  (value: 1, short: 'L', label: 'Lundi'),
  (value: 2, short: 'M', label: 'Mardi'),
  (value: 3, short: 'M', label: 'Mercredi'),
  (value: 4, short: 'J', label: 'Jeudi'),
  (value: 5, short: 'V', label: 'Vendredi'),
  (value: 6, short: 'S', label: 'Samedi'),
  (value: 7, short: 'D', label: 'Dimanche'),
];

/// Libellé FR d'une valeur d'équipement (utilisé hors de l'assistant).
String equipmentLabelFr(String? value) {
  for (final option in kAiEquipmentOptions) {
    if (option.value == value) return option.label;
  }
  return 'Autre';
}
