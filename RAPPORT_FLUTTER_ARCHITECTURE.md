# Rapport Flutter Architecture

## Arborescence finale réelle

```text
fitforge_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart
│   │   ├── network/
│   │   │   ├── api_exception.dart
│   │   │   └── dio_client.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   └── app_theme.dart
│   │   └── widgets/
│   │       ├── app_loader.dart
│   │       ├── app_text_field.dart
│   │       └── primary_button.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_api.dart
│   │   │   │   └── user_model.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── auth_provider.dart
│   │   │       └── screens/
│   │   │           ├── login_screen.dart
│   │   │           └── signup_screen.dart
│   │   ├── coaching/
│   │   │   ├── data/
│   │   │   │   ├── coach_model.dart
│   │   │   │   └── coaching_api.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── coaching_provider.dart
│   │   │       ├── screens/
│   │   │       │   └── coach_list_screen.dart
│   │   │       └── widgets/
│   │   │           └── coach_card.dart
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── home_screen.dart
│   │   │       └── widgets/
│   │   │           ├── home_greeting_header.dart
│   │   │           └── quick_stats_card.dart
│   │   ├── nutrition/
│   │   │   ├── data/
│   │   │   │   ├── meal_model.dart
│   │   │   │   └── nutrition_api.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── nutrition_provider.dart
│   │   │       ├── screens/
│   │   │       │   └── meals_screen.dart
│   │   │       └── widgets/
│   │   │           └── meal_card.dart
│   │   └── workout/
│   │       ├── data/
│   │       │   ├── workout_model.dart
│   │       │   └── workout_api.dart
│   │       └── presentation/
│   │           ├── providers/
│   │           │   └── workout_provider.dart
│   │           ├── screens/
│   │           │   ├── body_progress_screen.dart
│   │           │   └── exercise_list_screen.dart
│   │           └── widgets/
│   │               ├── body_2d_widget.dart
│   │               └── exercise_card.dart
│   └── shared/
│       └── navigation/
│           └── main_shell.dart
├── pubspec.yaml
└── FLUTTER_SETUP_ET_ECRANS_INITIAUX.md
```

## Fichiers créés ou présents et rôle

