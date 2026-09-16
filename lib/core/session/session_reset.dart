import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coaching/presentation/providers/ai_coach_provider.dart';
import '../../features/coaching/presentation/providers/coach_application_provider.dart';
import '../../features/coaching/presentation/providers/coaching_provider.dart';
import '../../features/nutrition/presentation/providers/food_search_provider.dart';
import '../../features/nutrition/presentation/providers/nutrition_provider.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/programs/presentation/providers/ai_program_provider.dart';
import '../../features/programs/presentation/providers/program_provider.dart';
import '../../features/sleep/presentation/providers/sleep_provider.dart';
import '../../features/workout/presentation/providers/active_session_provider.dart';
import '../../features/workout/presentation/providers/exercise_favorites_provider.dart';
import '../../features/workout/presentation/providers/recent_exercises_provider.dart';
import '../../features/workout/presentation/providers/workout_history_provider.dart';
import '../../features/workout/presentation/providers/workout_provider.dart';

/// Vide **tout ce qui appartient à un adhérent** de la mémoire de l'app.
///
/// ## Le problème que ça règle
///
/// Le `ProviderScope` vit aussi longtemps que le processus, pas aussi
/// longtemps qu'une session. Un provider chargé sous le compte A garde donc sa
/// valeur quand B se connecte sur le même appareil : les écrans affichent les
/// données de A jusqu'à ce qu'un rechargement les remplace — et certains ne
/// rechargent jamais d'eux-mêmes.
///
/// Le symptôme est passé inaperçu longtemps parce qu'il est **silencieux** :
/// rien ne plante, les chiffres sont simplement ceux de quelqu'un d'autre.
/// C'est le sommeil qui l'a révélé, parce qu'il est la seule fonctionnalité
/// avec une porte « une fois par jour » : le pop-up ne s'ouvrait plus pour le
/// nouveau compte, puisque le `loggedToday` du compte précédent disait déjà
/// « c'est fait ». Mais le profil, la nutrition, les programmes, le coaching et
/// l'historique de séances avaient exactement le même défaut.
///
/// Ce n'est pas qu'un bug d'affichage : montrer le poids, les repas ou les
/// nuits de quelqu'un d'autre est une fuite de données entre comptes d'un même
/// appareil.
///
/// ## Pourquoi un fichier à part
///
/// Il doit connaître **tous** les providers d'adhérent, ce qui en fait le seul
/// endroit de l'application à dépendre de toutes les features. Mettre ces
/// imports dans `auth_provider` aurait fait dépendre l'authentification de la
/// nutrition, du sommeil et du coaching — et rendu tout test d'auth
/// impossible à isoler. Ici, `auth_provider` n'importe que ce fichier.
///
/// ## Ce qui n'est PAS remis à zéro
///
/// - `themeModeProvider` — une préférence d'affichage, portée par l'appareil ;
/// - `aiCoachAvailableProvider` / `aiProgramAvailableProvider` — ils décrivent
///   la **configuration du serveur** (une clé Gemini existe-t-elle ?), pas
///   l'adhérent. Les invalider relancerait deux appels réseau pour obtenir la
///   même réponse ;
/// - les providers de type `Provider` qui ne font qu'exposer un client API :
///   ils ne portent aucune donnée.
///
/// ## Quand l'appeler
///
/// À la **déconnexion**, avant de remettre l'état d'authentification à zéro.
/// Pas à la connexion : à ce moment-là, les écrans se reconstruisent déjà et
/// invalider en pleine navigation ferait clignoter l'app.
void resetUserScopedProviders(Ref ref) {
  // Profil et mesures
  ref.invalidate(profileProvider);

  // Sommeil — l'état du jour ET la semaine affichée.
  ref.invalidate(sleepStatusProvider);
  ref.invalidate(sleepWeekProvider);

  // Nutrition : le journal du jour et l'état de recherche d'aliments.
  ref.invalidate(nutritionProvider);
  ref.invalidate(foodSearchProvider);

  // Programmes. `aiCtaDismissedProvider` en fait partie : la bande d'annonce
  // a été masquée par le compte précédent, le nouveau doit la découvrir.
  ref.invalidate(programsProvider);
  ref.invalidate(aiCtaDismissedProvider);

  // Entraînement : catalogue filtré, historique, séance en cours.
  ref.invalidate(workoutProvider);
  ref.invalidate(workoutHistoryProvider);
  ref.invalidate(activeSessionProvider);

  // Favoris d'exercices : ils appartiennent au compte, pas à l'appareil.
  ref.invalidate(exerciseFavoritesProvider);

  // Exercices récemment consultés. Stockés sur l'appareil : invalider le
  // provider ne suffit pas, il faut aussi effacer la trace sur le disque —
  // sinon le compte suivant hériterait de l'historique du précédent.
  ref.read(recentExerciseIdsProvider.notifier).clear();

  // Coaching : annuaire, relations, tableau de bord coach, profil pro.
  ref.invalidate(coachDirectoryProvider);
  ref.invalidate(myRelationshipsProvider);
  ref.invalidate(coachRelationshipsProvider);
  ref.invalidate(coachDashboardProvider);
  ref.invalidate(myCoachProfileProvider);

  // ⚠️ La candidature coach — celle-ci ne se contente PAS d'afficher des
  // données périmées, elle commande l'accès à tout l'espace coach.
  //
  // Son oubli a produit un bug réel : un coach soumet son dossier (le provider
  // met `PENDING` en cache), l'administration le refuse, le coach se
  // reconnecte — et l'application lui montre toujours « dossier en cours
  // d'examen, gelé ». Or c'est précisément l'état où AUCUNE modification n'est
  // permise : il se retrouvait sans aucun moyen de corriger ni de renvoyer,
  // alors que le serveur, lui, l'y autorisait parfaitement.
  //
  // Un statut décidé par quelqu'un d'autre ne doit jamais survivre à une
  // session dans un cache client.
  ref.invalidate(coachApplicationProvider);

  // Le fil du coach IA — une conversation privée, à ne surtout pas laisser
  // à l'écran pour le compte suivant.
  ref.invalidate(aiCoachProvider);
}
