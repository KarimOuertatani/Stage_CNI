import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Scène du splash : « la forge ».
///
/// ## L'idée
///
/// Le nom de l'app est *FitForge*. Une forge, ce n'est pas un logo qui apparaît
/// en fondu — c'est de la matière dispersée qu'on **rassemble**, qu'on
/// **comprime** jusqu'au point d'incandescence, et qui **ressort transformée**.
/// Toute l'animation raconte ça, en trois temps :
///
/// | Temps | Ce qu'on voit | Beat |
/// |---|---|---|
/// | **Aspiration** | le logo se contracte, des braises spiralent vers lui | [ForgeStage.gather] |
/// | **Ignition** | tout converge en un point blanc, qui explose | [ForgeStage.ignition] |
/// | **Éclosion** | l'emblème ressort forgé, le nom se dresse lettre à lettre | [ForgeStage.bloom] |
///
/// ## La continuité avec le splash natif
///
/// Le splash natif (`flutter_native_splash`) affiche le logo **nu** sur
/// `#080c1a`. La scène démarre donc exactement là : même fond, même logo nu,
/// immobile. Rien ne saute au moment où Flutter prend la main — l'animation ne
/// commence qu'après, et le disque dégradé de l'emblème n'apparaît qu'à
/// l'ignition. C'est ce qui fait que l'app semble démarrer d'un seul geste au
/// lieu de deux écrans successifs.
///
/// ## Toujours sombre, à dessein
///
/// La scène ignore le thème clair : une ignition sur fond blanc n'a aucun sens
/// physique, et le splash natif est de toute façon sombre dans les deux modes.
/// Les couleurs neutres sont donc figées ici plutôt que prises dans
/// [AppColors] (dont les getters suivent le mode). Seules les couleurs **de
/// marque** — constantes dans les deux modes — sont reprises telles quelles.
/// Le retour au thème de l'utilisateur se fait par le fondu de sortie.
abstract final class ForgeStage {
  /// Hauteur du foyer, en fraction de l'écran. Le fond, le logo et les ondes
  /// s'alignent tous dessus — d'où la constante partagée.
  ///
  /// Volontairement au-dessus du centre optique : le nom et la signature
  /// occupent le bas, et l'ensemble se lit alors comme centré.
  static const focusY = 0.42;

  /// Alignement équivalent à [focusY], pour la couche de widgets.
  static const focusAlignment = Alignment(0, focusY * 2 - 1);

  // ── Les beats de la timeline (fractions de la durée totale) ─────
  /// Début de l'aspiration : avant, le logo est immobile (raccord natif).
  static const gather = 0.16;

  /// L'explosion. Point de bascule de toute l'animation.
  static const ignition = 0.42;

  /// L'emblème a retrouvé sa taille.
  static const bloom = 0.66;

  /// Première lettre du nom.
  static const word = 0.54;

  /// Signature sous le nom.
  static const tagline = 0.74;
}

/// Fond de la scène. Opaque : il recouvre le [Scaffold] (qui, lui, porte la
/// couleur du thème de l'utilisateur et n'est révélé que par le fondu final).
const forgeBackground = Color(0xFF080C1A);

const _forgeInk = Color(0xFFFFFFFF);
const _forgeMuted = Color(0xFF8FA0C4);

/// Position normalisée dans un segment `[a, b]` de la timeline, bornée à
/// `[0, 1]`.
///
/// Toute l'animation est pilotée par **un seul** contrôleur : chaque élément
/// découpe sa propre fenêtre dedans avec cette fonction. Un contrôleur par
/// effet aurait rendu les enchaînements impossibles à régler — ici, décaler un
/// beat décale tout ce qui en dépend.
double seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

// ═══════════════════════════════════════════════════════════════════
//  Fond : halos, disque orbital, braises, noyau, ondes de choc
// ═══════════════════════════════════════════════════════════════════

