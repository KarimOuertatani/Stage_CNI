/// Modèles du domaine « Sommeil ».
///
/// Mappés depuis le backend Spring Boot :
///  - `SleepEntryResponse`  → [SleepEntry]
///  - `SleepDayResponse`    → [SleepDay]
///  - `SleepWeekResponse`   → [SleepWeek]
///  - `SleepStatusResponse` → [SleepStatus]
///
/// **Aucun calcul n'est refait ici.** La durée, la tranche, la moyenne, le
/// score et les conseils arrivent tout faits du serveur. C'est volontaire :
/// ces valeurs sont aussi lues par d'autres chemins (le profil, le coach IA
/// qui reçoit la moyenne de sommeil). Les recalculer côté Flutter garantirait
/// qu'un jour les deux ne diront plus la même chose, et personne ne saurait
/// laquelle croire.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tranche de durée d'une nuit — miroir de l'enum `SleepBand` du backend.
///
/// C'est elle qui pilote **la couleur de la barre** dans l'histogramme et le
/// ton du conseil. Elle vient du serveur plutôt que d'être déduite ici, ce qui
/// rend impossible qu'une barre verte accompagne un texte parlant de nuit trop
/// courte.
enum SleepBand {
  critique,
  insuffisant,
  court,
  optimal,
  long,
  excessif;

  static SleepBand? fromJson(String? raw) {
    return switch (raw) {
      'CRITIQUE' => SleepBand.critique,
      'INSUFFISANT' => SleepBand.insuffisant,
      'COURT' => SleepBand.court,
      'OPTIMAL' => SleepBand.optimal,
      'LONG' => SleepBand.long,
      'EXCESSIF' => SleepBand.excessif,
      _ => null,
    };
  }

  /// Couleur de la tranche.
  ///
  /// Une échelle qui converge vers le vert au centre et s'éloigne vers le rouge
  /// des deux côtés : dormir douze heures n'est pas « mieux » que d'en dormir
  /// cinq, et un dégradé qui monterait du rouge au vert le laisserait croire.
  Color get color => switch (this) {
    SleepBand.critique => AppColors.error,
    SleepBand.insuffisant => const Color(0xFFFF8A65),
    SleepBand.court => AppColors.warning,
    SleepBand.optimal => AppColors.success,
    SleepBand.long => const Color(0xFF4FC3F7),
    SleepBand.excessif => AppColors.info,
  };

  String get label => switch (this) {
    SleepBand.critique => 'Très courte',
    SleepBand.insuffisant => 'Insuffisante',
    SleepBand.court => 'Un peu courte',
    SleepBand.optimal => 'Idéale',
    SleepBand.long => 'Longue',
    SleepBand.excessif => 'Très longue',
  };
}

/// Une nuit enregistrée, avec sa tranche et son conseil.
class SleepEntry {
  final String id;
  final DateTime sleepDate;
  final TimeOfDay bedTime;
  final TimeOfDay wakeTime;
  final int durationMinutes;
  final SleepBand? band;
  final String? headline;
  final String? advice;

  const SleepEntry({
    required this.id,
    required this.sleepDate,
    required this.bedTime,
    required this.wakeTime,
    required this.durationMinutes,
    this.band,
    this.headline,
    this.advice,
  });

  factory SleepEntry.fromJson(Map<String, dynamic> json) {
    return SleepEntry(
      id: json['id'] as String,
      sleepDate: DateTime.parse(json['sleepDate'] as String),
      bedTime: parseTimeOfDay(json['bedTime'] as String?) ?? const TimeOfDay(hour: 23, minute: 0),
      wakeTime: parseTimeOfDay(json['wakeTime'] as String?) ?? const TimeOfDay(hour: 7, minute: 0),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      band: SleepBand.fromJson(json['band'] as String?),
      headline: json['headline'] as String?,
      advice: json['advice'] as String?,
    );
  }

  /// « 7 h 30 ».
  String get durationLabel => formatDuration(durationMinutes);
}

/// Un jour de l'histogramme — **rempli ou vide**.
///
/// Les jours sans saisie arrivent quand même du serveur, avec une durée nulle.
/// C'est ce qui permet d'afficher des colonnes creuses aux bons endroits : sans
/// elles, quatre barres tassées se liraient comme quatre jours consécutifs et
/// l'adhérent croirait voir une semaine complète.
class SleepDay {
  final String? id;
  final DateTime date;
  final int dayOfWeek; // 1 = lundi … 7 = dimanche
  final int? durationMinutes;
  final SleepBand? band;
  final TimeOfDay? bedTime;
  final TimeOfDay? wakeTime;

