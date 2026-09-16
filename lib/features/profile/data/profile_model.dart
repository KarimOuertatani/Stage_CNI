/// Profil physique et sportif de l'adhérent.
///
/// Mappé depuis le `ProfileResponse` du backend. Les champs dérivés
/// ([age], [bmi], [tdee]) sont calculés côté serveur.
class ProfileModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final DateTime? birthDate;
  final int? age;
  final String? gender; // HOMME, FEMME, AUTRE
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final String? goal; // PERTE_POIDS, PRISE_MASSE, MAINTIEN, FORCE, ENDURANCE
  final String? activityLevel; // SEDENTAIRE..TRES_ACTIF
  final String? experienceLevel; // DEBUTANT, INTERMEDIAIRE, AVANCE
  final int? weeklyWorkoutTarget;
  final int? dailyCalorieTarget;
  final int? waterTargetMl;
  final double? averageSleepHours;
  final double? bmi;
  final int? tdee;
  final bool onboardingCompleted;

  const ProfileModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.birthDate,
    this.age,
    this.gender,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.goal,
    this.activityLevel,
    this.experienceLevel,
    this.weeklyWorkoutTarget,
    this.dailyCalorieTarget,
    this.waterTargetMl,
    this.averageSleepHours,
    this.bmi,
    this.tdee,
    this.onboardingCompleted = false,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      goal: json['goal'] as String?,
      activityLevel: json['activityLevel'] as String?,
      experienceLevel: json['experienceLevel'] as String?,
      weeklyWorkoutTarget: (json['weeklyWorkoutTarget'] as num?)?.toInt(),
      dailyCalorieTarget: (json['dailyCalorieTarget'] as num?)?.toInt(),
      waterTargetMl: (json['waterTargetMl'] as num?)?.toInt(),
      averageSleepHours: (json['averageSleepHours'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      tdee: (json['tdee'] as num?)?.toInt(),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    );
  }
}

/// Score d'entraînement hebdomadaire (mappé depuis `TrainingScoreResponse`).
class TrainingScoreModel {
  final int score; // 0..100
  final double weeklyVolumeKg;
  final int sessionsCompleted;
  final double consistencyRate; // 0..1
  final String? insight;

  const TrainingScoreModel({
    required this.score,
    required this.weeklyVolumeKg,
    required this.sessionsCompleted,
    required this.consistencyRate,
    this.insight,
  });

  factory TrainingScoreModel.fromJson(Map<String, dynamic> json) {
    return TrainingScoreModel(
      score: (json['score'] as num?)?.toInt() ?? 0,
      weeklyVolumeKg: (json['weeklyVolumeKg'] as num?)?.toDouble() ?? 0,
      sessionsCompleted: (json['sessionsCompleted'] as num?)?.toInt() ?? 0,
      consistencyRate: (json['consistencyRate'] as num?)?.toDouble() ?? 0,
      insight: json['insight'] as String?,
    );
  }
}
