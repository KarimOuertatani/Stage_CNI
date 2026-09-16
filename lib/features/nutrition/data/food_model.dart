/// D'où vient un résultat de recherche.
///
/// Reflète `FoodResultSource` côté backend. Sert surtout à l'affichage : un
/// produit de marque venu d'Open Food Facts n'inspire pas la même confiance
/// qu'une donnée de référence USDA, et l'adhérent gagne à le savoir.
enum FoodResultSource {
  /// Déjà dans notre catalogue : ajout instantané, aucun appel externe.
  local,

  /// USDA FoodData Central — aliments génériques de référence.
  usda,

  /// Open Food Facts — produits emballés et de marque. Données sous licence
  /// ODbL, créditées dans les mentions légales.
  openFoodFacts,
}

/// Aliment proposé par la recherche nutritionnelle.
///
/// Mappé depuis `FoodSearchResultDto` du backend, qui agrège notre catalogue
/// local, **USDA FoodData Central** (aliments génériques) et **Open Food
/// Facts** (produits emballés). Toutes les valeurs sont exprimées
/// **pour 100 g** — c'est la convention commune aux deux bases.
///
/// L'aperçu des macros affiché pendant la saisie est calculé ici (feedback
/// instantané, sans aller-retour réseau), mais **la valeur enregistrée est
/// toujours celle recalculée par le serveur** : une seule source de vérité.
class FoodSearchResult {
  /// Id dans notre catalogue local — non nul si l'aliment y est déjà.
  final String? foodItemId;

  /// Id USDA FoodData Central — non nul pour un aliment issu d'USDA.
  final int? fdcId;

  /// Code-barres Open Food Facts — non nul pour un produit issu d'OFF.
  ///
  /// Un aliment porte **un seul** de ces trois identifiants : c'est celui-là
  /// que l'app renvoie tel quel à `POST /nutrition/from-food`.
  final String? offCode;

  /// Qui a fourni ce résultat.
  final FoodResultSource source;

  /// Libellé **déjà traduit en français** par le backend : la base USDA est
  /// anglophone, la francisation est faite côté serveur (lexique culinaire)
  /// pour que le libellé stocké dans le journal soit lui aussi en français.
  final String name;

  final String? brand;

  /// Jeu de données USDA (`Foundation`, `SR Legacy`, `Branded`…).
  final String? dataType;

  /// Déjà en catalogue : l'ajout ne déclenchera aucun appel externe.
  final bool cached;

  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;

  const FoodSearchResult({
    this.foodItemId,
    this.fdcId,
    this.offCode,
    required this.name,
    this.brand,
    this.dataType,
    this.source = FoodResultSource.usda,
    this.cached = false,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    final cached = json['cached'] as bool? ?? false;
    return FoodSearchResult(
      foodItemId: json['foodItemId'] as String?,
      fdcId: (json['fdcId'] as num?)?.toInt(),
      offCode: json['offCode'] as String?,
      name: (json['name'] as String?) ?? 'Aliment',
      brand: json['brand'] as String?,
      dataType: json['dataType'] as String?,
      source: _sourceFrom(json['source'] as String?, cached),
      cached: cached,
      caloriesPer100g: (json['caloriesPer100g'] as num?)?.toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num?)?.toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble(),
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble(),
      fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble(),
    );
  }

  /// Repli sur `cached` si le champ `source` manque : une version plus
  /// ancienne du backend n'envoie que le booléen.
  static FoodResultSource _sourceFrom(String? raw, bool cached) {
    return switch (raw) {
      'LOCAL' => FoodResultSource.local,
      'USDA' => FoodResultSource.usda,
      'OPEN_FOOD_FACTS' => FoodResultSource.openFoodFacts,
      _ => cached ? FoodResultSource.local : FoodResultSource.usda,
    };
  }

  /// Clé de liste stable (un aliment porte toujours au moins un identifiant).
  String get key =>
      foodItemId ??
      (offCode != null ? 'off-$offCode' : 'usda-${fdcId ?? name.hashCode}');

  /// Libellé secondaire : marque si connue, sinon la provenance des données.
  String? get subtitle {
    if (brand != null && brand!.trim().isNotEmpty) return brand;
    if (source == FoodResultSource.openFoodFacts) return 'Produit du commerce';
    return switch (dataType) {
      'Foundation' => 'Donnée de référence',
      'SR Legacy' => 'Donnée de référence',
      'Branded' => 'Produit de marque',
      'Survey (FNDDS)' => 'Aliment courant',
      _ => null,
    };
  }

  /// Aperçu des macros pour [grams] grammes (même formule que le serveur :
  /// `macro = macroPour100g × grammes / 100`).
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
}

/// Macros calculées pour une quantité donnée (affichage temps réel).
class MacroPreview {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;

  const MacroPreview({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
  });
}
