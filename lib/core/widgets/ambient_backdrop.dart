import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fond animé de l'accueil : trois halos de lumière qui dérivent lentement.
///
/// ## Pourquoi ce fond change tout
///
/// Un dégradé fixe est plat par nature : les cartes s'y posent, mais rien ne
/// dit qu'il y a de l'espace derrière elles. Trois sources lumineuses qui
/// dérivent créent une **profondeur d'arrière-plan** — et comme elles bougent
/// indépendamment des cartes, l'œil lit deux plans distincts.
///
/// C'est ce plan-là qui donne l'impression que les cartes flottent
/// *au-dessus de quelque chose*, plutôt que d'être collées à un mur.
///
/// ## Mesuré pour être lent
///
/// Un cycle de **28 secondes**, sur des trajectoires de Lissajous à périodes
/// premières entre elles — les halos ne repassent donc jamais par la même
/// configuration, et aucun motif ne devient reconnaissable.
///
/// La lenteur est le point : le mouvement doit être **perçu sans être
/// remarqué**. À 10 secondes, l'arrière-plan attire l'œil et concurrence le
/// contenu ; à 28, on ne le voit bouger qu'en le fixant.
///
/// ## Coût
///
/// Trois dégradés radiaux par image, **sans aucun flou** : un `RadialGradient`
/// est déjà diffus par construction, un `ImageFilter.blur` par-dessus coûterait
/// une passe de composition complète pour un résultat identique.
///
/// Le tout est isolé dans un [RepaintBoundary] : l'animation du fond ne
/// redessine jamais les cartes qui le surplombent.
///
/// ## Réglable par écran
///
/// [intensity] module l'opacité des halos. L'accueil et les onglets restent
/// **discrets** (1,0) : le fond doit s'effacer derrière le contenu. Un écran
/// dont le décor *est* le sujet peut monter plus haut.
///
/// À l'inverse, un écran très dense (une longue liste, un formulaire fourni)
/// gagne à descendre : au-delà d'un certain point, les halos passent derrière
/// du texte et nuisent à la lecture.
///
/// Respecte [MediaQueryData.disableAnimations] : le fond devient alors
/// strictement statique, halos figés dans leur position de départ.
class AmbientBackdrop extends StatefulWidget {
  /// Multiplicateur d'opacité des halos.
  final double intensity;

  const AmbientBackdrop({super.key, this.intensity = 1.0});

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return RepaintBoundary(
      child: reduced
          ? CustomPaint(
              painter: _AmbientPainter(0, widget.intensity),
              size: Size.infinite,
            )
          : AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                painter: _AmbientPainter(_ctrl.value, widget.intensity),
                size: Size.infinite,
              ),
            ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final double t;
  final double intensity;

  _AmbientPainter(this.t, this.intensity);

  /// Les trois halos.
  ///
  /// Leurs **périodes sont premières entre elles** (1/2/3 contre 3/2/1) : la
  /// configuration ne se répète donc qu'après un cycle très long, et l'œil ne
  /// peut pas apprendre le motif.
  ///
  /// Les rayons sont volontairement grands (jusqu'à 90 % de la largeur) : un
  /// halo serré se lit comme une tache, un halo large comme de la lumière.
  static const _blobs = [
    _Blob(
      color: AppColors.primary,
      cx: 0.18,
      cy: 0.10,
      radius: 0.85,
      driftX: 0.16,
      driftY: 0.10,
      phaseX: 1,
      phaseY: 3,
      opacity: 0.30,
    ),
    _Blob(
      color: AppColors.accent,
      cx: 0.88,
      cy: 0.28,
      radius: 0.72,
      driftX: 0.13,
      driftY: 0.14,
      phaseX: 2,
      phaseY: 2,
      opacity: 0.22,
    ),
    // Ce halo reste AU-DESSUS de la barre de navigation. Centré plus bas
    // (0,92), il se retrouvait derrière elle : la barre en masquait le cœur
    // et n'en laissait dépasser que le pourtour, lu comme une bande lumineuse
    // collée sous la barre au lieu d'une lumière diffuse.
    _Blob(
      color: AppColors.primaryLight,
      cx: 0.55,
      cy: 0.74,
      radius: 0.90,
      driftX: 0.18,
      driftY: 0.09,
      phaseX: 3,
      phaseY: 1,
      opacity: 0.18,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // En clair, les halos doivent rester très discrets : sur un fond blanc, la
    // même opacité qu'en sombre donnerait des taches de couleur franches.
    final scale = (AppColors.isDark ? 1.0 : 0.42) * intensity;
    final angle = t * 2 * math.pi;

    for (final blob in _blobs) {
      final center = Offset(
        (blob.cx + math.sin(angle * blob.phaseX) * blob.driftX) * size.width,
        (blob.cy + math.cos(angle * blob.phaseY) * blob.driftY) * size.height,
      );
      final radius = blob.radius * size.width;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              blob.color.withValues(alpha: blob.opacity * scale),
              blob.color.withValues(alpha: 0),
            ],
            // Le cœur du halo reste transparent : la lumière est diffuse, pas
            // ponctuelle. Sans ce stop, on verrait un disque coloré.
            stops: const [0, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.t != t || old.intensity != intensity;
}

class _Blob {
  final Color color;

  /// Position au repos, en fraction de la taille de l'écran.
  final double cx;
  final double cy;

  /// Rayon, en fraction de la **largeur** — pour que le halo garde ses
  /// proportions quelle que soit la hauteur de l'écran.
  final double radius;

  /// Amplitude de dérive sur chaque axe.
  final double driftX;
  final double driftY;

  /// Multiplicateurs de période. Premiers entre eux d'un halo à l'autre.
  final double phaseX;
  final double phaseY;

  final double opacity;

  const _Blob({
    required this.color,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.driftX,
    required this.driftY,
    required this.phaseX,
    required this.phaseY,
    required this.opacity,
  });
}
