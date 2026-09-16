import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Logo des écrans d'authentification : le disque, son halo pulsant, et un
/// **anneau lumineux qui tourne** autour.
///
/// ## L'anneau, c'est le détail qui fait la différence
///
/// Un logo qui pulse est un effet connu, et un peu daté : la lueur grandit et
/// rétrécit, mais rien ne se passe. L'anneau ajoute un mouvement **continu et
/// directionnel** — l'œil suit quelque chose, au lieu de regarder respirer.
///
/// Il est dessiné avec un [SweepGradient] : la couleur du trait varie sur le
/// tour du cercle, du transparent au vif. Un anneau de couleur uniforme qui
/// tourne serait invisible (rien ne distingue une position d'une autre) — c'est
/// le **dégradé** qui rend la rotation perceptible.
///
/// ## Deux animations séparées, à dessein
///
/// La pulsation (3 s, va-et-vient) et la rotation (6 s, continue) ont des
/// périodes et des natures différentes. Synchronisées, elles se liraient comme
/// un seul effet mécanique ; désynchronisées, elles donnent une impression
/// d'objet vivant.
///
/// Respecte [MediaQueryData.disableAnimations] : logo et halo statiques, sans
/// rotation.
class AuthLogo extends StatefulWidget {
  /// Diamètre du disque. L'anneau et le halo s'y adaptent proportionnellement.
  final double size;

  /// Dégradé du disque. Violet à la connexion, cyan à l'inscription — les deux
  /// écrans restent ainsi distinguables d'un coup d'œil.
  final Gradient gradient;

  /// Couleur du halo et de l'anneau.
  final Color glowColor;

  const AuthLogo({
    super.key,
    this.size = 100,
    this.gradient = AppColors.heroGradient,
    this.glowColor = AppColors.primary,
  });

  @override
  State<AuthLogo> createState() => _AuthLogoState();
}

class _AuthLogoState extends State<AuthLogo> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // L'anneau déborde du disque : la boîte doit être plus grande, sinon il est
    // rogné.
    final boxSize = widget.size * 1.28;

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── L'anneau tournant ──────────────────────────────────
          if (!reduced)
            SizedBox(
              width: boxSize,
              height: boxSize,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => Transform.rotate(
                  angle: _spin.value * 2 * math.pi,
                  child: CustomPaint(
                    painter: _RingPainter(color: widget.glowColor),
                  ),
                ),
              ),
            ),

          // ── Le disque et son halo ──────────────────────────────
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final p = reduced ? 0.5 : _pulse.value;
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withValues(
                        alpha: 0.40 + p * 0.28,
                      ),
                      blurRadius: 30 + p * 20,
                      spreadRadius: 2 + p * 6,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: EdgeInsets.all(widget.size * 0.16),
                    child: Image.asset(
                      'assets/images/App_Logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Anneau au trait dégradé, dessiné en un seul cercle.
///
/// Le [SweepGradient] va du transparent au vif puis retourne au transparent :
/// on voit donc une **traînée lumineuse** parcourir l'anneau, et non un cercle
/// plein qui tourne — ce dernier serait strictement immobile à l'œil.
class _RingPainter extends CustomPainter {
  final Color color;

  _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Le trait est centré sur le rayon : on retire sa demi-épaisseur pour que
    // l'anneau ne soit pas rogné par les bords de la boîte.
    final radius = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0),
          ],
          // La traînée n'occupe que le dernier quart du tour : une traînée
          // longue ferait un anneau presque complet, donc immobile à l'œil.
          stops: const [0, 0.55, 0.82, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
