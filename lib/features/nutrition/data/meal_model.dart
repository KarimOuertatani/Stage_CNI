/// Modèle d'entrée du journal alimentaire.
///
/// Mappé depuis le `NutritionEntryResponse` du backend :
/// { id, consumedOn, mealType, foodItemId, foodName, quantityGrams, calories,
///   proteinG, carbsG, fatG, fiberG }.
/// Chaque entrée backend = un aliment/repas ; l'UI l'affiche comme un [MealModel].
class MealModel {
  final String id;
  final String name;
  final MealType type;
  final int calories;
  final int protein; // en grammes
  final int carbs; // en grammes
  final int fat; // en grammes
  final int fiber; // en grammes
  final String
  time; // dérivé du type de repas (le backend ne stocke pas d'heure)
  final List<String> foods;

  /// Quantité consommée en grammes (null pour les anciennes saisies libres).
  final double? quantityGrams;

  /// Aliment du catalogue dont provient l'entrée.
  ///
  /// Non nul ⇒ la quantité est modifiable et le serveur recalcule les macros.
  /// Nul ⇒ saisie manuelle : les valeurs doivent être re-saisies à la main.
  final String? foodItemId;

  const MealModel({
    required this.id,
    required this.name,
    required this.type,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    required this.time,
    required this.foods,
    this.quantityGrams,
    this.foodItemId,
  });

  /// Vrai si l'entrée vient du catalogue (quantité ajustable en un geste).
  bool get isFromCatalog => foodItemId != null;

  factory MealModel.fromJson(Map<String, dynamic> json) {
    final type = mealTypeFromApi(json['mealType'] as String?);
    final name = (json['foodName'] as String?) ?? 'Aliment';
    return MealModel(
      id: json['id'] as String,
      name: name,
      type: type,
      calories: (json['calories'] as num?)?.round() ?? 0,
      protein: (json['proteinG'] as num?)?.round() ?? 0,
      carbs: (json['carbsG'] as num?)?.round() ?? 0,
      fat: (json['fatG'] as num?)?.round() ?? 0,
      fiber: (json['fiberG'] as num?)?.round() ?? 0,
      time: _defaultTimeForType(type),
      foods: [name],
      quantityGrams: (json['quantityGrams'] as num?)?.toDouble(),
      foodItemId: json['foodItemId'] as String?,
    );
  }

  /// Enum backend `MealType` -> enum Flutter.
  static MealType mealTypeFromApi(String? value) {
    switch (value) {
      case 'PETIT_DEJ':
        return MealType.breakfast;
      case 'DEJEUNER':
        return MealType.lunch;
      case 'DINER':
        return MealType.dinner;
      case 'COLLATION':
        return MealType.snack;
      default:
        return MealType.snack;
    }
  }

  /// Enum Flutter -> valeur attendue par le backend.
  static String mealTypeToApi(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'PETIT_DEJ';
      case MealType.lunch:
        return 'DEJEUNER';
      case MealType.dinner:
        return 'DINER';
      case MealType.snack:
        return 'COLLATION';
    }
  }

  /// Heure d'affichage par défaut selon le type de repas.
  static String _defaultTimeForType(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return '07:30';
      case MealType.lunch:
        return '12:30';
      case MealType.snack:
        return '16:00';
      case MealType.dinner:
        return '20:00';
    }
  }
}

enum MealType { breakfast, lunch, snack, dinner }
