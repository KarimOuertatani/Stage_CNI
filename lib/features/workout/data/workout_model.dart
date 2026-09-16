import 'muscle_effort.dart';

/// Modèle d'exercice (référentiel).
///
/// Mappé depuis l'`ExerciseResponse` du backend :
/// { id, name, primaryMuscle, equipment, instructions, videoUrl }.
///
/// [muscleGroup], [difficulty] et [icon] sont dérivés des enums backend.
/// [durationMinutes] et [caloriesBurned] ne sont pas fournis par le backend
/// (Partie 1) : ce sont des estimations dérivées du groupe musculaire, pour
/// garder l'UI existante (carte d'exercice) cohérente et variée.
class WorkoutModel {
  final String id;
  final String name;
  final String muscleGroup; // libellé FR (aligné sur les filtres de l'écran)
  final ExerciseLevel level; // niveau requis (calculé et stocké côté serveur)
  final IconLabel icon;
  final int durationMinutes; // estimation
  final int caloriesBurned; // estimation
  final String? equipment; // enum backend (BARRE, HALTERE...)
  final String? instructions;
  final String? videoUrl;

  // ── Champs enrichis ExerciseDB (null pour les exercices seed) ──
  final String? overview; // presentation generale
  final String? exerciseTips; // conseils (elements joints par " | ")
  final String? variations; // variations (elements joints par " | ")
  final String? secondaryMuscles; // muscles secondaires (", ")
  final String? targetMuscles; // muscles cibles (", ")
  final String? bodyPart; // partie du corps ExerciseDB (brut)
  final String? exerciseType; // STRENGTH, CARDIO, STRETCHING...
  final String? imageUrl; // image par defaut (aperçu liste)
  final String? imageUrl360p; // aperçu leger (liste)
  final String? imageUrl720p; // resolution ecran de detail

  const WorkoutModel({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.level,
    required this.icon,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.equipment,
    this.instructions,
    this.videoUrl,
    this.overview,
    this.exerciseTips,
    this.variations,
    this.secondaryMuscles,
    this.targetMuscles,
    this.bodyPart,
    this.exerciseType,
    this.imageUrl,
    this.imageUrl360p,
    this.imageUrl720p,
  });

  /// Libellé FR du niveau — conservé pour les affichages qui n'ont besoin que
  /// du texte (badges, filtres). La valeur typée reste [level].
  String get difficulty => level.label;

  /// Vrai si l'exercice possede une video de demonstration exploitable.
  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  /// Libellé FR du matériel (`BARRE` → « Barre »), null si non renseigné.
  ///
  /// Vit sur le modèle et non dans un écran : la carte, le détail, la feuille
  /// de séance et la barre de filtres l'affichent tous, et trois recopies de la
  /// même table de correspondance finiraient par se contredire.
  String? get equipmentLabel => switch (equipment) {
    'BARRE' => 'Barre',
    'HALTERE' => 'Haltère',
    'MACHINE' => 'Machine',
    'POULIE' => 'Poulie',
    'KETTLEBELL' => 'Kettlebell',
    'POIDS_CORPS' => 'Poids du corps',
    'ELASTIQUE' => 'Élastique',
    _ => null,
  };

  /// Libellé FR du type d'exercice ExerciseDB, null si non renseigné.
  String? get typeLabel {
    final t = exerciseType?.toUpperCase();
    if (t == null || t.isEmpty) return null;
    if (t.contains('STRETCH')) return 'Étirement';
    if (t.contains('CARDIO')) return 'Cardio';
    if (t.contains('STRENGTH')) return 'Force';
    if (t.contains('PLYO')) return 'Pliométrie';
    return null;
  }

  /// Muscles cibles éclatés en liste lisible (« PECTORALIS MAJOR » → ...).
  List<String> get targetMusclesList => _splitList(targetMuscles, ',');

  /// Muscles secondaires éclatés en liste.
  List<String> get secondaryMusclesList => _splitList(secondaryMuscles, ',');

