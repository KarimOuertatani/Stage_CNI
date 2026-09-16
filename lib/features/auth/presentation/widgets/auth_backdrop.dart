import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Fond animé des écrans d'authentification.
///
/// ## Pourquoi un seul widget pour les deux écrans
///
/// Connexion et inscription portaient chacun **leur propre copie** du fond :
/// un `AnimatedBuilder` sur un dégradé radial, plus deux ou trois
/// `_FloatingOrb` positionnés à la main, avec des couleurs et des phases
/// différentes. Résultat : passer d'un écran à l'autre faisait **sauter** le
/// décor, et toute retouche devait être faite deux fois.
///
/// Un seul fond, une seule définition : la transition entre les deux écrans
/// devient continue.
///
/// ## Ce que ça affiche
///
/// Quatre halos qui dérivent en **22 secondes** sur des trajectoires à périodes
/// premières entre elles, plus une **vignette** qui assombrit les bords.
///
/// La vignette n'est pas décorative : sans elle, les halos touchent les coins de
/// l'écran et l'image se lit comme un fond d'écran. En refermant la lumière vers
/// le centre, elle **dirige le regard** vers le formulaire — exactement ce qu'on
/// veut sur un écran qui n'a qu'une seule chose à faire faire.
///
/// ## Plus marqué que sur l'accueil, et c'est voulu
///
/// L'accueil doit s'effacer derrière le contenu ; ici, le fond **est** le
/// contenu. Les halos sont donc plus opaques et plus rapides
/// (22 s contre 28 s) — mais toujours assez lents pour ne pas gêner la lecture
/// d'un champ de saisie.
///
/// Respecte [MediaQueryData.disableAnimations] : halos figés, vignette
/// conservée.
class AuthBackdrop extends StatefulWidget {
  const AuthBackdrop({super.key});

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
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
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.background),
        child: reduced
            ? CustomPaint(painter: _AuthPainter(0), size: Size.infinite)
            : AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: _AuthPainter(_ctrl.value),
                  size: Size.infinite,
                ),
              ),
      ),
    );
  }
}

class _AuthPainter extends CustomPainter {
  final double t;

  _AuthPainter(this.t);

  /// Les quatre halos.
  ///
  /// Deux violets et deux cyan, répartis aux quatre coins de l'écran : la
  /// composition reste équilibrée quelle que soit la position de la dérive.
  /// Trois halos laissaient un angle systématiquement sombre.
  static const _blobs = [
    _Blob(
      color: AppColors.primary,
      cx: 0.15,
      cy: 0.08,
      r: 0.95,
      dx: 0.18,
      dy: 0.12,
      px: 1,
      py: 3,
      opacity: 0.42,
    ),
    _Blob(
      color: AppColors.accent,
      cx: 0.90,
      cy: 0.22,
      r: 0.70,
      dx: 0.14,
      dy: 0.16,
      px: 2,
      py: 2,
      opacity: 0.30,
    ),
    _Blob(
      color: AppColors.primaryLight,
      cx: 0.80,
      cy: 0.88,
      r: 0.85,
      dx: 0.16,
      dy: 0.11,
      px: 3,
      py: 1,
      opacity: 0.26,
    ),
    _Blob(
      color: AppColors.accentDark,
      cx: 0.10,
      cy: 0.78,
      r: 0.75,
      dx: 0.12,
      dy: 0.14,
      px: 2,
      py: 3,
      opacity: 0.22,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // En thème clair, les mêmes opacités donneraient des taches de couleur
    // franches sur fond blanc — illisible derrière un formulaire.
    final scale = AppColors.isDark ? 1.0 : 0.38;
    final angle = t * 2 * math.pi;

    for (final blob in _blobs) {
      final center = Offset(
        (blob.cx + math.sin(angle * blob.px) * blob.dx) * size.width,
        (blob.cy + math.cos(angle * blob.py) * blob.dy) * size.height,
      );
      final radius = blob.r * size.width;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              blob.color.withValues(alpha: blob.opacity * scale),
              blob.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // ── La vignette ────────────────────────────────────────────────
    // Elle referme la lumière vers le centre et dirige le regard vers le
    // formulaire. Sans elle, les halos touchent les coins et l'écran se lit
    // comme un fond d'écran plutôt que comme une scène éclairée.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: AppColors.isDark ? 0.55 : 0.10),
        ],
        // 0,45 : la zone claire couvre le formulaire, l'assombrissement ne
        // commence qu'au-delà.
        stops: const [0.45, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_AuthPainter old) => old.t != t;
}

class _Blob {
  final Color color;
  final double cx;
  final double cy;

  /// Rayon en fraction de la **largeur** : les proportions du halo ne changent
  /// pas d'un écran allongé à un écran large.
  final double r;
  final double dx;
  final double dy;

  /// Multiplicateurs de période, premiers entre eux d'un halo à l'autre.
  final double px;
  final double py;

  final double opacity;

  const _Blob({
    required this.color,
    required this.cx,
    required this.cy,
    required this.r,
    required this.dx,
    required this.dy,
    required this.px,
    required this.py,
    required this.opacity,
  });
}
