import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/constants/api_constants.dart';
import 'food_model.dart';
import 'meal_photo_models.dart';
import 'meal_model.dart';

/// Service API nutrition (backend Spring Boot).
///
/// La recherche d'aliments passe **uniquement par notre backend** : la clé USDA
/// FoodData Central ne quitte jamais le serveur et n'est donc pas embarquée
/// dans l'APK.
class NutritionApi {
  final Dio _dio;

  NutritionApi(this._dio);

  // ── Catalogue d'aliments ────────────────────────────────────────

  /// Recherche un aliment (`GET /nutrition/foods/search?query=`).
  ///
  /// [cancelToken] permet d'annuler une requête devenue obsolète quand
  /// l'utilisateur continue de taper — évite qu'une réponse lente écrase
  /// les résultats d'une frappe plus récente.
  Future<List<FoodSearchResult>> searchFoods(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      ApiConstants.foodSearch,
      queryParameters: {'query': query},
      cancelToken: cancelToken,
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => FoodSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mes aliments les plus utilisés (`GET /nutrition/foods/recent`).
  Future<List<FoodSearchResult>> recentFoods() async {
    final response = await _dio.get(ApiConstants.foodRecent);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => FoodSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ajoute un aliment du catalogue au journal (`POST /nutrition/from-food`).
  ///
  /// On n'envoie **que la quantité** : le serveur calcule calories, protéines,
  /// glucides, lipides et fibres au prorata.
  ///
  /// On renvoie **l'identifiant que la recherche a fourni**, et lui seul :
  /// `foodItemId` si l'aliment est déjà en catalogue, sinon `fdcId` (USDA) ou
  /// `offCode` (Open Food Facts). C'est cet identifiant qui dit au serveur
  /// quelle source interroger — et lui évite de deviner.
  Future<MealModel> addFoodEntry({
    required DateTime day,
    required MealType type,
    required FoodSearchResult food,
    required double grams,
  }) async {
    final response = await _dio.post(
      ApiConstants.nutritionFromFood,
      data: {
        ..._foodReference(food),
        'consumedOn': _formatDate(day),
        'mealType': MealModel.mealTypeToApi(type),
        'quantityGrams': grams,
      },
    );
    return MealModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// L'unique identifiant qui désigne cet aliment, par ordre de priorité.
  static Map<String, dynamic> _foodReference(FoodSearchResult food) {
    if (food.foodItemId != null) return {'foodItemId': food.foodItemId};
    if (food.fdcId != null) return {'fdcId': food.fdcId};
    if (food.offCode != null) return {'offCode': food.offCode};
    return const {};
  }

  // ── Analyse de photo ────────────────────────────────────────────

  /// Analyse une photo de repas (`POST /nutrition/analyze-photo`).
  ///
  /// **N'enregistre rien** : le backend renvoie une proposition d'aliments avec
  /// leurs macros estimées. C'est [addFoodEntry] qui écrit, une fois que
  /// l'adhérent a validé.
  ///
  /// Le délai est volontairement plus long que la valeur par défaut : la
  /// lecture d'une image prend quelques secondes, et chaque aliment reconnu
  /// peut déclencher une recherche au catalogue.
  Future<PhotoAnalysis> analyzePhoto(
    String path, {
    String? filename,
    String? contentType,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: filename ?? 'repas.jpg',
        contentType: MediaType.parse(contentType ?? 'image/jpeg'),
      ),
    });
    final response = await _dio.post(
      ApiConstants.nutritionAnalyzePhoto,
      data: form,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    return PhotoAnalysis.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Ajout vocal ─────────────────────────────────────────────────

  /// Analyse une description **vocale** de repas
  /// (`POST /nutrition/analyze-voice`).
  ///
  /// L'adhérent dit ce qu'il a mangé ; le backend transcrit, convertit les
  /// unités parlées en grammes (« deux œufs » → 100 g) et retrouve les macros.
  ///
  /// **N'enregistre rien** : c'est [addFoodEntry] qui écrit, une fois que
  /// l'adhérent a validé.
  ///
  /// Le délai est plus long que la valeur par défaut : le modèle doit
  /// transcrire l'enregistrement **avant** de raisonner dessus.
  Future<VoiceAnalysis> analyzeVoice(
    String path, {
    String? filename,
    String? contentType,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: filename ?? 'repas.m4a',
        contentType: MediaType.parse(contentType ?? 'audio/mp4'),
      ),
    });
    final response = await _dio.post(
      ApiConstants.nutritionAnalyzeVoice,
      data: form,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    return VoiceAnalysis.fromJson(response.data as Map<String, dynamic>);
  }

  /// Analyse une description **écrite** de repas
  /// (`POST /nutrition/analyze-text`).
  ///
  /// Deux usages : repli quand l'enregistrement n'a pas pu être analysé, et
  /// correction quand la transcription comporte un mot mal entendu. Le
  /// traitement est identique côté serveur, donc le résultat aussi.
  Future<VoiceAnalysis> analyzeText(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      ApiConstants.nutritionAnalyzeText,
      data: {'text': text},
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return VoiceAnalysis.fromJson(response.data as Map<String, dynamic>);
  }

  /// Change la quantité d'une entrée issue du catalogue
  /// (`PATCH /nutrition/{id}/quantity?grams=`) — macros recalculées serveur.
  Future<MealModel> updateQuantity(String entryId, double grams) async {
    final response = await _dio.patch(
      '${ApiConstants.nutrition}/$entryId/quantity',
      queryParameters: {'grams': grams},
    );
    return MealModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Journal alimentaire d'un jour (`GET /nutrition?date=yyyy-MM-dd`).
  Future<List<MealModel>> getMeals(DateTime day) async {
    final response = await _dio.get(
      ApiConstants.nutrition,
      queryParameters: {'date': _formatDate(day)},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => MealModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ajoute un aliment/repas au journal (`POST /nutrition`).
  Future<MealModel> addMeal({
    required DateTime day,
    required String name,
    required MealType type,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    final response = await _dio.post(
      ApiConstants.nutrition,
      data: {
        'consumedOn': _formatDate(day),
        'mealType': MealModel.mealTypeToApi(type),
        'foodName': name,
        'calories': calories,
        'proteinG': protein,
        'carbsG': carbs,
        'fatG': fat,
      },
    );
    return MealModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Supprime une entrée (`DELETE /nutrition/{id}`).
  Future<void> deleteMeal(String id) async {
    await _dio.delete('${ApiConstants.nutrition}/$id');
  }

  /// Objectif calorique quotidien : lu depuis le profil (dailyCalorieTarget,
  /// sinon TDEE), avec repli sur 2400 kcal si le profil n'est pas renseigné.
  Future<int> getDailyGoal() async {
    try {
      final response = await _dio.get(ApiConstants.profile);
      final data = response.data as Map<String, dynamic>;
      final target = data['dailyCalorieTarget'] as num?;
      final tdee = data['tdee'] as num?;
      return (target ?? tdee)?.round() ?? 2400;
    } catch (_) {
      return 2400;
    }
  }

  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