  const SleepDay({
    required this.date,
    required this.dayOfWeek,
    this.id,
    this.durationMinutes,
    this.band,
    this.bedTime,
    this.wakeTime,
  });

  factory SleepDay.fromJson(Map<String, dynamic> json) {
    return SleepDay(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      band: SleepBand.fromJson(json['band'] as String?),
      bedTime: parseTimeOfDay(json['bedTime'] as String?),
      wakeTime: parseTimeOfDay(json['wakeTime'] as String?),
    );
  }

  bool get hasData => durationMinutes != null;

  /// Initiale du jour, pour l'axe de l'histogramme.
  String get initial => const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][
    (dayOfWeek.clamp(1, 7)) - 1
  ];

  String get dayLabel => const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ][(dayOfWeek.clamp(1, 7)) - 1];
}

/// Une semaine complète : l'histogramme, la moyenne, le score, les conseils.
class SleepWeek {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<SleepDay> days;
  final int nightsLogged;
  final int? averageMinutes;
  final int? score;
  final String headline;
  final int? weekendCatchUpMinutes;
  final List<String> tips;
  final bool currentWeek;

  const SleepWeek({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.nightsLogged,
    required this.headline,
    required this.tips,
    required this.currentWeek,
    this.averageMinutes,
    this.score,
    this.weekendCatchUpMinutes,
  });

  factory SleepWeek.fromJson(Map<String, dynamic> json) {
    return SleepWeek(
      weekStart: DateTime.parse(json['weekStart'] as String),
      weekEnd: DateTime.parse(json['weekEnd'] as String),
      days: ((json['days'] as List<dynamic>?) ?? const [])
          .map((e) => SleepDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      nightsLogged: (json['nightsLogged'] as num?)?.toInt() ?? 0,
      averageMinutes: (json['averageMinutes'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toInt(),
      headline: json['headline'] as String? ?? '',
      weekendCatchUpMinutes: (json['weekendCatchUpMinutes'] as num?)?.toInt(),
      tips: ((json['tips'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
      currentWeek: json['currentWeek'] as bool? ?? false,
    );
  }

  /// La plus longue nuit de la semaine — sert d'échelle à l'histogramme.
  ///
  /// Bornée à 9 h au minimum pour que la zone idéale reste visible même sur une
  /// semaine de courtes nuits : sans ce plancher, une semaine à 5 h afficherait
  /// des barres pleine hauteur et donnerait l'impression d'un sans-faute.
  int get scaleMinutes {
    final longest = days
        .map((d) => d.durationMinutes ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return longest < 600 ? 600 : longest + 30;
  }

  String get averageLabel =>
      averageMinutes == null ? '—' : formatDuration(averageMinutes!);
}

/// Ce que l'app demande au lancement : faut-il ouvrir le pop-up, et
/// qu'affiche la tuile de l'accueil ?
class SleepStatus {
  final bool loggedToday;
  final SleepEntry? latest;

  const SleepStatus({required this.loggedToday, this.latest});

  factory SleepStatus.fromJson(Map<String, dynamic> json) {
    final latest = json['latest'];
    return SleepStatus(
      loggedToday: json['loggedToday'] as bool? ?? false,
      latest: latest == null
          ? null
          : SleepEntry.fromJson(latest as Map<String, dynamic>),
    );
  }
}

// ── Helpers de format ─────────────────────────────────────────────────

/// « 23:30 » → [TimeOfDay]. Null si la chaîne est absente ou illisible.
TimeOfDay? parseTimeOfDay(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// [TimeOfDay] → « 23:30 », le format attendu par le backend.
String formatTimeOfDay(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// 450 → « 7 h 30 ». Les minutes sont omises quand elles sont nulles :
/// « 8 h » se lit mieux que « 8 h 00 ».
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m';
}

/// Date `yyyy-MM-dd` — le format des paramètres de requête du backend.
String formatIsoDate(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// « 27 juil. – 2 août » — l'étiquette de la semaine affichée.
String formatWeekRange(DateTime start, DateTime end) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final startLabel = '${start.day} ${months[start.month - 1]}';
  final endLabel = '${end.day} ${months[end.month - 1]}';
  return '$startLabel – $endLabel';
}
