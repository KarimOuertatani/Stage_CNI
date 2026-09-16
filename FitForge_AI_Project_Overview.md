# FitForge AI — Vue d'ensemble du projet

> Document de référence pour un agent IA de développement. Décrit ce qu'est le projet, ses features, sa stack et son état actuel. Le code existe déjà — ce document sert à donner le contexte complet avant toute intervention (correction de bugs, refonte UI/UX).

---

## 1. Qu'est-ce que FitForge AI

Super-app mobile de coaching sportif (musculation) pensée pour le marché tunisien. Elle réunit dans une seule application ce qu'un pratiquant de musculation répartit aujourd'hui entre plusieurs outils : planification d'entraînement, suivi nutritionnel, coaching humain, communauté sociale, et suivi de progression — piloté par l'IA à chaque étape.

**Positionnement :** pas "l'app la plus innovante au monde" (chaque brique existe déjà ailleurs — MyFitnessPal, Fitbod, Hevy, SensAI), mais "la première super-app fitness pensée pour la Tunisie" : langue française, paiement local (Konnect/Flouci), coachs et salles de sport tunisiens.

**Porteur du projet :** Mohamed Karim Ouertatani, étudiant ingénieur ESPRIT (Tunis).

---

## 2. Stack technique

| Côté | Techno |
|---|---|
| Mobile | Flutter 3.44.4 / Dart 3.12.2 |
| State management | Riverpod |
| Navigation | go_router |
| HTTP client | Dio |
| Backend | Spring Boot 4.1.0 / Java 21 (monolithe modulaire) |
| Couche IA | FastAPI + Claude API + RAG (pgvector) |
| Base de données | PostgreSQL + pgvector |
| Visualisation 3D | Modèle GLB préparé sous Blender, package Flutter `interactive_3d` |

---

## 3. État actuel du projet

Le projet est **déjà développé** en grande partie (pas un projet à démarrer de zéro). Les composants suivants existent déjà en code :

- **`Body2DWidget`** — silhouette 2D du corps, coloration par groupe musculaire selon l'intensité de travail récente, implémenté via `CustomPainter`.
- **`Body3DWidget`** — modèle 3D rotatable au toucher, basé sur `assets/models/fitforge_body.glb` : une planche anatomique de **464 muscles**, chacun étant une entité distincte avec son propre matériau, ce qui permet de colorer un muscle précis au runtime. Le rattachement aux 6 groupes de l'app vit dans `muscle_catalog_3d.dart` (généré par `scripts/gen_muscle_catalog_3d.py`).
- Écrans principaux d'entraînement, nutrition, progression, profil et navigation globale (bottom nav / go_router) déjà en place.

**Ce qu'il reste à faire maintenant :** corriger les erreurs/bugs restants, et surtout **refondre entièrement le design et l'UI/UX** pour atteindre un niveau premium — en particulier sur la partie visualisation corporelle 2D/3D, qui est la fonctionnalité signature du produit.

---

## 4. Modules et features du produit

### 4.1 — Socle (déjà implémenté, cœur du produit)

| Module | Description | Pourquoi c'est important |
|---|---|---|
| Entraînement & programmes | Création/logging de séances, séries, répétitions, charges, bibliothèque d'exercices cherchable par groupe musculaire/équipement | Cœur du produit, source de toutes les données |
| Nutrition | Saisie de repas (manuelle), calcul calories/macros selon l'objectif (masse, perte, maintien) | Pèse autant que l'entraînement dans les résultats |
| Progression + corps | Statistiques de performance, visualisation du corps colorée par groupe musculaire travaillé | Moteur de rétention hebdomadaire — voir sa progression fait revenir l'utilisateur |
| Coaching privé | Chat coach-client, programmes et plans alimentaires personnalisés assignés au client | Levier de monétisation le plus solide |
| Communauté | Fil social de partage de progression | Acquisition virale, coût marketing quasi nul |

### 4.2 — Différenciation IA (à venir / partiellement présent)

