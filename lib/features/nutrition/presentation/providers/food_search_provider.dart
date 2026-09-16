import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/food_model.dart';
import 'nutrition_provider.dart';

/// État de la recherche d'aliments.
class FoodSearchState {
  /// Terme actuellement saisi.
  final String query;

  /// Résultats de la recherche en cours.
  final List<FoodSearchResult> results;

  /// Aliments déjà consommés par l'adhérent (proposés quand le champ est vide).
  final List<FoodSearchResult> recent;

  final bool isLoading;
  final bool isLoadingRecent;
  final String? errorMessage;

  /// Vrai dès qu'une recherche a abouti : distingue « pas encore cherché »
  /// de « cherché, aucun résultat ».
  final bool hasSearched;

  const FoodSearchState({
    this.query = '',
    this.results = const [],
    this.recent = const [],
    this.isLoading = false,
    this.isLoadingRecent = false,
    this.errorMessage,
    this.hasSearched = false,
  });

  /// Le champ est vide (ou trop court) : on affiche les aliments récents.
  bool get showsRecent =>
      query.trim().length < FoodSearchNotifier.minQueryLength;

  FoodSearchState copyWith({
    String? query,
    List<FoodSearchResult>? results,
    List<FoodSearchResult>? recent,
    bool? isLoading,
    bool? isLoadingRecent,
    String? errorMessage,
    bool? hasSearched,
  }) {
    return FoodSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      recent: recent ?? this.recent,
      isLoading: isLoading ?? this.isLoading,
      isLoadingRecent: isLoadingRecent ?? this.isLoadingRecent,
      errorMessage: errorMessage, // réinitialisé si non fourni explicitement
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

/// Recherche d'aliments avec **anti-rebond** et **annulation**.
///
/// Deux protections indispensables ici, car le backend appelle l'API USDA :
///  • le *debounce* (350 ms) évite de déclencher une requête par frappe ;
///  • le [CancelToken] annule la requête précédente dès qu'une nouvelle part,
///    ce qui empêche une réponse lente d'écraser des résultats plus récents
///    (condition de course classique sur les champs de recherche).
class FoodSearchNotifier extends Notifier<FoodSearchState> {
  /// Longueur minimale avant de lancer une recherche (aligné sur le backend).
  static const int minQueryLength = 2;

  static const Duration _debounceDelay = Duration(milliseconds: 350);

  Timer? _debounce;
  CancelToken? _inFlight;

  /// Identifie la dernière recherche lancée : une réponse tardive portant un
  /// numéro périmé est ignorée.
  int _requestId = 0;

  @override
  FoodSearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _inFlight?.cancel();
    });
    Future.microtask(loadRecent);
    return const FoodSearchState(isLoadingRecent: true);
  }

  /// Charge les aliments les plus utilisés (affichés quand le champ est vide).
  Future<void> loadRecent() async {
    try {
      final recent = await ref.read(nutritionApiProvider).recentFoods();
      state = state.copyWith(recent: recent, isLoadingRecent: false);
    } catch (_) {
      // Non bloquant : la recherche reste pleinement utilisable.
      state = state.copyWith(isLoadingRecent: false);
    }
  }

  /// Appelé à chaque frappe : programme la recherche après le délai d'inertie.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);

    if (query.trim().length < minQueryLength) {
      // Champ vidé : on annule tout et on revient aux aliments récents.
      _inFlight?.cancel();
      state = state.copyWith(
        results: const [],
        isLoading: false,
        hasSearched: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    _debounce = Timer(_debounceDelay, () => _run(query.trim()));
  }

  /// Relance la dernière recherche (bouton « Réessayer »).
  void retry() {
    final q = state.query.trim();
    if (q.length >= minQueryLength) {
      state = state.copyWith(isLoading: true);
      _run(q);
    }
  }

  Future<void> _run(String query) async {
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;
    final requestId = ++_requestId;

    try {
      final results = await ref
          .read(nutritionApiProvider)
          .searchFoods(query, cancelToken: token);
      // Une frappe plus récente a pris le relais.
      if (requestId != _requestId) {
        return;
      }
      state = state.copyWith(
        results: results,
        isLoading: false,
        hasSearched: true,
      );
    } on DioException catch (e) {
      // Annulation volontaire : rien à signaler.
      if (CancelToken.isCancel(e)) {
        return;
      }
      if (requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        hasSearched: true,
        errorMessage: _messageFrom(e),
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        hasSearched: true,
        errorMessage: _messageFrom(e),
      );
    }
  }

  /// Message lisible : on privilégie celui renvoyé par le backend (quota USDA
  /// atteint, service injoignable…), sinon un repli générique.
  String _messageFrom(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      final mapped = e.error;
      if (mapped is ApiException) return mapped.message;
    }
    return 'Recherche impossible pour le moment.';
  }
}

/// Auto-disposé : l'état repart à zéro à chaque ouverture de la recherche.
final foodSearchProvider =
    NotifierProvider.autoDispose<FoodSearchNotifier, FoodSearchState>(
      FoodSearchNotifier.new,
    );