- [lib/main.dart](lib/main.dart): point d’entrée Flutter avec `ProviderScope` et `MaterialApp.router`.
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart): routes `go_router`, redirection auth et `ShellRoute`.
- [lib/shared/navigation/main_shell.dart](lib/shared/navigation/main_shell.dart): navigation inférieure Accueil / Entraînement / Coaching / Nutrition.
- [lib/core/theme/app_colors.dart](lib/core/theme/app_colors.dart): palette sombre premium et couleurs d’intensité musculaire.
- [lib/core/theme/app_text_styles.dart](lib/core/theme/app_text_styles.dart): hiérarchie typographique réutilisable.
- [lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart): configuration globale du thème.
- [lib/core/network/dio_client.dart](lib/core/network/dio_client.dart): client HTTP centralisé.
- [lib/core/network/api_exception.dart](lib/core/network/api_exception.dart): exceptions réseau applicatives.
- [lib/core/constants/api_constants.dart](lib/core/constants/api_constants.dart): constantes d’API.
- [lib/core/widgets/primary_button.dart](lib/core/widgets/primary_button.dart): bouton principal réutilisable.
- [lib/core/widgets/app_loader.dart](lib/core/widgets/app_loader.dart): indicateur de chargement.
- [lib/core/widgets/app_text_field.dart](lib/core/widgets/app_text_field.dart): champ de texte stylé.
- [lib/features/auth/data/user_model.dart](lib/features/auth/data/user_model.dart): modèle utilisateur mocké.
- [lib/features/auth/data/auth_api.dart](lib/features/auth/data/auth_api.dart): API auth simulée.
- [lib/features/auth/presentation/providers/auth_provider.dart](lib/features/auth/presentation/providers/auth_provider.dart): état d’authentification Riverpod.
- [lib/features/auth/presentation/screens/login_screen.dart](lib/features/auth/presentation/screens/login_screen.dart): écran de connexion.
- [lib/features/auth/presentation/screens/signup_screen.dart](lib/features/auth/presentation/screens/signup_screen.dart): écran d’inscription.
- [lib/features/home/presentation/screens/home_screen.dart](lib/features/home/presentation/screens/home_screen.dart): tableau de bord principal.
- [lib/features/home/presentation/widgets/home_greeting_header.dart](lib/features/home/presentation/widgets/home_greeting_header.dart): en-tête de bienvenue.
- [lib/features/home/presentation/widgets/quick_stats_card.dart](lib/features/home/presentation/widgets/quick_stats_card.dart): cartes de statistiques rapides.
- [lib/features/workout/data/workout_model.dart](lib/features/workout/data/workout_model.dart): exercices mockés et intensités musculaires.
- [lib/features/workout/data/workout_api.dart](lib/features/workout/data/workout_api.dart): API workout simulée.
- [lib/features/workout/presentation/providers/workout_provider.dart](lib/features/workout/presentation/providers/workout_provider.dart): données d’entraînement exposées à l’UI.
- [lib/features/workout/presentation/screens/exercise_list_screen.dart](lib/features/workout/presentation/screens/exercise_list_screen.dart): liste filtrable des exercices.
- [lib/features/workout/presentation/screens/body_progress_screen.dart](lib/features/workout/presentation/screens/body_progress_screen.dart): vue de progression corporelle.
- [lib/features/workout/presentation/widgets/exercise_card.dart](lib/features/workout/presentation/widgets/exercise_card.dart): carte exercice.
- [lib/features/workout/presentation/widgets/body_2d_widget.dart](lib/features/workout/presentation/widgets/body_2d_widget.dart): silhouette 2D animée.
- [lib/features/coaching/data/coach_model.dart](lib/features/coaching/data/coach_model.dart): modèle coach mocké.
- [lib/features/coaching/data/coaching_api.dart](lib/features/coaching/data/coaching_api.dart): API coaching simulée.
- [lib/features/coaching/presentation/providers/coaching_provider.dart](lib/features/coaching/presentation/providers/coaching_provider.dart): état des coachs.
- [lib/features/coaching/presentation/screens/coach_list_screen.dart](lib/features/coaching/presentation/screens/coach_list_screen.dart): liste des coachs.
- [lib/features/coaching/presentation/widgets/coach_card.dart](lib/features/coaching/presentation/widgets/coach_card.dart): carte coach.
- [lib/features/nutrition/data/meal_model.dart](lib/features/nutrition/data/meal_model.dart): repas mockés et objectifs calorie.
- [lib/features/nutrition/data/nutrition_api.dart](lib/features/nutrition/data/nutrition_api.dart): API nutrition simulée.
- [lib/features/nutrition/presentation/providers/nutrition_provider.dart](lib/features/nutrition/presentation/providers/nutrition_provider.dart): données nutritionnelles exposées.
- [lib/features/nutrition/presentation/screens/meals_screen.dart](lib/features/nutrition/presentation/screens/meals_screen.dart): écran nutrition.
- [lib/features/nutrition/presentation/widgets/meal_card.dart](lib/features/nutrition/presentation/widgets/meal_card.dart): carte repas.

## Packages ajoutés à pubspec.yaml

- `flutter_riverpod`
- `go_router`
- `dio`
- `flutter_secure_storage`
- `flutter_animate`

## Ce qui reste à faire

- Remplacer les données mockées par de vrais appels API quand le backend sera prêt.
- Brancher une vraie persistance JWT via `flutter_secure_storage` dans le flux d’authentification.
- Relier les écrans aux endpoints réels pour les coachs, les repas et les programmes.
- Ajouter une couche de chargement initiale plus explicite si l’on veut éviter tout flash de navigation au démarrage.