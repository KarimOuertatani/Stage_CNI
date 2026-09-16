import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/food_model.dart';
import '../../data/meal_model.dart';
import '../../data/nutrition_api.dart';

class NutritionState {
  /// Jour actuellement consulté dans le journal (peut être un jour passé).
  final DateTime selectedDay;
  final List<MealModel> meals;
  final int dailyGoal;

  /// Calories consommées AUJOURD'HUI (indépendant de [selectedDay]) : sert à
  /// l'accueil, qui doit toujours refléter la journée en cours même si
  /// l'utilisateur navigue dans l'historique.
  final int todayCalories;

  final bool isLoading;
  final String? errorMessage;

  NutritionState({
    DateTime? selectedDay,
    this.meals = const [],
    this.dailyGoal = 2000,
    this.todayCalories = 0,
    this.isLoading = false,
    this.errorMessage,
  }) : selectedDay = selectedDay ?? _today();

  int get consumedCalories => meals.fold(0, (s, m) => s + m.calories);
  int get consumedProtein => meals.fold(0, (s, m) => s + m.protein);
  int get consumedCarbs => meals.fold(0, (s, m) => s + m.carbs);
  int get consumedFat => meals.fold(0, (s, m) => s + m.fat);
  int get consumedFiber => meals.fold(0, (s, m) => s + m.fiber);

  /// Repas du jour regroupés par moment (petit-déj, déjeuner, collation, dîner),
  /// dans l'ordre chronologique naturel de la journée.
  Map<MealType, List<MealModel>> get mealsByType {
    final grouped = <MealType, List<MealModel>>{};
    for (final type in const [
      MealType.breakfast,
      MealType.lunch,
      MealType.snack,
      MealType.dinner,
    ]) {
      final items = meals.where((m) => m.type == type).toList();
      if (items.isNotEmpty) grouped[type] = items;
    }
    return grouped;
  }

  /// Vrai si le jour consulté est aujourd'hui (bloque la navigation « futur »).
  bool get isToday => _sameDay(selectedDay, _today());

  NutritionState copyWith({
    DateTime? selectedDay,
    List<MealModel>? meals,
    int? dailyGoal,
    int? todayCalories,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NutritionState(
      selectedDay: selectedDay ?? this.selectedDay,
      meals: meals ?? this.meals,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      todayCalories: todayCalories ?? this.todayCalories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class NutritionNotifier extends Notifier<NutritionState> {
  late final NutritionApi _nutritionApi = ref.read(nutritionApiProvider);

  @override
  NutritionState build() {
    Future.microtask(loadTodayData);
    return NutritionState(isLoading: true);
  }

  /// Charge la journée en cours (utilisé au démarrage et par l'accueil).
  Future<void> loadTodayData() => loadDay(_today());

  /// Charge le journal d'un jour donné.
  Future<void> loadDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    state = state.copyWith(
      selectedDay: normalized,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final meals = await _nutritionApi.getMeals(normalized);
      final goal = await _nutritionApi.getDailyGoal();
      final isToday = _sameDay(normalized, _today());
      final todayCals = isToday
          ? meals.fold<int>(0, (s, m) => s + m.calories)
          : state.todayCalories;
      state = NutritionState(
        selectedDay: normalized,
        meals: meals,
        dailyGoal: goal,
        todayCalories: todayCals,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Jour précédent.
  Future<void> previousDay() =>
      loadDay(state.selectedDay.subtract(const Duration(days: 1)));

  /// Jour suivant (jamais au-delà d'aujourd'hui).
  Future<void> nextDay() {
    if (state.isToday) return Future.value();
    return loadDay(state.selectedDay.add(const Duration(days: 1)));
  }

  /// Revenir à aujourd'hui.
  Future<void> goToday() => loadDay(_today());

  /// Ajoute un repas au jour consulté puis l'insère dans l'état.
  Future<void> addMeal(
    String name,
    MealType type,
    int calories,
    int protein,
    int carbs,
    int fat,
  ) async {
    try {
      final created = await _nutritionApi.addMeal(
        day: state.selectedDay,
        name: name,
        type: type,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
      final meals = [...state.meals, created];
      // Si on ajoute pour aujourd'hui, on met aussi à jour le total « accueil ».
      final today = state.isToday
          ? meals.fold<int>(0, (s, m) => s + m.calories)
          : state.todayCalories;
      state = state.copyWith(meals: meals, todayCalories: today);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Ajoute un aliment **du catalogue** au jour consulté.
  ///
  /// On n'envoie que la quantité : le backend calcule les macros au prorata
  /// depuis les valeurs pour 100 g (USDA). Renvoie `null` en cas de succès,
  /// sinon le message d'erreur à afficher.
  Future<String?> addFoodEntry({
    required FoodSearchResult food,
    required MealType type,
    required double grams,
  }) async {
    try {
      final created = await _nutritionApi.addFoodEntry(
        day: state.selectedDay,
        type: type,
        food: food,
        grams: grams,
      );
      _replaceMeals([...state.meals, created]);
      return null;
    } catch (e) {
      final message = _messageFrom(e);
      state = state.copyWith(errorMessage: message);
      return message;
    }
  }

  /// Change la quantité d'une entrée issue du catalogue (macros recalculées
  /// côté serveur, qui reste la seule source de vérité).
  Future<String?> updateQuantity(String entryId, double grams) async {
    try {
      final updated = await _nutritionApi.updateQuantity(entryId, grams);
      _replaceMeals([
        for (final m in state.meals) m.id == entryId ? updated : m,
      ]);
      return null;
    } catch (e) {
      final message = _messageFrom(e);
      state = state.copyWith(errorMessage: message);
      return message;
    }
  }

  /// Applique une nouvelle liste de repas en gardant le total « accueil »
  /// cohérent (il ne doit refléter QUE la journée en cours).
  void _replaceMeals(List<MealModel> meals) {
    final today = state.isToday
        ? meals.fold<int>(0, (s, m) => s + m.calories)
        : state.todayCalories;
    state = state.copyWith(meals: meals, todayCalories: today);
  }

  /// Message lisible : on privilégie celui renvoyé par le backend.
  String _messageFrom(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      final mapped = e.error;
      if (mapped is ApiException) return mapped.message;
    }
    return 'Une erreur est survenue.';
  }

  /// Supprime une entrée du journal.
  Future<void> deleteMeal(String id) async {
    try {
      await _nutritionApi.deleteMeal(id);
      final meals = state.meals.where((m) => m.id != id).toList();
      final today = state.isToday
          ? meals.fold<int>(0, (s, m) => s + m.calories)
          : state.todayCalories;
      state = state.copyWith(meals: meals, todayCalories: today);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

// ── Helpers de date (au niveau fichier) ────────────────────────────────
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final nutritionApiProvider = Provider<NutritionApi>(
  (ref) => NutritionApi(ref.read(dioClientProvider)),
);

final nutritionProvider = NotifierProvider<NutritionNotifier, NutritionState>(
  NutritionNotifier.new,
);
