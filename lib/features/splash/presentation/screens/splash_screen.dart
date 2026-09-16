import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/forge_stage.dart';

/// Écran d'accueil animé — et **sas de démarrage** de l'application.
///
/// ## Il répond à un vrai défaut, pas seulement à une envie de décor
///
/// Avant, l'app démarrait sur `/login`. Or la session se rétablit de façon
/// asynchrone (lecture du jeton, puis `GET /me`) : un utilisateur déjà connecté
/// voyait donc l'**écran de connexion apparaître, puis disparaître** dès la
/// réponse du serveur. Le splash tient l'écran pendant ce temps et n'envoie
/// vers la bonne destination qu'une fois la session tranchée.
///
/// ## Deux conditions pour partir, jamais une seule
///
/// La navigation attend **l'animation ET la session** :
///
/// - partir dès la fin de l'animation couperait la vérification du jeton et
///   ferait réapparaître le clignotement qu'on cherche à supprimer ;
/// - partir dès la réponse du serveur tronquerait l'animation à un instant
///   arbitraire — sur une connexion rapide, on ne verrait jamais l'ignition.
///
/// Si le réseau traîne, l'intro se termine et la scène **continue de vivre**
/// (anneaux, halos, jauge) grâce à un second contrôleur en boucle : l'écran
/// n'est jamais figé.
///
/// Et si le serveur ne répond pas du tout, [_safetyDelay] libère l'utilisateur
/// vers `/login`. Ce n'est pas une impasse : quand la session finit par se
/// rétablir, la redirection du routeur le renvoie seule vers l'accueil.
///
/// ## Accessibilité
///
/// Respecte [MediaQueryData.disableAnimations] : l'intro est alors posée
/// directement sur sa dernière image (logo, nom et signature en place), sans
/// aucun mouvement, et l'écran s'efface après un court instant.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// Durée de l'intro. Réglée sur le rythme des beats de [ForgeStage] : plus
  /// court, l'aspiration n'a pas le temps de se lire ; plus long, l'attente
  /// devient perceptible même quand tout est déjà prêt.
  static const _introDuration = Duration(milliseconds: 3000);

  static const _exitDuration = Duration(milliseconds: 520);

  /// Filet de sécurité : au-delà, on part sans attendre la session.
  static const _safetyDelay = Duration(seconds: 8);

  /// Temps laissé au décodage du logo avant de lancer l'animation quand même.
  static const _decodeBudget = Duration(milliseconds: 400);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _introDuration,
  );

  /// Cycle continu, indépendant de l'intro : c'est lui qui garde la scène
  /// vivante pendant une éventuelle attente réseau.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: _exitDuration,
  );

  Timer? _safety;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();

    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leaveIfReady();
    });

    // Le démarrage est lancé après la première image : la toute première frame
    // de Flutter porte le coût d'initialisation du moteur, y démarrer
    // l'animation lui ferait sauter ses premières dizaines de millisecondes.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

      // Le logo est décodé AVANT que l'animation ne commence.
      //
      // `Image.asset` décode de façon asynchrone : sans cette attente, les
      // premières images de la scène s'affichaient sans logo — soit exactement
      // le trou que le raccord avec le splash natif doit éviter. Ici, l'écran
      // reste sur le fond `#080c1a` (identique au splash natif) le temps du
      // décodage : rien ne clignote, et l'aspiration part logo en place.
      // L'attente est **bornée** : un décodage anormalement lent ne doit pas
      // pouvoir retarder le démarrage de l'app indéfiniment. Passé ce délai on
      // lance l'animation sans attendre — le logo se posera de lui-même dès
      // qu'il sera prêt.
      await precacheImage(
        const AssetImage('assets/images/App_Logo.png'),
        context,
        // Un logo introuvable ne doit pas bloquer le démarrage non plus.
        onError: (_, _) {},
      ).timeout(_decodeBudget, onTimeout: () {});
      if (!mounted) return;

      if (reduced) {
        _spin.stop();
        _intro.value = 1;
        // `value = 1` ne déclenche pas le statusListener : on relaie à la main.
        Future.delayed(const Duration(milliseconds: 600), _leaveIfReady);
      } else {
        _intro.forward();
      }

      _safety = Timer(_safetyDelay, _leaveNow);
    });
  }

  @override
  void dispose() {
    _safety?.cancel();
    _intro.dispose();
    _spin.dispose();
    _exit.dispose();
    super.dispose();
  }

  /// Part **si** l'intro est finie et la session tranchée.
  void _leaveIfReady() {
    if (!mounted || _leaving) return;
    if (_intro.value < 1) return;
    if (!ref.read(authProvider).isBootstrapped) return;
    _leaveNow();
  }

  void _leaveNow() {
    if (!mounted || _leaving) return;
    _leaving = true;
    _safety?.cancel();

    _exit.forward().whenComplete(() {
      if (!mounted) return;
      context.go(_destination());
    });
  }

  /// Où atterrir. Même règle que les redirections du routeur : le coach a son
  /// propre espace, l'adhérent l'accueil, l'anonyme la connexion.
  String _destination() {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return '/login';
    return auth.user?.role == 'COACH' ? '/coach' : '/home';
  }

  @override
  Widget build(BuildContext context) {
    // La session peut se trancher avant OU après la fin de l'intro : on écoute
    // les deux côtés, chacun rappelant la même garde.
    ref.listen(authProvider, (_, next) {
      if (next.isBootstrapped) _leaveIfReady();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // La scène est sombre quel que soit le thème : les icônes système
      // doivent être claires, même si l'utilisateur a choisi le mode clair.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        // Le fond du Scaffold porte la couleur du THÈME, pas celle de la scène.
        // C'est lui qu'on découvre en fondu à la sortie : la bascule vers un
        // écran clair se fait alors en douceur au lieu d'un à-coup.
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: _exit,
          builder: (context, child) {
            final e = Curves.easeInCubic.transform(_exit.value);
            return Opacity(
              opacity: 1 - e,
              // Léger zoom : la scène « avance » vers l'utilisateur en
              // s'effaçant, comme si l'app s'ouvrait à travers elle.
              child: Transform.scale(scale: 1 + 0.10 * e, child: child),
            );
          },
          child: _buildStage(),
        ),
      ),
    );
  }

  Widget _buildStage() {
    final timeline = Listenable.merge([_intro, _spin]);

    return Stack(
      children: [
        // ── Le décor ────────────────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: timeline,
            builder: (context, _) =>
                ForgeBackdrop(t: _intro.value, spin: _spin.value),
          ),
        ),

        // ── L'emblème, aligné sur le foyer du décor ─────────────────
        Align(
          alignment: ForgeStage.focusAlignment,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: timeline,
              builder: (context, _) =>
                  ForgeEmblem(t: _intro.value, spin: _spin.value),
            ),
          ),
        ),

        // ── Le nom et la signature ──────────────────────────────────
        Align(
          alignment: const Alignment(0, 0.30),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ForgeWordmark(t: _intro.value),
                  const SizedBox(height: 14),
                  ForgeTagline(t: _intro.value),
                ],
              ),
            ),
          ),
        ),

        // ── La jauge ────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 64,
          child: Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: timeline,
                builder: (context, _) =>
                    ForgeProgress(t: _intro.value, spin: _spin.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
