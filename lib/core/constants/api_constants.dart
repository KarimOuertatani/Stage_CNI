// ignore: unused_import
import 'package:flutter/foundation.dart';

/// Constantes API centralisées (backend Spring Boot FitForge).
abstract final class ApiConstants {
  /// Port du backend Spring Boot (voir run.bat côté `api/`).
  static const int _port = 8081;

  // ═══════════════════════════════════════════════════════════════════
  //  ⚙️  OÙ TOURNE LE BACKEND ?  — UN SEUL bloc `_host` actif à la fois.
  //     Toutes les URLs (API REST, WebSocket, médias) en découlent.
  // ═══════════════════════════════════════════════════════════════════

  // ┌─────────────────────────────────────────────────────────────────┐
  // │ 🖥️  DÉV SUR LA MACHINE (émulateur Android / Chrome / Windows)    │
  // │     👉 LAISSER CE BLOC ACTIF pour tester sur émulateur/PC.       │
  // └─────────────────────────────────────────────────────────────────┘
  /* 
  static String get _host {
    // Émulateur Android : 10.0.2.2 = alias du localhost de la machine hôte.
    // Web / Windows / iOS simulateur : localhost fonctionne directement.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }
*/
  // ┌─────────────────────────────────────────────────────────────────┐
  // │ 📱  VRAI TÉLÉPHONE (sur le MÊME Wi-Fi que le PC)                  │
  // │     👉 POUR TESTER SUR TON TÉLÉPHONE :                           │
  // │        1) mets le bloc `_host` du DESSUS en commentaire ;        │
  // │        2) DÉCOMMENTE le bloc ci-dessous ;                        │
  // │        3) remplace l'IP par celle du PC (Wi-Fi) si elle change.  │
  // │           (IP actuelle détectée : 192.168.100.57 — Wi-Fi biscotinos) │
  // │     ⚠️ Le PC et le téléphone doivent être sur le même réseau,    │
  // │        et le pare-feu Windows doit autoriser le port 8081.       │
  // └─────────────────────────────────────────────────────────────────┘
  // Ancien Wi-Fi (mis en commentaire, à réutiliser si tu y reviens) :
  static String get _host => '192.168.1.114';

  // Wi-Fi « biscotinos » :
  //static String get _host => '192.168.100.57';

  /// URL de base de l'API REST (dérivée de [_host]).
  static String get baseUrl => 'http://$_host:$_port/api/v1';

  /// URL du endpoint WebSocket/STOMP (chat temps reel). Meme hote/port que l'API.
  static String get wsUrl => 'ws://$_host:$_port/ws';

  /// Origine HTTP du backend (schema + hote + port), SANS le prefixe `/api/v1`.
  /// Sert a resoudre les fichiers servis statiquement sous `/media/**`.
  static String get origin => 'http://$_host:$_port';