| Feature | Ce que ça fait |
|---|---|
| Analyse de forme (caméra) | ML Kit Pose Detection, 33 points clés en temps réel, traitement 100% on-device, détecte les écarts de technique |
| Reconnaissance de repas photo | API vision (LogMeal/FatSecret), estimation calories/macros depuis une photo d'assiette (marge d'erreur ~15-25%) |
| Périodisation adaptative | Charges/volumes recalculés selon performances loggées + RPE déclaré |
| Score de récupération | Formule : ratio charge aiguë/chronique (7j vs moyenne 4 semaines) + sommeil + FC repos (HealthKit/Health Connect) |
| Avatar 3D "futur moi" | Projection visuelle de l'évolution physique attendue à 3-6 mois |
| Marketplace de coachs | Coachs vérifiés vendent programmes/templates, avec avis et notation |
| Matching partenaires | Mise en relation par niveau/objectifs/localisation/horaires |

---

## 5. Modèle de données (entités principales)

```
User(id, email, fullName, phone, dateOfBirth, gender, role[CLIENT/COACH/ADMIN], profilePhotoUrl)
CoachProfile(id, userId, bio, specialties[], certificationUrl, verified, ratingAvg, hourlyRate)
Exercise(id, name, muscleGroup, equipment, difficultyLevel, instructions, videoUrl)
WorkoutProgram(id, ownerId, title, description, goal, durationWeeks, isTemplate, isPublic, price)
WorkoutSession(id, programId, dayOfWeek, title, notes, orderIndex)
SessionExercise(id, sessionId, exerciseId, targetSets, targetReps, targetWeight, restSeconds, orderIndex)
WorkoutLog(id, userId, sessionId, date, durationMinutes, notes, rpe)
SetLog(id, workoutLogId, exerciseId, setNumber, reps, weight, completed)
NutritionEntry(id, userId, date, mealType, foodName, calories, proteinG, carbsG, fatG, photoUrl, source[MANUAL/PHOTO_AI])
BodyProgress(id, userId, date, weightKg, bodyFatPct, muscleGroupVolumes[JSON], photoUrl)
RecoveryScore(id, userId, date, sleepHours, restingHeartRate, acuteChronicLoadRatio, score, recommendation)
CoachClientRelation(id, coachId, clientId, status, startedAt)
ChatMessage(id, conversationId, senderId, content, sentAt, read)
Post(id, userId, content, imageUrl, likesCount, commentsCount, createdAt)
MarketplaceListing(id, programId, price, ratingAvg, salesCount, publishedAt)
Payment(id, userId, amount, currency, provider[KONNECT/FLOUCI/IAP], status)
Subscription(id, userId, plan[FREE/PREMIUM], status, startDate, endDate, autoRenew)
TrainingPartnerMatch(id, userAId, userBId, status, matchedAt)
```

`muscleGroup` doit toujours correspondre aux 6 groupes pilotant `Body2DWidget`/`Body3DWidget` : `Pectoraux`, `Dos`, `Épaules`, `Bras`, `Abdominaux`, `Jambes`.

---

## 6. Analyse concurrentielle (pour situer le niveau d'exigence attendu)

| App | Points forts | Ce qui leur manque vs FitForge AI |
|---|---|---|
| MyFitnessPal | +200M utilisateurs, base alimentaire immense | Musculation limitée, pas de coach, pas de 3D |
| Fitbod | IA génération de programme, suivi de force détaillé | Pas de nutrition, pas de récupération, pas de coach humain |
| Hevy | Logging rapide, couche sociale, IA récente | Pas de nutrition, pas de caméra, pas de marketplace |
| Strong | Interface très rapide, export de données | Aucune IA, aucune nutrition, aucune communauté |
| SensAI | Coach LLM + lecture HRV/sommeil (wearables) | Pas localisé Tunisie/Afrique du Nord |

Aucun acteur ne combine tout + un ancrage local. FitForge AI doit donc se démarquer par l'**intégration** et par un **design nettement au-dessus** du standard des apps fitness génériques — c'est là que se joue la différenciation, pas sur une fonctionnalité isolée.

---

## 7. Priorités de refonte design (contexte pour la suite du travail)

- La visualisation corporelle (2D et surtout 3D) est **la fonctionnalité signature** — c'est le moteur de rétention hebdomadaire, elle doit être visuellement spectaculaire.
- Le logging de séance est **l'écran le plus utilisé** — friction minimale, feedback immédiat.
- La saisie nutrition est **le point d'abandon n°1** connu sur ce type d'app — doit être la plus rapide possible.
- Le design global doit donner une impression d'app premium/native, pas de template générique de fitness app.

---

*Document de référence basé sur le dossier de projet complet FitForge AI (version 3, juillet 2026) et l'état actuel du code Flutter.*