/// Tout ce qui se peint **derrière** l'emblème, en une seule passe.
///
/// Un [CustomPaint] unique plutôt qu'une pile de widgets animés : les braises
/// seules seraient 72 widgets repositionnés à chaque image. Ici, tout tient
/// dans une liste d'ordres de dessin, et le [RepaintBoundary] isole la scène du
/// reste de l'arbre.
class ForgeBackdrop extends StatelessWidget {
  /// Avancement de l'intro, `0..1`.
  final double t;

  /// Cycle continu (12 s) : dérive des halos, rotation des anneaux. Séparé de
  /// [t] pour que la scène reste **vivante** si l'app attend encore le réseau
  /// après la fin de l'intro.
  final double spin;

  const ForgeBackdrop({super.key, required this.t, required this.spin});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ForgePainter(t: t, spin: spin),
        size: Size.infinite,
      ),
    );
  }
}

/// Une braise aspirée par le foyer.
class _Ember {
  /// Angle de départ sur le disque.
  final double angle;

  /// Distance de départ, en fraction du petit côté de l'écran.
  final double radius;

  /// Nombre de tours parcourus avant d'atteindre le centre. C'est ce qui
  /// transforme une chute rectiligne en **spirale**.
  final double turns;

  /// Retard au départ. Sans lui, les 72 braises partiraient au même instant et
  /// formeraient un anneau qui se referme — un motif, pas une aspiration.
  final double delay;

  /// Épaisseur du trait.
  final double weight;

  /// Position dans le dégradé cyan → violet.
  final double tint;

  const _Ember({
    required this.angle,
    required this.radius,
    required this.turns,
    required this.delay,
    required this.weight,
    required this.tint,
  });
}

/// Graine fixe : la même scène à chaque lancement. Un tirage aléatoire à chaque
/// démarrage donnerait une animation qui ne se règle pas (et un rendu qu'on ne
/// peut pas juger deux fois de suite).
final List<_Ember> _embers = List.generate(72, (_) {
  final r = _emberRandom;
  return _Ember(
    angle: r.nextDouble() * math.pi * 2,
    radius: 0.40 + r.nextDouble() * 0.62,
    turns: 0.85 + r.nextDouble() * 1.35,
    delay: r.nextDouble() * 0.17,
    weight: 0.9 + r.nextDouble() * 1.9,
    tint: r.nextDouble(),
  );
});

final math.Random _emberRandom = math.Random(2024);

class _ForgePainter extends CustomPainter {
  final double t;
  final double spin;

  _ForgePainter({required this.t, required this.spin});

  /// Inclinaison du plan orbital. Sans elle, les braises tomberaient dans un
  /// cercle vu de face — plat. Avec, on lit un **disque en perspective**, et
  /// l'écran gagne une profondeur qu'aucun dégradé ne donne.
  static const _tilt = -0.22;

