# FitForge AI — Mobile Flutter — Mise en place de l'architecture + Première version des écrans

## Contexte

Tu es un agent IA chargé de démarrer le projet Flutter **FitForge AI**, une application mobile de coaching sportif (musculation, nutrition, coaching humain, IA). Ce document contient **toutes les instructions** pour :

1. Mettre en place l'architecture complète du projet (dossiers)
2. Générer une première version des écrans essentiels
3. Produire un rapport final de ce qui a été fait

Suis ces instructions **dans l'ordre**, section par section.

---

## 1. Stack technique imposée

- **Flutter 3.44.4** (stable), **Dart 3.12.2**
- **Riverpod** (`flutter_riverpod`) pour la gestion d'état
- **go_router** pour la navigation
- **Dio** pour les appels HTTP (même si le backend n'est pas encore branché, prépare la structure)
- **flutter_secure_storage** pour le token JWT
- Pour l'animation et le beau visuel : tu peux utiliser `flutter_animate`, les animations natives Flutter (`AnimationController`, `Hero`, `AnimatedContainer`, `TweenAnimationBuilder`), et `flutter_svg` si besoin d'icônes vectorielles personnalisées

Installe ce qui est nécessaire via `flutter pub add`.

---

## 2. Principe d'architecture : feature-first

Organisation **par fonctionnalité métier**, jamais par type de fichier au niveau racine. Chaque feature contient :
- `data/` → modèles + appels API (même si mockés pour l'instant)
- `presentation/` → écrans, widgets, providers Riverpod

Pas de dossier `domain/` pour cette première version — on le rajoutera plus tard si nécessaire.

---

## 3. Arborescence complète à créer

```
fitforge_app/
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── network/
│   │   │   ├── dio_client.dart
│   │   │   └── api_exception.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart
│   │   │   └── app_text_styles.dart
│   │   ├── constants/
│   │   │   └── api_constants.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── widgets/
│   │       ├── primary_button.dart
│   │       ├── app_loader.dart
│   │       └── app_text_field.dart
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_api.dart
│   │   │   │   └── user_model.dart
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   ├── login_screen.dart
│   │   │       │   └── signup_screen.dart
│   │   │       └── providers/
│   │   │           └── auth_provider.dart
│   │   │
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── home_screen.dart
│   │   │       └── widgets/
│   │   │           ├── home_greeting_header.dart
│   │   │           └── quick_stats_card.dart
│   │   │
│   │   ├── workout/
│   │   │   ├── data/
│   │   │   │   ├── workout_api.dart
│   │   │   │   └── workout_model.dart
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   ├── exercise_list_screen.dart
│   │   │       │   └── body_progress_screen.dart
│   │   │       ├── widgets/
│   │   │       │   ├── exercise_card.dart
│   │   │       │   └── body_2d_widget.dart
│   │   │       └── providers/
│   │   │           └── workout_provider.dart
│   │   │
│   │   ├── coaching/
│   │   │   ├── data/
│   │   │   │   ├── coaching_api.dart
│   │   │   │   └── coach_model.dart
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── coach_list_screen.dart
│   │   │       ├── widgets/
│   │   │       │   └── coach_card.dart
│   │   │       └── providers/
│   │   │           └── coaching_provider.dart
│   │   │
│   │   └── nutrition/
│   │       ├── data/
│   │       │   ├── nutrition_api.dart
│   │       │   └── meal_model.dart
│   │       └── presentation/
│   │           ├── screens/
│   │           │   └── meals_screen.dart
│   │           ├── widgets/
│   │           │   └── meal_card.dart
│   │           └── providers/
│   │               └── nutrition_provider.dart
│   │
│   └── shared/
│       └── navigation/
│           └── main_shell.dart        ← bottom navigation bar qui relie home/workout/coaching/nutrition
```

**Crée tous ces dossiers et fichiers dès maintenant**, même vides au départ, puis remplis-les selon la section 4.

---

## 4. Écrans à générer pour cette première version

Génère les écrans suivants, dans cet ordre, avec des **données mockées** (pas encore de vrai backend branché — utilise des listes statiques ou générées en local dans chaque provider, pour que l'app soit navigable et démontrable dès maintenant) :

### 4.1 — `login_screen.dart` et `signup_screen.dart`
Écrans d'authentification. Champs email/mot de passe, bouton principal, lien vers l'autre écran ("Pas de compte ? S'inscrire"). Validation de formulaire basique (email valide, mot de passe non vide).

### 4.2 — `home_screen.dart` (l'accueil)
Écran principal après connexion : message de bienvenue personnalisé, résumé rapide (séances de la semaine, calories du jour, prochaine séance de coaching), accès rapide vers les autres sections via des cartes visuelles.

### 4.3 — `exercise_list_screen.dart`
Liste des exercices/programmes disponibles, avec filtre par groupe musculaire. Chaque exercice dans une `exercise_card.dart` avec image/icône, nom, groupe musculaire, niveau de difficulté.

### 4.4 — `body_progress_screen.dart` avec `body_2d_widget.dart`
**Le corps en 2D coloré par groupe musculaire selon l'intensité de travail récente** (comme décrit dans le dossier projet) — une silhouette humaine simplifiée (peut être en `CustomPainter` ou SVG modifiable) où chaque zone (pectoraux, dos, jambes, bras, épaules...) change de couleur/intensité selon les données mockées d'entraînement récent.

### 4.5 — `coach_list_screen.dart`
Liste des coachs disponibles avec `coach_card.dart` : photo, nom, spécialité, note, bouton "Contacter" ou "Voir le profil".

### 4.6 — `meals_screen.dart`
Suivi nutritionnel : repas du jour listés par `meal_card.dart` (petit-déjeuner, déjeuner, dîner, collations) avec calories/macros, et un résumé visuel de l'objectif calorique du jour (barre de progression ou anneau).

### 4.7 — `main_shell.dart`
Structure de navigation principale avec bottom navigation bar reliant : Accueil / Entraînement / Coaching / Nutrition. Utilise `go_router` avec des routes imbriquées (`ShellRoute`).

---

## 5. Exigence de qualité visuelle — non négociable

**L'application doit être extrêmement belle, moderne, animée et soignée.** Ce n'est pas une exigence secondaire :

- Utilise une palette de couleurs cohérente et premium (définie dans `app_colors.dart`), pas les couleurs Material par défaut.
- Ajoute des **animations fluides** partout où c'est pertinent : transitions entre écrans, apparition des cartes (fade/slide au chargement), retour visuel au tap (scale/ripple personnalisé), la coloration du corps 2D doit s'animer progressivement plutôt qu'apparaître brutalement.
- Utilise des **coins arrondis, ombres douces, dégradés subtils** plutôt que des blocs plats.
- Typographie soignée avec hiérarchie claire (titres, sous-titres, corps de texte) définie une fois dans `app_text_styles.dart` et réutilisée partout — jamais de style de texte codé en dur dans un écran.
- Chaque écran doit donner l'impression d'une app premium prête à être montrée à des investisseurs ou publiée sur les stores — pas un prototype gris.

Si tu dois choisir entre "aller plus vite" et "faire plus beau", **priorise le beau** pour cette première version.

---

## 6. Ce que l'agent doit faire, dans l'ordre

1. Créer l'arborescence complète (section 3).
2. Mettre en place `core/theme/` (couleurs, typographie) et `core/router/app_router.dart` avant tout écran.
3. Générer `main_shell.dart` avec la navigation par onglets.
4. Générer les écrans dans l'ordre de la section 4, avec données mockées et animations.
5. Vérifier que l'app compile et se lance (`flutter run`) sans erreur avant de conclure.
6. **Générer un second fichier**, nommé `RAPPORT_FLUTTER_ARCHITECTURE.md`, à la racine du projet, qui liste :
   - L'arborescence finale réelle du projet (tous les dossiers et fichiers créés)
   - Pour **chaque fichier créé**, une courte description de ce qu'il contient et fait
   - Les packages ajoutés à `pubspec.yaml`
   - Ce qui reste à faire / à connecter plus tard (ex: "les données sont mockées, à remplacer par de vrais appels API une fois le backend prêt")

**Ne pas** : ajouter de fonctionnalités non listées ici (marketplace, matching, avatar 3D...), utiliser `setState` pour la logique métier, mettre plusieurs features dans un seul fichier API, ou livrer un écran visuellement basique/non animé — reviens vérifier la section 5 avant de considérer un écran terminé.