  /// Meilleure image disponible pour l'ecran de detail (720p sinon defaut).
  String? get detailImageUrl =>
      (imageUrl720p != null && imageUrl720p!.isNotEmpty)
      ? imageUrl720p
      : imageUrl;

  /// Aperçu leger pour les listes (360p sinon image par defaut). JAMAIS la video.
  String? get thumbnailUrl => (imageUrl360p != null && imageUrl360p!.isNotEmpty)
      ? imageUrl360p
      : imageUrl;

  /// Etapes d'instructions eclatees en liste (stockees jointes par " | ").
  List<String> get instructionSteps => _splitList(instructions, ' | ');

  /// Conseils eclatees en liste (stockes joints par " | ").
  List<String> get tipsList => _splitList(exerciseTips, ' | ');

  /// Variations eclatees en liste (stockees jointes par " | ").
  List<String> get variationsList => _splitList(variations, ' | ');

  static List<String> _splitList(String? value, String sep) {
    if (value == null || value.trim().isEmpty) return const [];
    return value
        .split(sep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory WorkoutModel.fromJson(Map<String, dynamic> json) {
    final muscle = json['primaryMuscle'] as String?;
    final equipment = json['equipment'] as String?;
    final duration = _estimatedDuration(muscle);
    return WorkoutModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      muscleGroup: _muscleLabel(muscle),
      // Le niveau vient désormais du serveur, où il est calculé une fois à
      // partir du nom, du type et du matériel. Le repli sur l'équipement ne
      // sert plus qu'aux bases pas encore migrées (colonne `difficulty` nulle).
      level:
          ExerciseLevel.fromApi(json['difficulty'] as String?) ??
          _levelFromEquipment(equipment),
      icon: _iconFromMuscle(muscle),
      durationMinutes: duration,
      caloriesBurned: _estimatedCalories(muscle, duration),
      equipment: equipment,
      instructions: json['instructions'] as String?,
      videoUrl: json['videoUrl'] as String?,
      overview: json['overview'] as String?,
      exerciseTips: json['exerciseTips'] as String?,
      variations: json['variations'] as String?,
      secondaryMuscles: json['secondaryMuscles'] as String?,
      targetMuscles: json['targetMuscles'] as String?,
      bodyPart: json['bodyPart'] as String?,
      exerciseType: json['exerciseType'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imageUrl360p: json['imageUrl360p'] as String?,
      imageUrl720p: json['imageUrl720p'] as String?,
    );
  }

  /// Enum backend `MuscleGroup` -> libellé français affiché/filtrable.
  static String _muscleLabel(String? muscle) {
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
      case 'TRICEPS':
        return 'Bras';
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

  /// Enum backend `MuscleGroup` -> icône du groupe (pour la carte d'exercice).
  static IconLabel _iconFromMuscle(String? muscle) {
    switch (muscle) {
      case 'PECTORAUX':
        return IconLabel.chest;
      case 'DOS':
        return IconLabel.back;
      case 'JAMBES':
      case 'FESSIERS':
      case 'MOLLETS':
        return IconLabel.legs;
      case 'EPAULES':
        return IconLabel.shoulders;
      case 'BICEPS':
      case 'TRICEPS':
        return IconLabel.arms;
      default:
        return IconLabel.abs;
    }
  }

  /// Repli quand le serveur ne renvoie pas encore de niveau (base non migrée).
  ///
  /// Volontairement grossier : c'est exactement la déduction que le serveur
  /// remplace. On ne la raffine pas ici — améliorer le repli reviendrait à
  /// maintenir deux règles concurrentes, et c'est celle du serveur qui fait foi.
  static ExerciseLevel _levelFromEquipment(String? equipment) {
    switch (equipment) {
      case 'POIDS_CORPS':
      case 'ELASTIQUE':
      case 'MACHINE':
        return ExerciseLevel.debutant;
      case 'BARRE':
      case 'KETTLEBELL':
        return ExerciseLevel.avance;
      default:
        return ExerciseLevel.intermediaire;
    }
  }

  /// Durée estimée (min) : les gros groupes/cardio prennent plus de temps.
  static int _estimatedDuration(String? muscle) {
    switch (muscle) {
      case 'JAMBES':
      case 'DOS':
      case 'FESSIERS':
        return 30;
      case 'PECTORAUX':
      case 'CARDIO':
        return 25;
      case 'EPAULES':
      case 'ABDOS':
        return 20;
      default:
        return 15;
    }
  }

  /// Calories estimées : ~8 kcal/min, majoré pour le cardio/gros groupes.
  static int _estimatedCalories(String? muscle, int duration) {
    final perMinute =
        (muscle == 'CARDIO' || muscle == 'JAMBES' || muscle == 'DOS') ? 10 : 7;
    return duration * perMinute;
  }
}

/// Labels d'icônes pour chaque groupe musculaire.
enum IconLabel { chest, legs, back, arms, shoulders, abs }

/// Niveau requis pour réaliser un exercice.
///
/// Typé plutôt que laissé en `String` : le filtre « niveau » de la
/// bibliothèque compare des valeurs, et une comparaison de chaînes accentuées
/// (« Avancé ») échoue silencieusement à la première faute de frappe. L'ordre
/// de déclaration est l'ordre croissant de difficulté — le tri par niveau s'en
/// sert directement via [index].
enum ExerciseLevel {
  debutant('Débutant', 'DEBUTANT'),
  intermediaire('Intermédiaire', 'INTERMEDIAIRE'),
  avance('Avancé', 'AVANCE');

  /// Libellé affiché à l'adhérent.
  final String label;

  /// Valeur de l'enum backend (`ExperienceLevel`), pour les requêtes.
  final String apiValue;

  const ExerciseLevel(this.label, this.apiValue);

  /// Convertit la valeur renvoyée par l'API. Null si absente ou inconnue —
  /// l'appelant décide alors du repli plutôt que de recevoir un niveau inventé.
  static ExerciseLevel? fromApi(String? value) {
    if (value == null) return null;
    for (final level in ExerciseLevel.values) {
      if (level.apiValue == value) return level;
    }
    return null;
  }
}

/// Charge d'entraînement de la fenêtre courante, aux **deux granularités**
/// dont l'app a besoin.
///
/// Les deux sont calculées d'un même passage sur les séances, mais ne se
/// déduisent pas l'une de l'autre : [groups] compte les séries par zone
/// (silhouette 2D, cartes, résumé), [muscles] ventile chaque série sur les
/// muscles réellement sollicités (modèle 3D anatomique).
class MuscleLoad {
  final List<MuscleIntensity> groups;
  final MuscleEffort muscles;

  const MuscleLoad({required this.groups, required this.muscles});

  static const MuscleLoad empty = MuscleLoad(
    groups: [],
    muscles: MuscleEffort.empty,
  );
}

/// Intensité d'entraînement par groupe musculaire (pour le body 2D/3D).
/// Non fournie par le backend (Partie 1) : reste calculée côté app à partir
/// des séances loggées durant la session.
class MuscleIntensity {
  final String group;
  final double intensity; // 0.0 → 1.0

  const MuscleIntensity({required this.group, required this.intensity});

  /// Données par défaut (avant tout entraînement enregistré).
  static List<MuscleIntensity> mockData() => const [
    MuscleIntensity(group: 'Pectoraux', intensity: 0.0),
    MuscleIntensity(group: 'Dos', intensity: 0.0),
    MuscleIntensity(group: 'Épaules', intensity: 0.0),
    MuscleIntensity(group: 'Bras', intensity: 0.0),
    MuscleIntensity(group: 'Abdominaux', intensity: 0.0),
    MuscleIntensity(group: 'Jambes', intensity: 0.0),
  ];
}
