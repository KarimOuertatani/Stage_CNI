import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/sleep_api.dart';
import '../../data/sleep_models.dart';
import '../../data/sleep_prompt_store.dart';

final sleepApiProvider = Provider<SleepApi>(
  (ref) => SleepApi(ref.read(dioClientProvider)),
);

/// L'état du sommeil pour aujourd'hui : nuit déjà saisie ? dernière nuit connue ?
///
/// Alimente **deux choses à la fois** — la tuile de l'accueil et la décision
/// d'ouvrir le pop-up. C'est pour ça que le backend les renvoie ensemble : les
/// deux sont demandées au même instant, au lancement.
class SleepStatusNotifier extends AsyncNotifier<SleepStatus> {
  @override
  Future<SleepStatus> build() {
    return ref.read(sleepApiProvider).status();
  }

  /// Enregistre une nuit et met l'état à jour sans second aller-retour.
  ///
  /// Renvoie l'entrée créée : le pop-up en a besoin **immédiatement** pour
  /// afficher son conseil, et repasser par l'état asynchrone ferait clignoter
  /// l'écran entre l'enregistrement et l'affichage.
  Future<SleepEntry> save({
    required TimeOfDay bedTime,
    required TimeOfDay wakeTime,
    DateTime? date,
  }) async {
    final entry = await ref
        .read(sleepApiProvider)
        .save(bedTime: bedTime, wakeTime: wakeTime, date: date);

    final isToday = date == null || _isSameDay(date, DateTime.now());
    state = AsyncData(
      SleepStatus(
        loggedToday: isToday || (state.value?.loggedToday ?? false),
        latest: entry,
      ),
    );

    // Le backend recalcule la moyenne de sommeil du profil à chaque saisie. On
    // rafraîchit le profil pour que la valeur affichée ailleurs (fiche profil,
    // briefing du coach IA) reflète la nuit qu'on vient d'entrer.
    //
    // Sans `await` et avec l'erreur avalée : ce rafraîchissement ne doit pas
    // retarder l'affichage du conseil, et s'il échoue la nuit est enregistrée
    // quand même — c'est elle qui compte.
    ref.read(profileProvider.notifier).load().catchError((_) {});

    return entry;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(sleepApiProvider).status());
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

final sleepStatusProvider =
    AsyncNotifierProvider<SleepStatusNotifier, SleepStatus>(
      SleepStatusNotifier.new,
    );

/// La semaine affichée dans l'écran Sommeil.
///
/// L'état est la **date de référence** (n'importe quel jour de la semaine
/// voulue) et non la semaine elle-même : c'est le serveur qui remonte au lundi.
/// L'app n'a donc jamais à savoir où commence une semaine, ni à gérer les
/// changements de mois ou d'année en naviguant.
class SleepWeekNotifier extends AsyncNotifier<SleepWeek> {
  DateTime _reference = DateTime.now();

  @override
  Future<SleepWeek> build() {
    return ref.read(sleepApiProvider).week(anyDayOfWeek: _reference);
  }

  Future<void> _load() async {
    // Pas de bascule vers AsyncLoading : la semaine précédente reste affichée
    // pendant le chargement de la suivante. Vider l'histogramme entre deux
    // semaines ferait clignoter tout l'écran à chaque coup de flèche, pour un
    // appel qui dure quelques dizaines de millisecondes.
    state = await AsyncValue.guard(
      () => ref.read(sleepApiProvider).week(anyDayOfWeek: _reference),
    );
  }

  Future<void> previousWeek() {
    _reference = _reference.subtract(const Duration(days: 7));
    return _load();
  }

  /// Avance d'une semaine. Sans effet au-delà de la semaine en cours : il n'y a
  /// rien à voir dans le futur, et un écran vide y ressemblerait à une panne.
  Future<void> nextWeek() {
    final next = _reference.add(const Duration(days: 7));
    if (next.isAfter(DateTime.now())) {
      // On autorise quand même le retour vers la semaine courante depuis une
      // semaine passée : c'est le cas où `next` dépasse aujourd'hui mais où la
      // semaine visée est bien la semaine en cours.
      final currentWeek = state.value?.currentWeek ?? false;
      if (currentWeek) return Future<void>.value();
    }
    _reference = next;
    return _load();
  }

  Future<void> reload() => _load();
}

final sleepWeekProvider = AsyncNotifierProvider<SleepWeekNotifier, SleepWeek>(
  SleepWeekNotifier.new,
);

/// Faut-il ouvrir le pop-up de saisie maintenant ?
///
/// Trois conditions, et il faut les trois :
///  1. le statut est chargé (sinon on ne sait rien) ;
///  2. la nuit du jour n'est pas déjà enregistrée (côté **serveur**) ;
///  3. on n'a pas déjà posé la question aujourd'hui (côté **appareil**).
///
/// La troisième est celle qu'on oublie : le serveur ignore qu'un adhérent a
/// appuyé sur « Plus tard ». Sans elle, le pop-up reviendrait à chaque retour
/// sur l'accueil.
Future<bool> shouldPromptForSleep(SleepStatus? status) async {
  if (status == null || status.loggedToday) return false;
  return !await SleepPromptStore.instance.askedToday();
}