  /// Écrasement vertical du même plan : le cercle devient ellipse.
  static const _squash = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * ForgeStage.focusY);
    final short = math.min(size.width, size.height);

    _paintBase(canvas, size);
    _paintAurora(canvas, size);

    // Le disque et les braises vivent dans un repère incliné, centré sur le
    // foyer : on l'installe une fois pour les deux.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_tilt);
    _paintDisc(canvas, short);
    _paintEmbers(canvas, short);
    canvas.restore();

    _paintCore(canvas, center, short);
    _paintWaves(canvas, center, short);
  }

  /// Fond opaque + remontée de lumière derrière le foyer.
  void _paintBase(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = forgeBackground);

    // La lumière monte pendant l'aspiration : le fond « chauffe » avant même
    // que quoi que ce soit n'explose.
    final lift = 0.18 + 0.42 * seg(t, 0.10, ForgeStage.ignition + 0.08);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: ForgeStage.focusAlignment,
          radius: 0.85,
          colors: [
            const Color(0xFF2A1B6B).withValues(alpha: lift),
            const Color(0x002A1B6B),
          ],
        ).createShader(rect),
    );
  }

  /// Deux halos qui dérivent, très lents — le même principe que le fond de
  /// l'accueil, en un peu plus present : ici le décor *est* le sujet.
  void _paintAurora(Canvas canvas, Size size) {
    final appear = seg(t, 0.0, 0.35);
    if (appear <= 0) return;

    final angle = spin * 2 * math.pi;
    // Les deux halos restent dans la MOITIÉ HAUTE. Placé bas, celui d'accent
    // teintait tout le bas de l'écran en vert d'eau — une couleur qui n'est
    // pas dans la marque, et qui passait de surcroît derrière le nom.
    const blobs = [
      (color: AppColors.primary, cx: 0.16, cy: 0.18, r: 0.95, ph: 1.0, o: 0.28),
      (color: AppColors.accent, cx: 0.88, cy: 0.32, r: 0.72, ph: 2.0, o: 0.16),
    ];

    for (final b in blobs) {
      final c = Offset(
        (b.cx + math.sin(angle * b.ph) * 0.12) * size.width,
        (b.cy + math.cos(angle * (3 - b.ph)) * 0.08) * size.height,
      );
      final radius = b.r * size.width;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              b.color.withValues(alpha: b.o * appear),
              b.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
  }

  /// Les deux orbites du plan incliné, tracées en [SweepGradient] : la couleur
  /// varie le long du trait, donc la rotation se **voit**. Un anneau uni qui
  /// tourne est strictement immobile à l'œil.
  ///
  /// Dessinées en ovales explicites plutôt qu'en cercles dans un repère
  /// écrasé : `canvas.scale` déformerait aussi l'épaisseur du trait, qui
  /// s'amincirait en haut et en bas de l'ellipse.
  void _paintDisc(Canvas canvas, double short) {
    // Elles s'installent pendant l'aspiration, puis s'effacent à moitié une
    // fois l'emblème présent : à ce moment, c'est lui le sujet.
    final appear =
        seg(t, 0.08, 0.40) * (1 - 0.55 * seg(t, ForgeStage.ignition, 0.85));
    if (appear <= 0) return;

    for (var i = 0; i < 2; i++) {
      final rx = short * (0.33 + i * 0.17);
      final ry = rx * _squash;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: rx * 2,
        height: ry * 2,
      );
      final color = i == 0 ? AppColors.accent : AppColors.primaryLight;

      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 - i * 0.5
          ..shader = SweepGradient(
            transform: GradientRotation(
              spin * 2 * math.pi * (i == 0 ? 1 : -1.6),
            ),
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: 0.55 * appear),
              color.withValues(alpha: 0),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.18, 0.46, 1.0],
          ).createShader(rect),
      );
    }
  }

  /// Les braises : une spirale accélérée vers le foyer, chacune traînant sa
  /// comète.
  void _paintEmbers(Canvas canvas, double short) {
    if (t <= 0) return;

    for (final e in _embers) {
      final u = seg(t, e.delay, ForgeStage.ignition);
      if (u <= 0) continue;

      // easeIn : lentes au loin, avalées à la fin. Une progression linéaire
      // donnerait une pluie régulière, pas une **aspiration**.
      final k = Curves.easeInCubic.transform(u);

      Offset at(double p) {
        final a = e.angle + e.turns * 2 * math.pi * p;
        final r = e.radius * (1 - p) * short;
        return Offset(math.cos(a) * r, math.sin(a) * r * _squash);
      }

      // Apparition en douceur, extinction juste avant le centre : les braises
      // sont absorbées par le noyau, elles ne s'y empilent pas.
      final alpha =
          math.min(1.0, u / 0.12) *
          (1 - seg(k, 0.88, 1.0)) *
          (1 - seg(t, ForgeStage.ignition, ForgeStage.ignition + 0.05));
      if (alpha <= 0.01) continue;

      // La traînée suit la spirale au lieu de la couper.
      //
      // Un simple segment tête↔queue serait la **corde** de l'arc parcouru :
      // sur une trajectoire qui fait plus d'un tour, ça donne des bâtonnets
      // droits jetés en travers de l'écran — c'est le rendu qu'on avait. Cinq
      // points échantillonnés sur la trajectoire suffisent à retrouver la
      // courbe, et la comète redevient lisible comme un mouvement.
      const steps = 4;
      final from = math.max(0.0, k - 0.055);
      final trail = Path();
      for (var i = 0; i <= steps; i++) {
        final o = at(from + (k - from) * (i / steps));
        i == 0 ? trail.moveTo(o.dx, o.dy) : trail.lineTo(o.dx, o.dy);
      }

      final color = Color.lerp(
        AppColors.accent,
        AppColors.primaryLight,
        e.tint,
      )!;

      // La traînée large et faible tient lieu de halo : un vrai flou par
      // braise coûterait 72 passes de composition par image.
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: 0.16 * alpha)
          ..strokeWidth = e.weight * 3.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: 0.9 * alpha)
          ..strokeWidth = e.weight
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// Le noyau qui se charge, puis l'éclair d'ignition.
  void _paintCore(Canvas canvas, Offset center, double short) {
    final charge = seg(t, ForgeStage.gather, ForgeStage.ignition);
    // Le noyau s'éteint VITE : il doit disparaître pendant que l'éclair est
    // encore aveuglant. Prolongé, il restait visible comme une bille blanche
    // posée sur l'emblème qui repousse dessous.
    final alive = 1 - seg(t, ForgeStage.ignition, ForgeStage.ignition + 0.05);

    if (charge > 0 && alive > 0) {
      final r = short * (0.004 + 0.05 * Curves.easeInQuad.transform(charge));
      final halo = r * 7;
      canvas.drawCircle(
        center,
        halo,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.55 * charge * alive),
              AppColors.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: halo)),
      );
      canvas.drawCircle(
        center,
        r,
        Paint()..color = _forgeInk.withValues(alpha: alive),
      );
    }

    // L'éclair : très court, très large. C'est lui qui « cache » le
    // changement d'état du logo (nu → emblème forgé).
    final f = seg(t, ForgeStage.ignition, ForgeStage.ignition + 0.13);
    if (f > 0 && f < 1) {
      final a = math.pow(1 - f, 3).toDouble();
      final r = short * (0.10 + 1.05 * Curves.easeOutCubic.transform(f));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _forgeInk.withValues(alpha: 0.60 * a),
              AppColors.primary.withValues(alpha: 0.22 * a),
              AppColors.primary.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.42, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  /// Trois ondes de choc décalées. Une seule se lirait comme un cercle qui
  /// grandit ; trois, comme une **détonation**.
  void _paintWaves(Canvas canvas, Offset center, double short) {
    const starts = [0.0, 0.07, 0.15];
    for (final s in starts) {
      final from = ForgeStage.ignition + s;
      final u = seg(t, from, from + 0.34);
      if (u <= 0 || u >= 1) continue;

      final r = short * (0.03 + 0.88 * Curves.easeOutCubic.transform(u));
      final fade = math.pow(1 - u, 2.2).toDouble();
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 + 3.4 * fade
          ..color = Color.lerp(
            AppColors.accentLight,
            AppColors.primary,
            s * 4,
          )!.withValues(alpha: 0.5 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_ForgePainter old) => old.t != t || old.spin != spin;
}

// ═══════════════════════════════════════════════════════════════════
//  L'emblème
// ═══════════════════════════════════════════════════════════════════

/// Le logo et son halo : au repos, puis aspiré, puis reforgé.
class ForgeEmblem extends StatelessWidget {
  final double t;
  final double spin;

  const ForgeEmblem({super.key, required this.t, required this.spin});

  /// Diamètre du disque de l'emblème.
  static const disc = 148.0;

  /// Le logo nu, avant/après. Plus petit que le disque : il doit tenir dedans
  /// avec sa marge, sans jamais toucher le bord.
  static const mark = 104.0;

  /// L'anneau déborde largement du disque : la boîte doit lui laisser la place.
  static const box = disc * 1.9;

  @override
  Widget build(BuildContext context) {
    // ── Échelle : 1 → point → 1 avec dépassement ────────────────
    final double scale;
    if (t < ForgeStage.gather) {
      scale = 1;
    } else if (t < ForgeStage.ignition) {
      final u = Curves.easeInCubic.transform(
        seg(t, ForgeStage.gather, ForgeStage.ignition),
      );
      scale = 1 - 0.94 * u;
    } else {
      // easeOutBack dépasse la cible puis revient : l'emblème « rebondit » à
      // l'arrivée. Sans ce dépassement, la sortie de l'explosion serait molle.
      scale =
          0.06 +
          0.94 *
              Curves.easeOutBack.transform(
                seg(t, ForgeStage.ignition, ForgeStage.bloom),
              );
    }

    // Le logo s'éteint juste avant l'ignition (le noyau blanc prend le relais)
    // et se rallume juste après, sous le couvert de l'éclair.
    final markOpacity = t < ForgeStage.ignition
        ? 1 - seg(t, ForgeStage.ignition - 0.10, ForgeStage.ignition)
        : seg(t, ForgeStage.ignition + 0.02, ForgeStage.ignition + 0.11);

    // Le disque dégradé n'existe QUE après la forge : avant, on raccorde au
    // splash natif, qui montre le logo nu.
    //
    // Il se remplit AUSSI VITE que le logo se rallume, sous le couvert de
    // l'éclair : étalé jusqu'à l'éclosion, on voyait une icône délavée grandir
    // avant de devenir un emblème, ce qui donnait un objet à moitié fini.
    final discOpacity = seg(
      t,
      ForgeStage.ignition + 0.02,
      ForgeStage.ignition + 0.11,
    );
    final halo = seg(t, ForgeStage.ignition + 0.06, ForgeStage.bloom + 0.06);

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (halo > 0)
            Positioned.fill(
              child: CustomPaint(
                painter: _HaloPainter(spin: spin, opacity: halo),
              ),
            ),
          Transform.scale(
            scale: scale,
            child: SizedBox(
              width: disc,
              height: disc,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: discOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.heroGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: 0.55 * discOpacity,
                            ),
                            blurRadius: 46,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: markOpacity,
                    child: Image.asset(
                      'assets/images/App_Logo.png',
                      width: mark,
                      height: mark,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deux anneaux contra-rotatifs et trois satellites sur une orbite inclinée.
///
/// La contra-rotation n'est pas un détail : deux anneaux tournant dans le même
/// sens se lisent comme **une** pièce qui tourne. En sens opposés, on lit deux
/// objets distincts — et l'emblème semble tenir dans un mécanisme.
class _HaloPainter extends CustomPainter {
  final double spin;
  final double opacity;

  _HaloPainter({required this.spin, required this.opacity});

  /// Même inclinaison que le disque du fond : les deux plans doivent coïncider.
  static const _tilt = -0.22;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    for (var i = 0; i < 2; i++) {
      final r = size.width / 2 - 3 - i * 16;
      final rect = Rect.fromCircle(center: c, radius: r);
      final color = i == 0 ? AppColors.accent : AppColors.primaryLight;

      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 - i * 1.0
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            transform: GradientRotation(
              spin * 2 * math.pi * (i == 0 ? 1 : -0.7),
            ),
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: 0),
              color.withValues(alpha: 0.85 * opacity),
              color.withValues(alpha: 0),
            ],
            // La traînée n'occupe qu'un quart du tour : plus longue, l'anneau
            // se refermerait et paraîtrait fixe.
            stops: const [0.0, 0.55, 0.82, 1.0],
          ).createShader(rect),
      );
    }

    // ── Satellites ────────────────────────────────────────────────
    final rx = size.width / 2 - 8;
    final ry = rx * 0.34;
    for (var i = 0; i < 3; i++) {
      final a = spin * 2 * math.pi * 1.35 + i * 2 * math.pi / 3;
      final dx = math.cos(a) * rx;
      final dy = math.sin(a) * ry;
      final p =
          c +
          Offset(
            dx * math.cos(_tilt) - dy * math.sin(_tilt),
            dx * math.sin(_tilt) + dy * math.cos(_tilt),
          );

      // 0 = au fond de l'orbite, 1 = au premier plan. Taille et éclat suivent :
      // c'est ce qui fait lire une orbite en 3D plutôt qu'un cercle plat.
      final depth = (math.sin(a) + 1) / 2;
      final radius = 1.5 + 2.3 * depth;

      canvas.drawCircle(
        p,
        radius * 3.4,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.20 * depth * opacity),
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = _forgeInk.withValues(
            alpha: (0.30 + 0.65 * depth) * opacity,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.spin != spin || old.opacity != opacity;
}

// ═══════════════════════════════════════════════════════════════════
//  Le nom, la signature, la jauge
// ═══════════════════════════════════════════════════════════════════

/// « FITFORGE », lettre par lettre, traversé par un éclat.
///
/// Les lettres sont animées **individuellement** avec un décalage de 26 ms :
/// le mot se dresse au lieu d'apparaître. Un fondu global sur le mot entier
/// coûterait le même code et ne raconterait rien.
class ForgeWordmark extends StatelessWidget {
  final double t;

  const ForgeWordmark({super.key, required this.t});

  static const _word = 'FITFORGE';

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: 5,
      height: 1,
      color: _forgeInk,
      shadows: [
        Shadow(
          color: AppColors.primary.withValues(alpha: 0.55),
          blurRadius: 28,
        ),
      ],
    );

    final letters = List.generate(_word.length, (i) {
      final start = ForgeStage.word + i * 0.026;
      final u = Curves.easeOutCubic.transform(seg(t, start, start + 0.22));
      return Opacity(
        opacity: u,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - u)),
          child: Transform.scale(
            scale: 0.80 + 0.20 * u,
            child: Text(_word[i], style: style),
          ),
        ),
      );
    });

    return ShaderMask(
      // srcATop : le dégradé ne teinte QUE les pixels déjà peints par les
      // lettres. Sans ça, le masque remplirait tout le rectangle.
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final p = Curves.easeInOut.transform(seg(t, 0.72, 1.0));
        final x = -0.35 + 1.7 * p;
        // Les arrêts doivent rester strictement croissants dans [0, 1], y
        // compris quand la bande est encore hors du mot.
        final s0 = (x - 0.16).clamp(0.0, 0.96);
        final s1 = x.clamp(s0 + 0.02, 0.98);
        final s2 = (x + 0.16).clamp(s1 + 0.02, 1.0);
        return LinearGradient(
          colors: const [
            _forgeInk,
            _forgeInk,
            AppColors.accentLight,
            _forgeInk,
            _forgeInk,
          ],
          stops: [0.0, s0, s1, s2, 1.0],
        ).createShader(rect);
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: letters),
    );
  }
}

