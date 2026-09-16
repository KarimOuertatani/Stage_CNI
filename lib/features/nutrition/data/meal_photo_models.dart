import 'food_model.dart';

/// Un aliment repéré par une analyse automatique — **photo de repas** ou
/// **description vocale**.
///
/// Mappé depuis `AnalyzedFoodDto`. **Rien n'est encore enregistré** : c'est une
/// proposition que l'adhérent ajuste, puis confirme aliment par aliment via
/// `POST /nutrition/from-food` — le chemin d'écriture habituel.
///
/// Les macros arrivent **deux fois** : calculées pour la quantité estimée, et
/// ramenées à 100 g. Ce sont ces dernières qui permettent de recalculer
/// **en direct** quand l'utilisateur corrige la quantité, sans rappeler le
/// serveur. La valeur enregistrée reste celle que le serveur recalcule à la
/// confirmation : une seule source de vérité.
class AnalyzedFood {
  /// Nom tel que le modèle l'a compris (« blanc de poulet ») — sur la photo,
  /// ou dans la phrase prononcée.
  final String detectedLabel;

  /// Quantité estimée en grammes, corrigeable par l'adhérent.
  final double quantityGrams;

  /// Confiance du modèle entre 0 et 1, `null` si non fournie.
  final double? confidence;

  /// L'aliment a été retrouvé au catalogue : il porte alors ses macros et
  /// peut être ajouté au journal. Sinon, seule la saisie manuelle est possible.
  final bool matched;

  /// Libellé de l'aliment retrouvé au catalogue (déjà en français).
  final String? foodName;

  final String? foodItemId;
  final int? fdcId;

  /// Code-barres Open Food Facts, quand c'est cette source qui a fourni
  /// l'aliment. Un seul des trois identifiants est renseigné.
  final String? offCode;

  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;

  const AnalyzedFood({
    required this.detectedLabel,
    required this.quantityGrams,
    required this.matched,
    this.confidence,
    this.foodName,
    this.foodItemId,
    this.fdcId,
    this.offCode,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
  });

  factory AnalyzedFood.fromJson(Map<String, dynamic> j) => AnalyzedFood(
    detectedLabel: (j['detectedLabel'] as String?) ?? 'Aliment',
    quantityGrams: (j['quantityGrams'] as num?)?.toDouble() ?? 100,
    confidence: (j['confidence'] as num?)?.toDouble(),
    matched: j['matched'] as bool? ?? false,
    foodName: j['foodName'] as String?,
    foodItemId: j['foodItemId'] as String?,
    fdcId: (j['fdcId'] as num?)?.toInt(),
    offCode: j['offCode'] as String?,
    caloriesPer100g: (j['caloriesPer100g'] as num?)?.toDouble(),
    proteinPer100g: (j['proteinPer100g'] as num?)?.toDouble(),
    carbsPer100g: (j['carbsPer100g'] as num?)?.toDouble(),
    fatPer100g: (j['fatPer100g'] as num?)?.toDouble(),
    fiberPer100g: (j['fiberPer100g'] as num?)?.toDouble(),
  );

  /// Clé de liste stable.
  String get key {
    if (foodItemId != null) return foodItemId!;
    if (offCode != null) return 'off-$offCode';
    return 'fdc-${fdcId ?? detectedLabel.hashCode}';
  }

  /// Aperçu des macros pour [grams] — même formule que le serveur.
  MacroPreview previewFor(double grams) {
    final ratio = grams / 100.0;
    return MacroPreview(
      calories: ((caloriesPer100g ?? 0) * ratio).round(),
      protein: (proteinPer100g ?? 0) * ratio,
      carbs: (carbsPer100g ?? 0) * ratio,
      fat: (fatPer100g ?? 0) * ratio,
      fiber: fiberPer100g == null ? null : fiberPer100g! * ratio,
    );
  }

  /// Convertit vers le modèle attendu par l'ajout au journal, ce qui permet de
  /// réutiliser tel quel le chemin `POST /nutrition/from-food` déjà en place.
  FoodSearchResult toFoodSearchResult() => FoodSearchResult(
    foodItemId: foodItemId,
    fdcId: fdcId,
    offCode: offCode,
    name: foodName ?? detectedLabel,
    cached: foodItemId != null,
    source: foodItemId != null
        ? FoodResultSource.local
        : (offCode != null
              ? FoodResultSource.openFoodFacts
              : FoodResultSource.usda),
    caloriesPer100g: caloriesPer100g,
    proteinPer100g: proteinPer100g,
    carbsPer100g: carbsPer100g,
    fatPer100g: fatPer100g,
    fiberPer100g: fiberPer100g,
  );
}

/// Résultat complet de l'analyse d'une photo.
class PhotoAnalysis {
  final List<AnalyzedFood> foods;

  /// Nombre d'aliments vus sur la photo (peut dépasser `foods.length` : le
  /// backend plafonne le nombre d'aliments réellement traités).
  final int detectedCount;

  /// Nombre d'aliments effectivement retrouvés au catalogue.
  final int matchedCount;

  const PhotoAnalysis({
    required this.foods,
    required this.detectedCount,
    required this.matchedCount,
  });

  factory PhotoAnalysis.fromJson(Map<String, dynamic> j) => PhotoAnalysis(
    foods: ((j['foods'] as List<dynamic>?) ?? const [])
        .map((e) => AnalyzedFood.fromJson(e as Map<String, dynamic>))
        .toList(),
    detectedCount: (j['detectedCount'] as num?)?.toInt() ?? 0,
    matchedCount: (j['matchedCount'] as num?)?.toInt() ?? 0,
  );

  bool get isEmpty => foods.isEmpty;

  /// Vrai si le modèle a bien vu des aliments mais qu'aucun n'a pu être
  /// rattaché au catalogue — un cas qui mérite un message différent de
  /// « aucun aliment détecté ».
  bool get detectedButNoneMatched => foods.isNotEmpty && matchedCount == 0;
}

/// Résultat complet d'une analyse **vocale** (ou d'une description écrite).
///
/// Même contenu que [PhotoAnalysis], plus la **transcription** — la pièce
/// maîtresse de ce mode : c'est le seul moyen pour l'adhérent de voir ce que
/// le serveur a entendu, de corriger un mot de travers, et de relancer.
class VoiceAnalysis {
  /// Ce que le modèle a compris, mot pour mot. `null` s'il n'a rien entendu.
  final String? transcript;

  final List<AnalyzedFood> foods;
  final int detectedCount;
  final int matchedCount;

  const VoiceAnalysis({
    required this.foods,
    required this.detectedCount,
    required this.matchedCount,
    this.transcript,
  });

  factory VoiceAnalysis.fromJson(Map<String, dynamic> j) => VoiceAnalysis(
    transcript: j['transcript'] as String?,
    foods: ((j['foods'] as List<dynamic>?) ?? const [])
        .map((e) => AnalyzedFood.fromJson(e as Map<String, dynamic>))
        .toList(),
    detectedCount: (j['detectedCount'] as num?)?.toInt() ?? 0,
    matchedCount: (j['matchedCount'] as num?)?.toInt() ?? 0,
  );

  bool get isEmpty => foods.isEmpty;

  /// Des aliments ont été entendus, mais aucun n'existe au catalogue.
  bool get detectedButNoneMatched => foods.isNotEmpty && matchedCount == 0;
}
