import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import 'sleep_models.dart';

/// Service API « Sommeil » (backend Spring Boot).
///
/// Trois appels, qui suivent le parcours de l'adhérent : on lui demande sa nuit
/// au réveil ([status]), il la saisit ([save]), il consulte sa semaine
/// ([week]).
class SleepApi {
  final Dio _dio;

  SleepApi(this._dio);

  /// Faut-il ouvrir le pop-up, et qu'affiche la tuile de l'accueil ?
  ///
  /// Les deux réponses en un appel — elles sont demandées au même moment, au
  /// lancement de l'application, sur un écran qui fait déjà plusieurs
  /// allers-retours.
  Future<SleepStatus> status() async {
    final res = await _dio.get(ApiConstants.sleepStatus);
    return SleepStatus.fromJson(res.data as Map<String, dynamic>);
  }

  /// Enregistre (ou corrige) une nuit et renvoie le conseil qui va avec.
  ///
  /// [date] absente = aujourd'hui, le cas de tous les jours puisque la saisie
  /// se fait au réveil.
  Future<SleepEntry> save({
    required TimeOfDay bedTime,
    required TimeOfDay wakeTime,
    DateTime? date,
  }) async {
    final res = await _dio.post(
      ApiConstants.sleep,
      data: {
        'bedTime': formatTimeOfDay(bedTime),
        'wakeTime': formatTimeOfDay(wakeTime),
        'sleepDate': ?(date == null ? null : formatIsoDate(date)),
      },
    );
    return SleepEntry.fromJson(res.data as Map<String, dynamic>);
  }

  /// Une semaine complète. [anyDayOfWeek] peut être n'importe quelle date de la
  /// semaine voulue : c'est le serveur qui remonte au lundi, l'app n'a pas à
  /// savoir où commence une semaine.
  Future<SleepWeek> week({DateTime? anyDayOfWeek}) async {
    final res = await _dio.get(
      ApiConstants.sleepWeek,
      queryParameters: {
        'start': ?(anyDayOfWeek == null ? null : formatIsoDate(anyDayOfWeek)),
      },
    );
    return SleepWeek.fromJson(res.data as Map<String, dynamic>);
  }

  /// Supprime une nuit (correction d'une saisie erronée).
  Future<void> delete(String id) async {
    await _dio.delete('${ApiConstants.sleep}/$id');
  }
}
