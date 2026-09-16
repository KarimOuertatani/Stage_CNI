# FitForge AI — Guide de création du Backend (Partie 1 : Adhérent)

---

## 🎯 MISSION POUR L'AGENT IA — À LIRE EN PREMIER

> **Tu es un développeur backend senior Spring Boot.** Ta mission est de construire, de A à Z et proprement, le backend de la Partie 1 (adhérent) de l'application FitForge AI, en suivant ce document comme référence unique. Tu dois tout faire toi-même, sans laisser d'étapes « à compléter par l'utilisateur ».

### Ce que tu dois livrer, dans cet ordre exact

1. **La base de données (Docker).** Crée le fichier `docker-compose.yml` (PostgreSQL 16, volume nommé, healthcheck), donne la commande `docker compose up -d`, puis **vérifie explicitement que la base tourne et est saine** (`docker compose ps` doit montrer le statut `healthy`, et une requête `SELECT version();` doit répondre). Ne passe pas à la suite tant que la base n'est pas confirmée opérationnelle.

2. **La configuration.** Crée `application.yml` avec la connexion à cette base. Les identifiants doivent correspondre exactement au `docker-compose.yml`.

3. **Le backend complet**, module par module, dans l'ordre de la section 17 : setup projet → auth (JWT) → profil → mensurations → exercices → programmes/séances → logs d'entraînement → nutrition → score. Après **chaque** module, indique comment le tester dans Swagger avant de continuer.

4. **La vérification finale.** Lance l'application, confirme le message `Started ... in X seconds`, confirme que les tables sont créées, et donne l'URL Swagger (`/swagger-ui.html`) pour tester les API.

### Règles de qualité NON négociables

- **Tout le code doit être commenté** avec des commentaires explicatifs clairs (en français) : chaque classe explique son rôle, chaque méthode non triviale explique ce qu'elle fait et pourquoi, chaque relation JPA et chaque règle métier (calcul IMC/TDEE/âge/score) est commentée. Le but est qu'un étudiant puisse lire le code et le comprendre sans aide extérieure.
- **Architecture en couches** stricte : `Controller → Service → Repository → Entity`. Aucune logique métier dans les controllers.
- **On n'expose jamais une entité JPA** dans l'API : DTO (records) en entrée et en sortie pour chaque endpoint, mapping via MapStruct.
- **IDs en UUID**, relations `LAZY`, timestamps automatiques.
- **Validation** des DTO d'entrée (Jakarta Validation) + **GlobalExceptionHandler** qui renvoie des erreurs JSON propres (404, 400…).
- **Swagger bien fait** : `@Tag`, `@Operation`, `@Schema` avec descriptions et exemples, bouton « Authorize » pour le JWT. L'API doit être directement testable et prête à brancher sur Flutter.
- **Code qui compile** : on cible **Spring Boot 4.1.0 (Spring Framework 7, Spring Security 6.x, nouvelle syntaxe lambda de la config Security, imports Jakarta)**. Si un doute sur une API récente, utilise la syntaxe Spring Boot 4 / Jakarta, pas l'ancienne Spring Boot 2/3 javax.

### Ordre de travail imposé

Procède **un module à la fois**. Commence par le setup (`docker-compose.yml`, `pom.xml`, `application.yml`) et la vérification de la base. Puis enchaîne les modules. À la fin de chaque module, résume ce qui a été créé et comment le tester, puis passe au suivant. Le détail complet de chaque entité, DTO, endpoint et règle métier est fourni dans les sections ci-dessous.

---

> Guide complet et prêt à suivre pour monter le backend **Spring Boot** de FitForge AI.
> Objectif : des **API REST propres, documentées (Swagger) et prêtes à brancher sur Flutter**.
> Périmètre de ce document : **l'adhérent (utilisateur pratiquant)** — profil complet, nutrition, entraînement, exercices, score d'entraînement.

---

## Table des matières