  /// Resout une URL de media renvoyee par le backend.
  ///
  /// Le backend renvoie un chemin RELATIF (`/media/<nom>`) pour rester portable
  /// entre emulateur et vrai appareil. On le prefixe ici par l'[origin]. Une URL
  /// deja absolue (http/https) est renvoyee telle quelle ; null/vide -> null.
  static String? mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }

  /// Hôte du CDN ExerciseDB (images + vidéos des exercices).
  static const String _exerciseDbCdn = 'https://cdn.exercisedb.dev/';

  /// Route une URL média du CDN ExerciseDB à travers NOTRE backend
  /// (`/api/v1/cdn/…`). Le téléphone joint toujours le backend (LAN / prod),
  /// même s'il ne peut pas joindre directement le CDN public → images et
  /// vidéos s'affichent de façon fiable. Une URL non-CDN est renvoyée telle
  /// quelle ; null/vide → null.
  static String? proxiedMedia(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith(_exerciseDbCdn)) {
      return '$origin/api/v1/cdn/${url.substring(_exerciseDbCdn.length)}';
    }
    return url;
  }

  /// Timeouts par défaut en millisecondes.
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  static const int sendTimeout = 10000;

  // ── Endpoints (base : /api/v1) ────────────────────────────────
  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  // Verification de l'adresse email par code a 6 chiffres.
  static const String verifyEmail = '/auth/verify-email';
  static const String resendCode = '/auth/resend-code';
  static const String me = '/auth/me';
  static const String avatar = '/auth/me/avatar';

  // Medias (upload de pieces jointes)
  static const String media = '/media';

  // Profil & mensurations
  static const String profile = '/profile';
  static const String measurements = '/measurements';

  // Entraînement
  static const String exercises = '/exercises';
  static const String bodyParts = '/bodyparts';
  static const String programs = '/programs';
  static const String programTemplates = '/programs/templates';
  // Génération d'un programme complet par l'IA FitForge (Gemini, proxifié par
  // notre backend). Le questionnaire part au serveur, qui y joint le profil de
  // l'adhérent et le catalogue d'exercices réellement réalisables par lui, puis
  // matérialise le programme dans les tables habituelles.
  static const String programAiGenerate = '/programs/ai/generate';
  static const String programAiStatus = '/programs/ai/status';
  static const String sessions = '/sessions';
  static const String sessionExercises = '/session-exercises';
  static const String workoutLogs = '/workout-logs';

  // Coaching
  static const String registerCoach = '/auth/register/coach';
  static const String coaches = '/coaches';
  static const String coachMe = '/coach/me';
  static const String coachDashboard = '/coach/dashboard';
  static const String coaching = '/coaching';

  // Candidature coach : dépôt des justificatifs et soumission du dossier à
  // l'administration. Depuis la mise en place de la validation, un coach
  // inscrit n'exerce pas tant que son dossier n'a pas été examiné — il est
  // créé en DRAFT, passe en PENDING à la soumission, puis APPROVED ou
  // REJECTED. Aucune de ces routes ne prend d'identifiant : tout est porté
  // par le JWT.
  static const String coachApplication = '/coach-application';
  static const String coachApplicationDocuments = '/coach-application/documents';
  static const String coachApplicationSubmit = '/coach-application/submit';

  /// URL du fichier d'un justificatif.
  ///
  /// ⚠️ Contrairement aux avatars et aux pièces jointes du chat, ces fichiers
  /// ne sont **pas** servis sous `/media/**` (qui est public). Une pièce
  /// d'identité déposée dans un dossier public serait lisible par quiconque
  /// connaît son URL. Ils passent donc par une route authentifiée, et
  /// l'affichage doit transmettre le JWT — d'où l'usage de `Image.network`
  /// avec en-tête, et non d'une URL nue.
  static String coachDocumentFile(String documentId) =>
      '$origin/api/v1/coach-application/documents/$documentId/file';

  // Signalement d'un problème (adhérent ET coach). Le même écran sert les
  // deux rôles : le serveur fige le rôle au moment de l'envoi, ce qui indique
  // depuis quel espace le problème a été rencontré.
  static const String problemReports = '/problem-reports';

  // Coach IA (Gemini, proxifie par notre backend : la cle ne quitte jamais le
  // serveur). Fil prive et unique par adherent — aucune route ne prend
  // d'identifiant d'utilisateur, tout est porte par le JWT.
  static const String coachAiMessages = '/coach-ai/messages';
  static const String coachAiStatus = '/coach-ai/status';

  // Nutrition
  static const String nutrition = '/nutrition';
  static const String nutritionSummary = '/nutrition/summary';
  // Catalogue d'aliments. Le backend agrege trois sources — son cache local,
  // USDA FoodData Central (aliments generiques) et Open Food Facts (produits
  // emballes). Aucune cle externe ne quitte le serveur.
  static const String foodSearch = '/nutrition/foods/search';
  static const String foodRecent = '/nutrition/foods/recent';
  static const String nutritionFromFood = '/nutrition/from-food';

  // Analyse d'une photo de repas (Gemini, proxifie par notre backend : la cle
  // Gemini ne quitte jamais le serveur).
  static const String nutritionAnalyzePhoto = '/nutrition/analyze-photo';

  // Ajout d'un repas a la voix : l'adherent dit ce qu'il a mange. Meme moteur
  // que la photo, meme forme de reponse.
  static const String nutritionAnalyzeVoice = '/nutrition/analyze-voice';
  // Repli / correction : la meme analyse a partir d'une phrase ecrite.
  static const String nutritionAnalyzeText = '/nutrition/analyze-text';

  // Sommeil. `status` répond à deux questions au lancement — faut-il ouvrir
  // le pop-up de saisie, et qu'affiche la tuile de l'accueil — en un seul
  // aller-retour. Le score, la moyenne et les conseils sont calculés par le
  // serveur (règle écrite, sans appel à un modèle de langage).
  static const String sleep = '/sleep';
  static const String sleepStatus = '/sleep/status';
  static const String sleepWeek = '/sleep/week';

  // Score
  static const String scoreCurrent = '/score/current';
  static const String scoreHistory = '/score/history';
  static const String scoreRecompute = '/score/recompute';

  // ── Headers ───────────────────────────────────────────────────
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
  static const String contentType = 'application/json';
}
