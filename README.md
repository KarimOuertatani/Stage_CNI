# FitForge AI — Backend (Partie 1 : Adhérent)

Backend REST **Spring Boot 4.1.0 / Java 21** de l'application FitForge AI.
Architecture en couches *package-by-feature* (`controller → service → repository → entity`),
DTO en records + MapStruct, Lombok, PostgreSQL 16 (Docker) + Flyway, Spring Security + JWT,
Swagger/OpenAPI. Prêt à brancher sur Flutter.

> Le document de référence complet est [`FitForge_Backend_Guide.md`](FitForge_Backend_Guide.md).

## Prérequis

- **Java 21** (le projet cible Java 21 ; un JDK 17 seul ne suffit pas pour compiler).
- **Docker Desktop** (pour PostgreSQL).
- Maven est fourni via le wrapper `./mvnw` (aucune installation nécessaire).

## Démarrage le plus simple (Windows)

**Double-clique sur `run.bat`** (dossier `api/`) : il démarre la base **et** le
serveur, sur le port **8081**. Attends `Started ApiApplication`, puis ouvre
**http://localhost:8081/swagger-ui.html**.

Détails pas à pas : [`GUIDE_DEMARRAGE.md`](GUIDE_DEMARRAGE.md).

## Démarrage manuel

```bash
# 1) Lancer la base PostgreSQL (attendre le statut "healthy")
docker compose up -d
docker compose ps

# 2) Démarrer l'application
#    Bash / Git Bash :
JAVA_HOME="C:/Users/karim/.jdks/ms-21.0.8" ./mvnw spring-boot:run
#    PowerShell :
#    $env:JAVA_HOME="C:\Users\karim\.jdks\ms-21.0.8"; .\mvnw.cmd spring-boot:run

# 3) Ouvrir Swagger
#    http://localhost:8080/swagger-ui.html
```

> Le port par défaut est **8080**. S'il est occupé (message *Port 8080 already in
> use*), ajoute `-Dspring-boot.run.arguments="--server.port=8081"` — c'est ce que
> fait `run.bat`.

Au démarrage, **Flyway** crée le schéma (16 tables) et insère **20 exercices** de base,
puis **Hibernate valide** que les entités correspondent au schéma.

### Tester dans Swagger

1. `POST /api/v1/auth/register` → récupérer le `token`.
2. Cliquer sur **Authorize** (en haut à droite) et coller le token.
3. Tous les endpoints protégés sont maintenant testables.

## Configuration

Tout est dans [`src/main/resources/application.yaml`](src/main/resources/application.yaml).
Les identifiants de la base (`fitforge` / `fitforge` / `fitforge`) correspondent au
[`docker-compose.yml`](docker-compose.yml).

- **Port** : `8080` par défaut. S'il est occupé, lancer sur un autre port :
  `./mvnw spring-boot:run -Dspring-boot.run.arguments="--server.port=8090"`
  (ou variable d'environnement `SERVER_PORT`).
- **Secret JWT** et durée de vie : bloc `app.jwt` (à surcharger par variable
  d'environnement en production).

## Structure des packages

```
com.fitforge.api
├── config       OpenApiConfig, SecurityConfig, CorsConfig
├── security     JwtService, JwtAuthenticationFilter, CustomUserDetailsService, UserPrincipal
├── common       enums, exception (GlobalExceptionHandler), dto (ApiError)
├── user         compte + profil + mensurations (auth, profil, IMC/TDEE)
├── training     exercices, programmes, séances, logs d'entraînement
├── nutrition    journal alimentaire + résumé
└── score        score d'entraînement hebdomadaire
```

## Principaux endpoints (`/api/v1`, JWT sauf `/auth/**`)

| Domaine | Endpoints |
|---|---|
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me` |
| Profil | `GET /profile`, `PUT /profile` (calcule âge, IMC, TDEE) |
| Mensurations | `GET/POST /measurements`, `DELETE /measurements/{id}` |
| Exercices | `GET /exercises?muscle=&equipment=`, `GET /exercises/{id}` |
| Programmes | `GET/POST /programs`, `GET/PUT/DELETE /programs/{id}`, `POST /programs/{id}/sessions`, `POST /sessions/{id}/exercises` |
| Logs | `GET /workout-logs?from=&to=`, `POST /workout-logs`, `GET/DELETE /workout-logs/{id}` |
| Nutrition | `GET /nutrition?date=`, `POST /nutrition`, `PUT/DELETE /nutrition/{id}`, `GET /nutrition/summary?date=` |
| Score | `GET /score/current`, `GET /score/history?weeks=`, `POST /score/recompute` |

## Règles métier implémentées

- **Âge** : recalculé depuis `birthDate` (jamais saisi directement).
- **IMC** : `poids / taille²`.
- **TDEE** : BMR (Mifflin-St Jeor) × facteur de rythme de vie.
- **Score** : assiduité (séances/objectif hebdo, 70 pts) + progression du volume
  vs semaine précédente (30 pts), 0–100, avec une phrase d'analyse.

## Commandes utiles

```bash
./mvnw compile            # compiler
./mvnw test               # tests
docker compose down       # arrêter la base (données conservées)
docker compose down -v    # tout remettre à zéro (données supprimées)
```