/// Signature. Son interlettrage se **resserre** en apparaissant : le texte
/// semble se poser, au lieu de simplement s'allumer.
class ForgeTagline extends StatelessWidget {
  final double t;

  const ForgeTagline({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final u = Curves.easeOutCubic.transform(
      seg(t, ForgeStage.tagline, ForgeStage.tagline + 0.22),
    );
    if (u <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: u * 0.9,
      child: Text(
        "ENTRAÎNEMENT AUGMENTÉ PAR L'IA",
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.2 + 5 * (1 - u),
          color: _forgeMuted,
        ),
      ),
    );
  }
}

/// Jauge de chargement : un cheveu de 132 px avec une tête lumineuse.
///
/// Elle dit ce qu'aucune animation ne dit — que l'app **travaille**. Quand la
/// session tarde à se rétablir, elle reste pleine et sa tête continue de
/// pulser (via [spin]) : l'écran n'a jamais l'air figé.
class ForgeProgress extends StatelessWidget {
  final double t;
  final double spin;

  const ForgeProgress({super.key, required this.t, required this.spin});

  static const _width = 132.0;

  @override
  Widget build(BuildContext context) {
    final appear = seg(t, 0.08, 0.30);
    if (appear <= 0) return const SizedBox(height: 3, width: _width);

    final fill = Curves.easeInOutCubic.transform(t);
    final pulse = 0.5 + 0.5 * math.sin(spin * 2 * math.pi * 6);

    return Opacity(
      opacity: appear,
      child: SizedBox(
        width: _width,
        height: 3,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _forgeInk.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(width: _width, height: 3),
            ),
            Container(
              width: _width * fill,
              height: 3,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: 0.35 + 0.35 * pulse,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