1. [Périmètre & principes](#1-périmètre--principes)
2. [Stack technique](#2-stack-technique)
3. [Architecture du projet (couches + packages)](#3-architecture-du-projet)
4. [Initialisation du projet](#4-initialisation-du-projet)
5. [Configuration (`application.yml`)](#5-configuration)
6. [Le modèle de données de la Partie 1](#6-le-modèle-de-données)
7. [Les entités JPA (code)](#7-les-entités-jpa)
8. [Les ENUMs](#8-les-enums)
9. [DTOs & mapping](#9-dtos--mapping)
10. [Repositories](#10-repositories)
11. [Services](#11-services)
12. [Controllers (les API REST)](#12-controllers--les-api-rest)
13. [Sécurité (JWT)](#13-sécurité-jwt)
14. [Swagger / OpenAPI bien fait](#14-swagger--openapi)
15. [Gestion des erreurs](#15-gestion-des-erreurs)
16. [Liste complète des endpoints (à brancher sur Flutter)](#16-liste-complète-des-endpoints)
17. [Ordre de développement conseillé](#17-ordre-de-développement-conseillé)
18. [Le prompt à réutiliser](#18-le-prompt-à-réutiliser)

---

## 1. Périmètre & principes

Cette partie 1 couvre **uniquement l'adhérent** et ce dont il a besoin :

- **Son profil complet** : email, nom, mais surtout ses données physiques et sportives (poids, taille, objectif, rythme de vie, blessures…). Ces infos « corps & sport » sont volontairement **stockées dans une table séparée** (`UserProfile`) pour ne pas surcharger la table `User` d'authentification, et pour pouvoir faire évoluer le profil (mensurations dans le temps) sans toucher au compte.
- **La nutrition** : journal alimentaire (repas, calories, macros).
- **L'entraînement** : programmes, séances, exercices, logs de séries.
- **Le score d'entraînement** : une note calculée qui résume la charge / progression.

**Principes suivis :**

| Principe | Ce que ça veut dire concrètement |
|---|---|
| **Architecture en couches** | `Controller → Service → Repository → Entity`. Jamais de logique métier dans le controller. |
| **DTO partout en entrée/sortie** | On n'expose **jamais** une entité JPA directement dans l'API (sécurité + découplage Flutter). |
| **Séparation compte / profil** | `User` = identité & auth. `UserProfile` = données physiques & sportives. |
| **Historisation** | Le poids et les mensurations sont historisés (`BodyMeasurement`) — on ne les écrase pas. |
| **API REST cohérente** | Noms au pluriel, verbes HTTP corrects, codes de statut justes. |
| **Documentée** | Swagger/OpenAPI généré automatiquement, annoté proprement. |

---

## 2. Stack technique

| Élément | Choix | Version conseillée |
|---|---|---|
| Langage | Java | **21** |
| Framework | Spring Boot | **4.1.0** (dernière stable, sur Spring Framework 7) |
| Build | Maven | 3.9+ |
| Base de données | PostgreSQL | 16 (via Docker) |
| Conteneurisation | Docker + Docker Compose | dernière |
| ORM | Spring Data JPA / Hibernate | inclus |
| Sécurité | Spring Security + JWT | jjwt 0.12.x |
| Doc API | springdoc-openapi (Swagger UI) | **2.8.x** (compatible Spring Boot 4) |
| Mapping DTO | MapStruct | 1.6.x |
| Boilerplate | Lombok | dernière |
| Migrations | Flyway | inclus Spring Boot |
| Validation | Bean Validation (Jakarta) | inclus |

> **Note versions** : Spring Boot 4.1.0 (juin 2026) tourne sur Spring Framework 7, exige **Java 17 minimum** (donc Java 21 est parfait) et va jusqu'à Java 26. Spring Boot n'a **pas** de version « LTS » : chaque version mineure a 12 mois de support. On part sur 4.1.0 car le projet démarre de zéro — autant prendre le plus récent stable et éviter une migration plus tard.

> **Important pour springdoc** : avec Spring Boot 4.x, il faut springdoc-openapi **2.8.x ou plus récent**. Les versions 2.6.x ciblaient Spring Boot 3.x. Vérifie la dernière version compatible sur le repo springdoc si tu as un souci de démarrage.

---

## 3. Architecture du projet

### Structure en couches

```
┌─────────────────────────────────────────────┐
│  CONTROLLER   → reçoit la requête HTTP,       │
│                 valide le DTO d'entrée,       │
│                 renvoie un DTO de sortie      │
├─────────────────────────────────────────────┤
│  SERVICE      → logique métier, transactions, │
│                 calcul du score, règles       │
├─────────────────────────────────────────────┤
│  REPOSITORY   → accès base (Spring Data JPA)  │
├─────────────────────────────────────────────┤
│  ENTITY       → tables mappées (JPA)          │
└─────────────────────────────────────────────┘
        DTO + MAPPER traversent les couches
```

### Arborescence des packages

```
com.fitforge.api
├── FitForgeApplication.java
│
├── config
│   ├── OpenApiConfig.java          # config Swagger
│   ├── SecurityConfig.java         # Spring Security + JWT
│   └── CorsConfig.java             # autoriser Flutter
│
├── security
│   ├── JwtService.java
│   ├── JwtAuthenticationFilter.java
│   └── CustomUserDetailsService.java
│
├── common
│   ├── exception
│   │   ├── ResourceNotFoundException.java
│   │   ├── BusinessException.java
│   │   └── GlobalExceptionHandler.java
│   └── dto
│       └── ApiError.java
│
├── user            # compte + profil + mensurations
│   ├── entity      (User, UserProfile, BodyMeasurement)
│   ├── dto
│   ├── mapper
│   ├── repository
│   ├── service
│   └── controller
│
├── training        # programmes, séances, exercices, logs
│   ├── entity      (Exercise, WorkoutProgram, WorkoutSession,
│   │                SessionExercise, WorkoutLog, SetLog)
│   ├── dto / mapper / repository / service / controller
│
├── nutrition       # journal alimentaire
│   ├── entity      (NutritionEntry)
│   └── dto / mapper / repository / service / controller
│
└── score           # score d'entraînement
    ├── entity      (TrainingScore)
    └── dto / mapper / repository / service / controller
```

> **Pourquoi découper par domaine (user / training / nutrition / score) et pas par couche technique ?**
> Ça reste lisible quand le projet grossit : tout ce qui concerne l'entraînement est au même endroit. C'est l'approche « package by feature ».

---

## 4. Initialisation du projet

Va sur [start.spring.io](https://start.spring.io) et choisis :

| Champ | Valeur |
|---|---|
| Project | **Maven** |
| Language | **Java** |
| Spring Boot | **4.1.0** (pas les SNAPSHOT) |
| Group | `com.fitforge` |
| Artifact | `api` |
| Package name | `com.fitforge.api` |
| Packaging | **Jar** |
| Configuration | **YAML** (important : pas Properties) |
| Java | **21** |

Dépendances à cocher :

- Spring Web
- Spring Data JPA
- PostgreSQL Driver
- Spring Security
- Validation
- Lombok
- Flyway Migration

Ajoute manuellement dans le `pom.xml` :

```xml
<!-- Swagger / OpenAPI (2.8.x pour Spring Boot 4.x) -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.8.5</version>
</dependency>

<!-- JWT -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.6</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>

<!-- MapStruct -->
<dependency>
    <groupId>org.mapstruct</groupId>
    <artifactId>mapstruct</artifactId>
    <version>1.6.3</version>
</dependency>
```

Et dans le plugin `maven-compiler-plugin`, ajoute le processor MapStruct + Lombok :

```xml
<annotationProcessorPaths>
    <path>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>1.18.34</version>
    </path>
    <path>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct-processor</artifactId>
        <version>1.6.3</version>
    </path>
    <path>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok-mapstruct-binding</artifactId>
        <version>0.2.0</version>
    </path>
</annotationProcessorPaths>
```

---

## 5. Configuration

`src/main/resources/application.yml` :

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/fitforge
    username: fitforge
    password: fitforge
  jpa:
    hibernate:
      ddl-auto: validate      # Flyway gère le schéma, pas Hibernate
    properties:
      hibernate:
        format_sql: true
    show-sql: false
  flyway:
    enabled: true
    locations: classpath:db/migration

server:
  port: 8080

# Config JWT maison
app:
  jwt:
    secret: "CHANGE_ME_avec_une_cle_base64_de_256_bits_minimum"
    expiration-ms: 86400000    # 24h

springdoc:
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
    tagsSorter: alpha
  api-docs:
    path: /v3/api-docs
```

> **Astuce** : mets `ddl-auto: update` seulement au tout début pour prototyper vite, puis repasse à `validate` + Flyway dès que le schéma se stabilise.

---

## 5 bis. Mise en place de PostgreSQL avec Docker

On lance PostgreSQL dans un conteneur : rien ne s'installe en dur sur la machine, l'environnement est reproductible et jetable, et c'est identique à ce qu'on aura en production.

### `docker-compose.yml` (à la racine du projet, à côté du `pom.xml`)

```yaml
services:
  db:
    image: postgres:16
    container_name: fitforge-db
    environment:
      POSTGRES_USER: fitforge
      POSTGRES_PASSWORD: fitforge
      POSTGRES_DB: fitforge
    ports:
      - "5432:5432"
    volumes:
      - fitforge_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U fitforge -d fitforge"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  fitforge_pgdata:
```

> Le `volume` nommé `fitforge_pgdata` fait survivre les données même si on supprime le conteneur. Le `healthcheck` permet de savoir quand la base est vraiment prête (statut `healthy`).

### Commandes essentielles

```bash
docker compose up -d        # démarrer la base en arrière-plan
docker compose ps           # vérifier le statut (attendre "healthy")
docker compose logs -f db   # voir les logs de la base
docker compose stop         # arrêter sans supprimer
docker compose down         # supprimer le conteneur (les données restent dans le volume)
docker compose down -v      # tout supprimer, y compris les données (repart de zéro)
```

### Vérifier que la base répond

```bash
docker exec -it fitforge-db psql -U fitforge -d fitforge -c "SELECT version();"
```

Si ça affiche `PostgreSQL 16.x ...`, la base tourne. Les valeurs `fitforge/fitforge/fitforge` correspondent exactement à ce qui est dans `application.yml`, donc Spring Boot se connectera sans rien changer.

### Évolution future (quand le projet grandit)

Le jour où tu ajoutes d'autres services (pgvector pour l'IA, Redis pour le cache, ton microservice FastAPI d'analyse de forme), tu les ajoutes simplement comme nouveaux `services:` dans ce même fichier, et `docker compose up -d` lance tout ensemble. Pour l'IA vectorielle, il suffira de remplacer l'image par `pgvector/pgvector:pg16`.

---

## 6. Le modèle de données

### Vue d'ensemble des tables (Partie 1)

| Table | Rôle | Relations clés |
|---|---|---|
| `users` | Compte & authentification | 1–1 avec `user_profiles` |
| `user_profiles` | **Données physiques & sportives** (date de naissance, poids, taille, objectif, rythme de vie, blessures, préférences alimentaires, sommeil, langue…) | appartient à 1 `User` |
| `user_injuries`, `user_allergies`, `user_equipment`, `user_workout_days` | Listes rattachées au profil (`@ElementCollection`) | appartiennent à 1 `UserProfile` |
| `body_measurements` | **Historique** poids / mensurations dans le temps | N appartiennent à 1 `User` |
| `exercises` | Catalogue d'exercices (référentiel) | référencé par `SessionExercise` & `SetLog` |
| `workout_programs` | Programme (ex : « Prise de masse 4 semaines ») | 1 `User` a N programmes |
| `workout_sessions` | Séance-type dans un programme | 1 programme a N séances |
| `session_exercises` | Exercice placé dans une séance (séries/reps cibles) | table de liaison enrichie |
| `workout_logs` | Une séance **réellement effectuée** (date, durée, RPE) | 1 `User` a N logs |
| `set_logs` | Une série réellement faite (poids, reps réels) | 1 log a N séries |
| `nutrition_entries` | Journal alimentaire (repas, calories, macros) | 1 `User` a N entrées |
| `training_scores` | Score d'entraînement calculé (par jour/semaine) | 1 `User` a N scores |

### Pourquoi séparer `User`, `UserProfile` et `BodyMeasurement` ?

- **`User`** ne contient que l'identité et l'auth (email, mot de passe hashé, rôle). C'est ce qui sert à se connecter.
- **`UserProfile`** contient les données « qui es-tu physiquement » : la **valeur actuelle** de taille, poids, objectif, rythme de vie, blessures, niveau. Relation **1–1** avec `User`.
- **`BodyMeasurement`** garde **l'historique** : chaque pesée est une ligne. On peut ainsi tracer une courbe de poids dans Flutter sans jamais perdre de données. Relation **1–N**.

### Schéma relationnel (texte)

```
User (1) ───── (1) UserProfile
  │
  ├──── (N) BodyMeasurement        [historique poids/mensurations]
  ├──── (N) WorkoutProgram ──(N) WorkoutSession ──(N) SessionExercise ──(1) Exercise
  ├──── (N) WorkoutLog ──(N) SetLog ──(1) Exercise
  ├──── (N) NutritionEntry
  └──── (N) TrainingScore
```

---

## 7. Les entités JPA

> Extraits représentatifs. Les autres suivent exactement le même patron.

### `User`

```java
@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String fullName;

    private String phoneNumber;        // téléphone (optionnel, utile en Tunisie pour l'inscription)

    private String avatarUrl;          // photo de profil

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;                 // ADHERENT pour la partie 1

    @Column(nullable = false)
    private boolean enabled = true;

    @Column(nullable = false)
    private boolean emailVerified = false;  // pour la validation d'email

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    private Instant lastLoginAt;       // dernière connexion

    // 1–1 : le profil physique
    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private UserProfile profile;
}
```

### `UserProfile` — **toutes les infos de l'adhérent**

```java
@Entity
@Table(name = "user_profiles")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UserProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // Lien 1–1 vers le compte
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    // --- Identité physique ---
    @Column(nullable = false)
    private LocalDate birthDate;       // date de naissance (l'âge se calcule à partir de ça)

    @Enumerated(EnumType.STRING)
    private Gender gender;             // HOMME, FEMME, AUTRE

    private Double heightCm;           // taille en cm
    private Double currentWeightKg;    // poids actuel (dernière pesée)
    private Double targetWeightKg;     // poids visé

    // --- Objectif & mode de vie ---
    @Enumerated(EnumType.STRING)
    private FitnessGoal goal;          // PERTE_POIDS, PRISE_MASSE, MAINTIEN, FORCE, ENDURANCE

    @Enumerated(EnumType.STRING)
    private ActivityLevel activityLevel; // SEDENTAIRE, LEGER, MODERE, ACTIF, TRES_ACTIF (rythme de vie)

    @Enumerated(EnumType.STRING)
    private ExperienceLevel experienceLevel; // DEBUTANT, INTERMEDIAIRE, AVANCE

    private Integer weeklyWorkoutTarget; // nb de séances visées / semaine

    @Enumerated(EnumType.STRING)
    private WorkoutLocation preferredLocation; // SALLE, MAISON, EXTERIEUR

    // Jours d'entraînement préférés (ex : LUNDI, MERCREDI, VENDREDI)
    @ElementCollection(targetClass = DayOfWeek.class)
    @CollectionTable(name = "user_workout_days", joinColumns = @JoinColumn(name = "profile_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "day")
    private List<DayOfWeek> preferredWorkoutDays = new ArrayList<>();

    // Équipement dont l'adhérent dispose (pour adapter les programmes)
    @ElementCollection(targetClass = Equipment.class)
    @CollectionTable(name = "user_equipment", joinColumns = @JoinColumn(name = "profile_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "equipment")
    private List<Equipment> availableEquipment = new ArrayList<>();

    // --- Santé / blessures ---
    @ElementCollection
    @CollectionTable(name = "user_injuries", joinColumns = @JoinColumn(name = "profile_id"))
    @Column(name = "injury")
    private List<String> injuries = new ArrayList<>();   // ex : "genou droit", "épaule gauche"

    @Column(length = 1000)
    private String medicalNotes;        // maladies, contre-indications, remarques médicales

    // --- Nutrition & habitudes ---
    @Enumerated(EnumType.STRING)
    private DietaryPreference dietaryPreference; // AUCUNE, VEGETARIEN, VEGAN, HALAL, SANS_GLUTEN, KETO

    @ElementCollection
    @CollectionTable(name = "user_allergies", joinColumns = @JoinColumn(name = "profile_id"))
    @Column(name = "allergy")
    private List<String> allergies = new ArrayList<>();  // ex : "arachides", "lactose"

    private Integer dailyCalorieTarget; // objectif calories/jour (sinon calculé depuis TDEE)
    private Integer waterTargetMl;      // objectif hydratation/jour
    private Double averageSleepHours;   // sommeil moyen (impacte la récupération)

    // --- Préférences applicatives ---
    @Enumerated(EnumType.STRING)
    private UnitSystem unitSystem = UnitSystem.METRIQUE; // METRIQUE (kg/cm) ou IMPERIAL (lb/in)

    private String preferredLanguage = "fr"; // fr, ar, en — l'app cible la Tunisie/Maghreb

    // --- Calculés / dérivés (mis à jour par le service) ---
    private Double bmi;                 // IMC calculé
    private Integer tdee;               // dépense énergétique estimée (kcal/j)
    private Integer age;                // âge calculé depuis birthDate (dénormalisé pour le TDEE)

    // --- Onboarding ---
    @Column(nullable = false)
    private boolean onboardingCompleted = false; // profil rempli au 1er lancement ?

    @UpdateTimestamp
    private Instant updatedAt;
}
```

### `BodyMeasurement` — historique

```java
@Entity
@Table(name = "body_measurements")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class BodyMeasurement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private LocalDate measuredOn;

    private Double weightKg;
    private Double bodyFatPercent;
    private Double waistCm;
    private Double chestCm;
    private Double armCm;
    private Double thighCm;
}
```

### `Exercise` (référentiel)

```java
@Entity
@Table(name = "exercises")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Exercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    private MuscleGroup primaryMuscle;   // PECTORAUX, DOS, JAMBES, EPAULES...

    @Enumerated(EnumType.STRING)
    private Equipment equipment;         // BARRE, HALTERE, MACHINE, POIDS_CORPS...

    @Column(length = 1000)
    private String instructions;

    private String videoUrl;
}
```

### `WorkoutProgram` / `WorkoutSession` / `SessionExercise`

```java
@Entity @Table(name = "workout_programs")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class WorkoutProgram {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "user_id")
    private User user;

    private String title;
    @Enumerated(EnumType.STRING) private FitnessGoal goal;
    private Integer durationWeeks;
    private boolean isTemplate;

    @OneToMany(mappedBy = "program", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkoutSession> sessions = new ArrayList<>();
}

@Entity @Table(name = "workout_sessions")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class WorkoutSession {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "program_id")
    private WorkoutProgram program;

    private String title;          // ex : "Push - Jour 1"
    private Integer dayOfWeek;      // 1..7
    private Integer orderIndex;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SessionExercise> exercises = new ArrayList<>();
}

@Entity @Table(name = "session_exercises")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SessionExercise {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "session_id")
    private WorkoutSession session;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "exercise_id")
    private Exercise exercise;

    private Integer targetSets;
    private Integer targetReps;
    private Double targetWeightKg;
    private Integer restSeconds;
    private Integer orderIndex;
}
```

### `WorkoutLog` / `SetLog` (séances réellement faites)

```java
@Entity @Table(name = "workout_logs")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class WorkoutLog {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "session_id")
    private WorkoutSession session;    // optionnel (séance libre possible)

    @Column(nullable = false)
    private LocalDate performedOn;
    private Integer durationMinutes;
    private Integer rpe;               // ressenti d'effort 1..10

    @OneToMany(mappedBy = "workoutLog", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SetLog> sets = new ArrayList<>();
}

@Entity @Table(name = "set_logs")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SetLog {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "workout_log_id")
    private WorkoutLog workoutLog;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "exercise_id")
    private Exercise exercise;

    private Integer setNumber;
    private Integer reps;
    private Double weightKg;
    private boolean completed;
}
```

### `NutritionEntry`

```java
@Entity @Table(name = "nutrition_entries")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class NutritionEntry {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false)
    private LocalDate consumedOn;

    @Enumerated(EnumType.STRING)
    private MealType mealType;          // PETIT_DEJ, DEJEUNER, DINER, COLLATION

    private String foodName;
    private Double quantityGrams;
    private Integer calories;
    private Double proteinG;
    private Double carbsG;
    private Double fatG;
}
```

### `TrainingScore`

```java
@Entity @Table(name = "training_scores")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class TrainingScore {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false)
    private LocalDate scoreDate;

    private Integer score;             // 0..100
    private Double weeklyVolumeKg;     // volume total soulevé
    private Integer sessionsCompleted; // séances de la semaine
    private Double consistencyRate;    // % d'assiduité vs objectif

    @Column(length = 500)
    private String insight;            // phrase générée : "Volume en hausse de 8%"
}
```

---

## 8. Les ENUMs

```java
public enum Role { ADHERENT, COACH, ADMIN }

public enum Gender { HOMME, FEMME, AUTRE }

public enum FitnessGoal { PERTE_POIDS, PRISE_MASSE, MAINTIEN, FORCE, ENDURANCE }

public enum ActivityLevel {          // rythme de vie
    SEDENTAIRE, LEGER, MODERE, ACTIF, TRES_ACTIF
}

public enum ExperienceLevel { DEBUTANT, INTERMEDIAIRE, AVANCE }

public enum MuscleGroup {
    PECTORAUX, DOS, JAMBES, EPAULES, BICEPS, TRICEPS, ABDOS, FESSIERS, MOLLETS, CARDIO
}

public enum Equipment { BARRE, HALTERE, MACHINE, POULIE, KETTLEBELL, POIDS_CORPS, ELASTIQUE }

public enum MealType { PETIT_DEJ, DEJEUNER, DINER, COLLATION }

public enum WorkoutLocation { SALLE, MAISON, EXTERIEUR }

public enum DietaryPreference { AUCUNE, VEGETARIEN, VEGAN, HALAL, SANS_GLUTEN, KETO }

public enum UnitSystem { METRIQUE, IMPERIAL }

// DayOfWeek : on réutilise java.time.DayOfWeek (LUNDI..DIMANCHE), pas besoin d'en créer un.
```

---

## 9. DTOs & mapping

**Règle d'or : on n'expose jamais une entité.** Exemple pour le profil :

```java
// Ce que Flutter envoie pour créer/mettre à jour le profil
public record UpdateProfileRequest(
    // Identité physique
    @Past @NotNull LocalDate birthDate,
    Gender gender,
    @Positive Double heightCm,
    @Positive Double currentWeightKg,
    @Positive Double targetWeightKg,
    // Objectif & mode de vie
    FitnessGoal goal,
    ActivityLevel activityLevel,
    ExperienceLevel experienceLevel,
    @Min(0) @Max(14) Integer weeklyWorkoutTarget,
    WorkoutLocation preferredLocation,
    List<DayOfWeek> preferredWorkoutDays,
    List<Equipment> availableEquipment,
    // Santé
    List<String> injuries,
    String medicalNotes,
    // Nutrition & habitudes
    DietaryPreference dietaryPreference,
    List<String> allergies,
    @Positive Integer dailyCalorieTarget,
    @Positive Integer waterTargetMl,
    @PositiveOrZero Double averageSleepHours,
    // Préférences applicatives
    UnitSystem unitSystem,
    String preferredLanguage
) {}

// Ce que l'API renvoie
public record ProfileResponse(
    UUID id,
    String fullName,
    String avatarUrl,
    // Identité physique
    LocalDate birthDate,
    Integer age,                 // calculé côté serveur
    Gender gender,
    Double heightCm,
    Double currentWeightKg,
    Double targetWeightKg,
    // Objectif & mode de vie
    FitnessGoal goal,
    ActivityLevel activityLevel,
    ExperienceLevel experienceLevel,
    Integer weeklyWorkoutTarget,
    WorkoutLocation preferredLocation,
    List<DayOfWeek> preferredWorkoutDays,
    List<Equipment> availableEquipment,
    // Santé
    List<String> injuries,
    String medicalNotes,
    // Nutrition & habitudes
    DietaryPreference dietaryPreference,
    List<String> allergies,
    Integer dailyCalorieTarget,
    Integer waterTargetMl,
    Double averageSleepHours,
    // Préférences applicatives
    UnitSystem unitSystem,
    String preferredLanguage,
    // Dérivés
    Double bmi,
    Integer tdee,
    boolean onboardingCompleted
) {}
```

> **Note sur l'âge** : on stocke la **date de naissance** (`birthDate`) et l'`age` est recalculé par le service (`Period.between(birthDate, LocalDate.now()).getYears()`) à chaque mise à jour, car l'âge change tout seul avec le temps. On ne demande jamais l'âge directement à l'utilisateur.

Mapper MapStruct :

```java
@Mapper(componentModel = "spring")
public interface ProfileMapper {
    ProfileResponse toResponse(UserProfile profile);
    void updateFromDto(UpdateProfileRequest dto, @MappingTarget UserProfile profile);
}
```

---

## 10. Repositories

```java
public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}

public interface UserProfileRepository extends JpaRepository<UserProfile, UUID> {
    Optional<UserProfile> findByUserId(UUID userId);
}

public interface BodyMeasurementRepository extends JpaRepository<BodyMeasurement, UUID> {
    List<BodyMeasurement> findByUserIdOrderByMeasuredOnDesc(UUID userId);
}

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {
    List<WorkoutLog> findByUserIdAndPerformedOnBetween(UUID userId, LocalDate from, LocalDate to);
}

public interface NutritionEntryRepository extends JpaRepository<NutritionEntry, UUID> {
    List<NutritionEntry> findByUserIdAndConsumedOn(UUID userId, LocalDate date);
}

public interface TrainingScoreRepository extends JpaRepository<TrainingScore, UUID> {
    Optional<TrainingScore> findTopByUserIdOrderByScoreDateDesc(UUID userId);
}
```

---

## 11. Services

Exemple : le service profil qui **calcule l'IMC et le TDEE** au passage.

```java
@Service
@RequiredArgsConstructor
public class ProfileService {

    private final UserProfileRepository profileRepo;
    private final UserRepository userRepo;
    private final ProfileMapper mapper;

    @Transactional(readOnly = true)
    public ProfileResponse getMyProfile(UUID userId) {
        UserProfile p = profileRepo.findByUserId(userId)
            .orElseThrow(() -> new ResourceNotFoundException("Profil introuvable"));
        return mapper.toResponse(p);
    }

    @Transactional
    public ProfileResponse updateMyProfile(UUID userId, UpdateProfileRequest req) {
        UserProfile p = profileRepo.findByUserId(userId)
            .orElseGet(() -> {
                User u = userRepo.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User introuvable"));
                UserProfile np = new UserProfile();
                np.setUser(u);
                return np;
            });

        mapper.updateFromDto(req, p);
        recomputeDerived(p);              // IMC + TDEE
        return mapper.toResponse(profileRepo.save(p));
    }

    private void recomputeDerived(UserProfile p) {
        // Âge à partir de la date de naissance
        if (p.getBirthDate() != null) {
            p.setAge(Period.between(p.getBirthDate(), LocalDate.now()).getYears());
        }
        // IMC
        if (p.getHeightCm() != null && p.getCurrentWeightKg() != null) {
            double m = p.getHeightCm() / 100.0;
            p.setBmi(round(p.getCurrentWeightKg() / (m * m), 1));
        }
        // TDEE = BMR (Mifflin-St Jeor) × facteur d'activité
        if (p.getHeightCm() != null && p.getCurrentWeightKg() != null
                && p.getAge() != null && p.getGender() != null) {
            double bmr = 10 * p.getCurrentWeightKg() + 6.25 * p.getHeightCm() - 5 * p.getAge();
            bmr += (p.getGender() == Gender.HOMME) ? 5 : -161;
            double factor = switch (p.getActivityLevel() == null ? ActivityLevel.MODERE : p.getActivityLevel()) {
                case SEDENTAIRE -> 1.2;
                case LEGER      -> 1.375;
                case MODERE     -> 1.55;
                case ACTIF      -> 1.725;
                case TRES_ACTIF -> 1.9;
            };
            p.setTdee((int) Math.round(bmr * factor));
        }
    }
}
```

> Le **calcul du score d'entraînement** vit dans `TrainingScoreService` : il lit les `WorkoutLog` de la semaine, additionne le volume (Σ reps × poids), compare à l'objectif hebdo du profil, et produit une note 0–100 + une phrase d'insight.

---

## 12. Controllers — les API REST

Exemple complet du controller profil, annoté pour Swagger :

```java
@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
@Tag(name = "Profil", description = "Données physiques et sportives de l'adhérent")
public class ProfileController {

    private final ProfileService service;

    @GetMapping
    @Operation(summary = "Récupérer mon profil complet")
    public ProfileResponse getMyProfile(@AuthenticationPrincipal UserPrincipal me) {
        return service.getMyProfile(me.getId());
    }

    @PutMapping
    @Operation(summary = "Créer ou mettre à jour mon profil (poids, taille, objectif, blessures…)")
    public ProfileResponse updateMyProfile(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody UpdateProfileRequest req) {
        return service.updateMyProfile(me.getId(), req);
    }
}
```

Même patron pour `BodyMeasurementController`, `WorkoutProgramController`, `WorkoutLogController`, `NutritionController`, `TrainingScoreController`, `ExerciseController`.

---

## 13. Sécurité (JWT)

Flux : `POST /api/v1/auth/register` → `POST /api/v1/auth/login` renvoie un **token JWT** → Flutter met `Authorization: Bearer <token>` sur chaque requête.

```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
          .csrf(AbstractHttpConfigurer::disable)
          .cors(Customizer.withDefaults())
          .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
          .authorizeHttpRequests(auth -> auth
              .requestMatchers(
                  "/api/v1/auth/**",
                  "/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**"
              ).permitAll()
              .anyRequest().authenticated()
          )
          .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

> **CORS** : autorise l'origine de ton app Flutter (en dev, `http://localhost` + l'IP de l'émulateur). En prod, restreins au domaine réel.

---

## 14. Swagger / OpenAPI

Config pour un Swagger **propre** avec le bouton « Authorize » (JWT) :

```java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI fitforgeOpenApi() {
        final String scheme = "bearerAuth";
        return new OpenAPI()
            .info(new Info()
                .title("FitForge AI — API Adhérent")
                .version("v1")
                .description("API REST de la partie adhérent : profil, entraînement, nutrition, score.")
                .contact(new Contact().name("FitForge AI").email("contact@fitforge.tn")))
            .addSecurityItem(new SecurityRequirement().addList(scheme))
            .components(new Components().addSecuritySchemes(scheme,
                new SecurityScheme()
                    .name(scheme)
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")));
    }
}
```

Accès : **`http://localhost:8080/swagger-ui.html`**

Bonnes pratiques Swagger :
- `@Tag` sur chaque controller (regroupe les endpoints par domaine).
- `@Operation(summary = "...")` sur chaque méthode.
- `@Schema(description = "...", example = "...")` sur les champs de DTO importants.
- `@ApiResponse` pour documenter les codes 200 / 400 / 404 quand c'est utile.

---

## 15. Gestion des erreurs

Un handler global renvoie des erreurs JSON cohérentes à Flutter :

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiError> notFound(ResourceNotFoundException ex) {
        return ResponseEntity.status(404)
            .body(new ApiError(404, "NOT_FOUND", ex.getMessage(), Instant.now()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> validation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> e.getField() + " : " + e.getDefaultMessage())
            .collect(Collectors.joining(", "));
        return ResponseEntity.badRequest()
            .body(new ApiError(400, "VALIDATION_ERROR", msg, Instant.now()));
    }
}

public record ApiError(int status, String code, String message, Instant timestamp) {}
```

---

## 16. Liste complète des endpoints

Base : `/api/v1` — tout est en `Bearer JWT` sauf `/auth/**`.

### Auth
| Méthode | Endpoint | Rôle |
|---|---|---|
| POST | `/auth/register` | Créer un compte adhérent |
| POST | `/auth/login` | Se connecter → renvoie le JWT |
| GET  | `/auth/me` | Infos du compte connecté |

### Profil (données de l'adhérent)
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/profile` | Mon profil complet (poids, taille, objectif, rythme, blessures…) |
| PUT | `/profile` | Créer / mettre à jour mon profil |

### Mensurations (historique)
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET  | `/measurements` | Historique de mes pesées/mensurations |
| POST | `/measurements` | Ajouter une pesée |
| DELETE | `/measurements/{id}` | Supprimer une entrée |

### Exercices (référentiel)
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/exercises` | Lister / filtrer par muscle, équipement |
| GET | `/exercises/{id}` | Détail d'un exercice |

### Programmes & séances
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET  | `/programs` | Mes programmes |
| POST | `/programs` | Créer un programme |
| GET  | `/programs/{id}` | Détail (avec séances + exercices) |
| PUT  | `/programs/{id}` | Modifier |
| DELETE | `/programs/{id}` | Supprimer |
| POST | `/programs/{id}/sessions` | Ajouter une séance |
| POST | `/sessions/{id}/exercises` | Ajouter un exercice à une séance |

### Logs d'entraînement (séances faites)
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET  | `/workout-logs?from=&to=` | Mes séances effectuées sur une période |
| POST | `/workout-logs` | Enregistrer une séance faite (+ ses séries) |
| GET  | `/workout-logs/{id}` | Détail d'une séance |
| DELETE | `/workout-logs/{id}` | Supprimer |

### Nutrition
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET  | `/nutrition?date=` | Mon journal d'un jour |
| POST | `/nutrition` | Ajouter un aliment/repas |
| PUT  | `/nutrition/{id}` | Modifier |
| DELETE | `/nutrition/{id}` | Supprimer |
| GET  | `/nutrition/summary?date=` | Totaux calories/macros du jour |

### Score d'entraînement
| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/score/current` | Mon score le plus récent |
| GET | `/score/history?weeks=` | Évolution du score |
| POST | `/score/recompute` | Recalculer (déclenché après une séance) |

---

## 17. Ordre de développement conseillé

1. **Setup** : projet Spring Boot 4.1.0 (start.spring.io) + `docker compose up -d` pour PostgreSQL + `application.yml` + première migration Flyway.
2. **Auth** : `User`, register/login, JWT, sécuriser les routes. → tester dans Swagger.
3. **Profil** : `UserProfile` + `BodyMeasurement` + calcul IMC/TDEE.
4. **Exercices** : référentiel + seed de quelques exercices (migration `INSERT`).
5. **Programmes/séances** : `WorkoutProgram → WorkoutSession → SessionExercise`.
6. **Logs** : `WorkoutLog → SetLog` (le cœur du tracking).
7. **Nutrition** : `NutritionEntry` + endpoint résumé.
8. **Score** : `TrainingScore` + logique de calcul.
9. **Finitions Swagger** : exemples, descriptions, `@ApiResponse`.
10. **Brancher Flutter** : générer le client Dio à partir de l'OpenAPI si tu veux gagner du temps.

> **Tip Flutter** : le fichier OpenAPI (`/v3/api-docs`) peut générer automatiquement un client Dart avec `openapi-generator` (`-g dart-dio`). Tu récupères les modèles + les appels prêts.

---

## 18. Le prompt à réutiliser

Copie-colle ce prompt à un assistant IA (ou à moi dans une nouvelle session) pour qu'il **génère le code complet** module par module :

```
Tu es un développeur backend senior Spring Boot. Je construis "FitForge AI",
une app fitness. Génère le backend de la PARTIE 1 (adhérent) en Java 21 /
Spring Boot 4.1.0 (Spring Framework 7), architecture en couches package-by-feature
(controller → service → repository → entity), DTO en records + MapStruct,
Lombok, PostgreSQL 16 (lancé via docker-compose) + Flyway, Spring Security + JWT,
et springdoc-openapi 2.8.x (Swagger UI avec bouton Authorize JWT).

Domaines et entités à couvrir :
- user : User (compte/auth : email, passwordHash, fullName, phoneNumber,
  avatarUrl, role, emailVerified, createdAt, updatedAt, lastLoginAt),
  UserProfile (1–1 : birthDate, gender, heightCm, currentWeightKg,
  targetWeightKg, goal, activityLevel [rythme de vie], experienceLevel,
  weeklyWorkoutTarget, preferredLocation, preferredWorkoutDays [liste],
  availableEquipment [liste], injuries [liste], medicalNotes,
  dietaryPreference, allergies [liste], dailyCalorieTarget, waterTargetMl,
  averageSleepHours, unitSystem, preferredLanguage, onboardingCompleted,
  + age/bmi/tdee calculés), BodyMeasurement (historique poids/mensurations).
- training : Exercise (référentiel), WorkoutProgram, WorkoutSession,
  SessionExercise, WorkoutLog, SetLog.
- nutrition : NutritionEntry (mealType, calories, macros).
- score : TrainingScore (score 0–100, volume, assiduité, insight).

ENUMs : Role, Gender, FitnessGoal, ActivityLevel, ExperienceLevel,
MuscleGroup, Equipment, MealType, WorkoutLocation, DietaryPreference,
UnitSystem (+ java.time.DayOfWeek réutilisé).

Exigences :
1. Ne jamais exposer une entité : DTO request/response pour chaque endpoint.
2. IDs en UUID. Relations LAZY. Timestamps auto.
3. Le service profil calcule l'âge (depuis birthDate), l'IMC et le TDEE
   (Mifflin-St Jeor + facteur activité).
4. Le service score calcule une note hebdo à partir des WorkoutLog.
5. GlobalExceptionHandler avec réponses JSON propres (404 / 400 validation).
6. Swagger annoté (@Tag, @Operation, @Schema, exemples) — API prête pour Flutter.
7. Migrations Flyway pour tout le schéma + un seed d'exercices (ou Hibernate
   ddl-auto=update si je te le précise).
8. Fournis aussi le docker-compose.yml (postgres:16, volume nommé, healthcheck)
   et le application.yml correspondant, PUIS vérifie que la base tourne
   (docker compose ps = healthy, SELECT version() répond) avant de coder.
9. TOUT le code doit être commenté avec des commentaires explicatifs clairs en
   français : rôle de chaque classe, but de chaque méthode non triviale, chaque
   relation JPA et chaque règle métier (IMC/TDEE/âge/score). Un étudiant doit
   pouvoir lire et comprendre sans aide.
10. Cible Spring Boot 4.1.0 / Spring Framework 7 / Spring Security 6.x
    (syntaxe lambda, imports Jakarta). Le code doit compiler.

Donne-moi le code dans cet ordre, un module à la fois, en commençant par
le setup (docker-compose.yml + vérification base, pom.xml, application.yml)
puis auth, profil, etc. À la fin de chaque module, dis-moi comment le tester
dans Swagger. Attends ma validation avant de passer au module suivant.
```

---

### Récapitulatif

Tu as maintenant : l'**architecture complète**, le **modèle de données** de la partie adhérent (avec la table `UserProfile` séparée pour poids/taille/objectif/rythme/blessures + l'historique `BodyMeasurement`), toutes les **entités**, les **DTO**, la **sécurité JWT**, un **Swagger propre**, la **liste exhaustive des endpoints** à brancher sur Flutter, un **ordre de dev** clair, et un **prompt réutilisable**.

Prochaine étape logique : je peux te générer directement le **code source complet** d'un module (par ex. auth + profil) si tu veux démarrer tout de suite.
