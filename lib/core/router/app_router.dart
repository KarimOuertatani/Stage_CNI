import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/workout/presentation/screens/workout_hub_screen.dart';
import '../../features/workout/presentation/screens/body_progress_screen.dart';
import '../../features/workout/data/workout_log_args.dart';
import '../../features/workout/presentation/screens/workout_log_screen.dart';
import '../../features/workout/presentation/screens/workout_history_screen.dart';
import '../../features/workout/presentation/screens/exercise_detail_screen.dart';
import '../../features/workout/presentation/screens/exercises_by_body_part_screen.dart';
import '../../features/workout/presentation/screens/exercises_by_muscle_screen.dart';
import '../../features/programs/data/program_models.dart';
import '../../features/programs/presentation/screens/ai_program_wizard_screen.dart';
import '../../features/programs/presentation/screens/create_program_screen.dart';
import '../../features/programs/presentation/screens/program_detail_screen.dart';
import '../../features/coaching/presentation/screens/coaching_hub_screen.dart';
import '../../features/coaching/presentation/screens/coach_detail_screen.dart';
import '../../features/coaching/presentation/screens/chat_screen.dart';
import '../../features/coaching/presentation/screens/ai_coach_screen.dart';
import '../../features/coaching/presentation/screens/conversations_screen.dart';
import '../../features/coaching/presentation/screens/coach_application_screen.dart';
import '../../features/coaching/presentation/screens/coach_gate.dart';
import '../../features/coaching/presentation/screens/coach_profile_edit_screen.dart';
import '../../features/coaching/presentation/screens/coach_client_screen.dart';
import '../../features/coaching/data/coaching_models.dart';
import '../../features/nutrition/presentation/screens/meal_photo_screen.dart';
import '../../features/nutrition/presentation/screens/meal_voice_screen.dart';
import '../../features/nutrition/presentation/screens/meals_screen.dart';
import '../../features/sleep/presentation/screens/sleep_screen.dart';
import '../../features/profile/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/support/presentation/screens/my_reports_screen.dart';
import '../../features/support/presentation/screens/report_problem_screen.dart';
import '../../shared/navigation/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Transition fondu + léger slide pour les écrans hors onglets
/// (auth, logging de séance).
CustomTransitionPage<void> _fadePage(
  GoRouterState state,
  Widget child, {
  Offset begin = const Offset(0, 0.04),
  Duration duration = const Duration(milliseconds: 320),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // IMPORTANT : on ne fait PAS ref.watch(authProvider) ici, sinon le GoRouter
  // serait recréé à chaque changement d'auth et repartirait de /login (ce qui
  // écrasait la navigation vers /onboarding après l'inscription). À la place,
  // on rafraîchit les redirections via un refreshListenable et on lit l'état
  // d'auth à la demande avec ref.read.
  final refresh = _AuthRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;

      // Le splash se redirige LUI-MÊME, une fois son animation terminée ET la
      // session tranchée (voir SplashScreen). Le laisser passer par les règles
      // ci-dessous le renverrait vers /login à la première évaluation — soit
      // avant même que la vérification du jeton ait répondu, exactement le
      // clignotement que cet écran supprime.
      if (path == '/splash') return null;
      // /verify-email fait partie du parcours d'entrée : on y arrive AVANT
      // d'être authentifié (le compte existe mais n'est pas encore activé),
      // il ne doit donc pas être renvoyé vers /login.
      final isLoggingIn =
          path == '/login' || path == '/signup' || path == '/verify-email';
      final auth = ref.read(authProvider);
      final isAuthenticated = auth.isAuthenticated;
      final isCoach = auth.user?.role == 'COACH';

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // Ancienne route de la visualisation corporelle → onglet Progression.
      if (path == '/workout/body-progress') {
        return '/progress';
      }

      if (isAuthenticated) {
        // Espace réservé au coach (attention : /coaches/... est adhérent).
        final inCoachSpace = path == '/coach' || path.startsWith('/coach/');
        final inChat =
            path.startsWith('/chat') || path.startsWith('/conversations');

        // Signaler un problème est ouvert aux DEUX rôles : c'est la seule
        // porte de sortie quand quelque chose est cassé, y compris dans
        // l'espace coach. L'exclure de la garde ci-dessous renverrait un
        // coach vers son tableau de bord au moment précis où il essaie de
        // nous dire que ce tableau de bord ne marche pas.
        final inSupport =
            path == '/signaler' || path.startsWith('/signalements');

        if (isCoach) {
          // Le coach reste dans son espace (dashboard + chats), mais peut
          // aussi composer/éditer les programmes (routes /programs*).
          final inPrograms = path.startsWith('/programs');
          if (!inCoachSpace && !inChat && !inPrograms && !inSupport) {
            return '/coach';
          }
        } else {
          // L'adhérent n'accède pas à l'espace coach.
          if (inCoachSpace) return '/home';
          // Déjà connecté et de retour sur /login → accueil. On NE force PAS
          // depuis /signup (enchaîne volontairement vers /onboarding).
          if (path == '/login') return '/home';
        }
      }
      return null;
    },
    routes: [
      // ── Splash : premier écran, sas de restauration de session ────────
      //
      // Sans transition d'entrée : il prend la relève du splash natif, qui
      // affiche déjà le même fond et le même logo. Un fondu ici ferait
      // clignoter le raccord.
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => _fadePage(state, const SignupScreen()),
      ),

      // ── Vérification d'email : code à 6 chiffres après l'inscription ──
      GoRoute(
        path: '/verify-email',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? const {};
          return _fadePage(
            state,
            VerifyEmailScreen(
              email: (args['email'] as String?) ?? '',
              isCoach: args['isCoach'] as bool? ?? false,
            ),
          );
        },
      ),

      // ── Onboarding : formulaire de profil juste après l'inscription ──
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingScreen()),
      ),

      // ── Profil : plein écran, hors shell (accessible depuis l'accueil) ──
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const ProfileScreen()),
      ),

      // ── Nutrition : analyse d'une photo de repas, hors shell ──────────
      GoRoute(
        path: '/nutrition/photo',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const MealPhotoScreen()),
      ),

      // ── Nutrition : ajout d'un repas à la voix, hors shell ────────────
      GoRoute(
        path: '/nutrition/voice',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const MealVoiceScreen()),
      ),

      // ── Sommeil : historique par semaine, plein écran ─────────────────
      GoRoute(
        path: '/sleep',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(state, const SleepScreen()),
      ),

      // ── Programmes : écrans plein écran, hors shell ───────────────────
      GoRoute(
        path: '/programs/new',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const CreateProgramScreen()),
      ),
      // Assistant de génération par l'IA. Déclaré AVANT /programs/detail/:id
      // et /programs/edit/:id : go_router essaie les routes dans l'ordre, et
      // un chemin littéral doit passer avant tout motif qui pourrait le
      // capturer.
      GoRoute(
        path: '/programs/ai',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const AiProgramWizardScreen()),
      ),
      GoRoute(
        path: '/programs/edit/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          CreateProgramScreen(existing: state.extra as ProgramModel?),
        ),
      ),
      GoRoute(
        path: '/programs/detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ProgramDetailScreen(programId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/programs/template/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ProgramDetailScreen(
            programId: state.pathParameters['id'] ?? '',
            isTemplate: true,
          ),
        ),
      ),

      // ── Coaching : profils, chat et espace coach (plein écran) ────────
      GoRoute(
        path: '/coaches/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          CoachDetailScreen(coachUserId: state.pathParameters['userId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/conversations',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const ConversationsScreen()),
      ),

      // ── Coach IA : conversation plein écran, hors shell ───────────────
      GoRoute(
        path: '/coach-ai',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const AiCoachScreen()),
      ),
      GoRoute(
        path: '/chat/:relationshipId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ChatScreen(
            relationshipId: state.pathParameters['relationshipId'] ?? '',
          ),
        ),
      ),
      // ── Espace coach ────────────────────────────────────────────────
      //
      // /coach passe par CoachGate et NON directement par CoachShell : depuis
      // la mise en place de la validation par l'administration, un coach dont
      // le dossier n'est pas approuve doit voir sa candidature, pas un tableau
      // de bord vide. La decision depend d'un appel serveur, donc d'un widget
      // et non de la fonction `redirect` (qui est synchrone) — voir CoachGate.
      GoRoute(
        path: '/coach',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(state, const CoachGate()),
      ),
      // Acces direct au dossier, y compris pour un coach deja valide qui
      // voudrait relire ce qu'il a envoye.
      GoRoute(
        path: '/coach/application',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const CoachApplicationScreen()),
      ),
      GoRoute(
        path: '/coach/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const CoachProfileEditScreen(firstTime: true)),
      ),
      GoRoute(
        path: '/coach/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const CoachProfileEditScreen()),
      ),
      GoRoute(
        path: '/coach/member/:memberUserId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          CoachClientScreen(
            memberUserId: state.pathParameters['memberUserId'] ?? '',
            relationship: state.extra as CoachingRelationship?,
          ),
        ),
      ),
      GoRoute(
        path: '/coach/member/:memberUserId/new-program',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          CreateProgramScreen(
            forMemberUserId: state.pathParameters['memberUserId'],
            forMemberName: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/coach/program/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ProgramDetailScreen(
            programId: state.pathParameters['id'] ?? '',
            coachMode: true,
          ),
        ),
      ),

      // ── Signalement d'un probleme : ouvert aux DEUX roles ─────────────
      //
      // Ces routes ne sont volontairement pas rattachees a l'espace adherent
      // ni a l'espace coach : les deux en ont l'usage, et les dupliquer aurait
      // donne deux ecrans a maintenir pour une seule difference — le role de
      // l'auteur, que le serveur deduit tout seul du jeton.
      GoRoute(
        path: '/signaler',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const ReportProblemScreen()),
      ),
      GoRoute(
        path: '/signalements',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const MyReportsScreen()),
      ),

      // ── Historique des séances : plein écran, hors shell ──────────────
      GoRoute(
        path: '/workout/history',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _fadePage(state, const WorkoutHistoryScreen()),
      ),

      // ── Exercices d'une zone du corps (plein écran) ──────────────────
      GoRoute(
        path: '/workout/bodypart/:name',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ExercisesByBodyPartScreen(
            bodyPart: Uri.decodeComponent(state.pathParameters['name'] ?? ''),
            labelFr: state.extra as String? ?? 'Exercices',
          ),
        ),
      ),

      // ── Exercices d'un groupe musculaire (depuis la silhouette 2D/3D) ────
      GoRoute(
        path: '/workout/muscle/:group',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ExercisesByMuscleScreen(
            muscleGroup: Uri.decodeComponent(
              state.pathParameters['group'] ?? '',
            ),
          ),
        ),
      ),

      // ── Détail d'un exercice : vidéo de démo + instructions (plein écran) ──
      GoRoute(
        path: '/workout/exercise/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          ExerciseDetailScreen(exerciseId: state.pathParameters['id'] ?? ''),
        ),
      ),

      // ── Logging de séance : plein écran, hors shell (pas de nav bar) ──
      //
      // `extra` porte le contexte de programme (objectifs prescrits, exercices
      // suivants de la séance) quand on arrive depuis un programme. Il reste
      // null quand l'écran est ouvert depuis la bibliothèque — l'écran
      // fonctionne alors avec ses valeurs par défaut.
      GoRoute(
        path: '/workout/log/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadePage(
          state,
          WorkoutLogScreen(
            exerciseId: state.pathParameters['id'] ?? '',
            args: state.extra is WorkoutLogArgs
                ? state.extra as WorkoutLogArgs
                : null,
          ),
          begin: const Offset(0, 0.06),
          duration: const Duration(milliseconds: 360),
        ),
      ),

      // ── Navigation principale à 5 onglets ─────────────────────────────
      //
      // StatefulShellRoute.indexedStack conserve CHAQUE onglet vivant après
      // sa première ouverture (IndexedStack). Conséquence critique : le
      // modèle 3D / la texture Filament de l'onglet Progression n'est créé
      // qu'UNE fois pour toute la session — plus de cycle création/destruction
      // à chaque changement d'onglet (qui provoquait des fuites natives et le
      // crash « l'app quitte après un peu de navigation »). Bonus : bascule
      // d'onglet instantanée, état de scroll/formulaire préservé.
      // On utilise le conteneur intégré IndexedStack : seul l'onglet ACTIF
      // est peint et hit-testé. Cela évite l'assertion réentrante du mouse
      // tracker (curseur qui bloque tous les clics) qu'introduisait un
      // cross-fade manuel (AnimatedOpacity) au-dessus de MouseRegion vivants.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const WorkoutHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const BodyProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coaching',
                builder: (context, state) => const CoachingHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nutrition',
                builder: (context, state) => const MealsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Notifie GoRouter quand l'état d'authentification change, SANS recréer le
/// routeur : la même instance ré-évalue simplement ses redirections. Évite que
/// la navigation vers /onboarding après l'inscription soit écrasée par un
/// routeur fraîchement reconstruit qui repartirait de /login.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}
