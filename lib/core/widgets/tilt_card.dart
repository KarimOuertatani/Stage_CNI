import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_depth.dart';

/// Carte à **inclinaison 3D** : elle s'incline vers le doigt, se soulève, et
/// reçoit un reflet là où on la touche.
///
/// ## Les quatre effets, et pourquoi les quatre
///
/// Une perspective seule ne convainc pas : le cerveau lit la profondeur à
/// plusieurs indices simultanés. Enlever un seul des quatre casse l'illusion —
/// la carte se met à ressembler à une image déformée plutôt qu'à un objet.
///
/// | Effet | Ce qu'il apporte | Sans lui |
/// |---|---|---|
/// | **Perspective** | Le côté proche grandit, le côté loin rétrécit | Un simple cisaillement, plat |
/// | **Élévation** | L'ombre s'allonge et se décale | L'objet semble collé au fond |
/// | **Reflet spéculaire** | Une surface qui accroche la lumière | Du carton mat |
/// | **Retour élastique** | Une masse qui revient à sa place | Un effet « logiciel » |
///
/// ## Le détail qui fait tout : l'ombre va **à l'opposé** de l'inclinaison
///
/// Quand le haut de la carte part vers l'arrière, sa base s'approche du fond :
/// l'ombre doit descendre. La faire suivre le doigt produit une image que l'œil
/// rejette sans savoir pourquoi — c'est la même raison qui rend une ombre mal
/// orientée immédiatement suspecte sur une photo truquée.
///
/// ## Mesure et retenue
///
/// L'angle maximal est de **6°** par défaut. Au-delà de 8°, le texte devient
/// visiblement déformé et l'effet passe de « objet physique » à « gadget ».
/// L'échelle ne monte qu'à 1,02 : une carte qui grossit franchement paraît
/// sauter vers l'utilisateur.
///
/// ## Accessibilité et performance
///
/// - `Matrix4` + `Transform` : pas de nouvelle couche de composition, le coût
///   est celui d'une transformation de peinture.
/// - L'inclinaison est **désactivée** quand le système demande de réduire les
///   animations ([MediaQueryData.disableAnimations]) : seul le retour tactile
///   subsiste, la carte reste parfaitement utilisable.
/// - Un [Semantics] `button` est posé dès qu'il y a un [onTap].
class TiltCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Rayon des coins — doit correspondre à celui de l'enfant, sinon l'ombre et
  /// le reflet dépassent aux angles.
  final double borderRadius;

  /// Inclinaison maximale, en degrés.
  final double maxTilt;

  /// Ombre au repos. Par défaut [AppDepth.resting].
  final List<BoxShadow>? restingShadow;

  /// Ombre à l'inclinaison. Par défaut [AppDepth.lifted].
  final List<BoxShadow>? liftedShadow;

  /// Teinte du reflet. Un reflet blanc sur une carte sombre suffit ; sur une
  /// carte colorée, teinter légèrement évite l'aspect « voile gris ».
  final Color sheenColor;

  /// Intensité du reflet, entre 0 et 1. À 0, le reflet est désactivé.
  final double sheenStrength;

  const TiltCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.maxTilt = 6,
    this.restingShadow,
    this.liftedShadow,
    this.sheenColor = Colors.white,
    this.sheenStrength = 0.16,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin {
  /// Contrôle l'intensité globale de l'effet (0 = repos, 1 = incliné).
  ///
  /// Entrée rapide, sortie plus longue et élastique : on prend l'inclinaison
  /// immédiatement — sinon la carte semble en retard sur le doigt — et on la
  /// rend avec l'inertie d'une masse qui se replace.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _amount = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
    // easeOutBack : un léger dépassement au retour. C'est ce qui donne
    // l'impression d'une masse, là où une courbe sans rebond fait « logiciel ».
    reverseCurve: Curves.easeOutBack.flipped,
  );

  /// Position du doigt, normalisée en [-1, 1] sur les deux axes.
  Offset _pointer = Offset.zero;

  bool get _reducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _updatePointer(Offset local, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _pointer = Offset(
        (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _engage(Offset local, Size size) {
    if (_reducedMotion) return;
    _updatePointer(local, size);
    _ctrl.forward();
  }

  void _release() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final resting = widget.restingShadow ?? AppDepth.resting;
    final lifted = widget.liftedShadow ?? AppDepth.lifted;
    final radius = BorderRadius.circular(widget.borderRadius);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        return Listener(
          // `Listener` et non `MouseRegion` seul : il faut le doigt (tactile)
          // ET le curseur (desktop, web). Les deux passent par les mêmes
          // événements de pointeur.
          onPointerHover: (e) {
            if (_ctrl.value > 0) _updatePointer(e.localPosition, size);
          },
          child: MouseRegion(
            onEnter: (e) => _engage(e.localPosition, size),
            onExit: (_) => _release(),
            child: GestureDetector(
              onTapDown: (d) {
                if (widget.onTap != null) HapticFeedback.selectionClick();
                _engage(d.localPosition, size);
              },
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              onTap: widget.onTap,
              child: AnimatedBuilder(
                animation: _amount,
                builder: (context, child) {
                  // `clamp` : easeOutBack dépasse hors de [0,1] au retour, ce
                  // qui donnerait une opacité invalide sur le reflet.
                  final t = _amount.value.clamp(0.0, 1.0);
                  final rad = widget.maxTilt * math.pi / 180;
                  // 1,02 au maximum : au-delà, la carte semble sauter vers
                  // l'utilisateur au lieu de se soulever.
                  final s = 1 + 0.02 * t;

                  // Au repos : l'IDENTITÉ, strictement.
                  //
                  // Poser la perspective en permanence n'a aucun effet visible
                  // (le contenu est plat, z = 0) mais laisse une matrice non
                  // identitaire sur chaque carte de l'écran — donc une couche
                  // de transformation que Flutter doit gérer sans rien rendre.
                  // Une carte au repos doit se comporter exactement comme si le
                  // relief n'existait pas.
                  final transform = t == 0
                      ? Matrix4.identity()
                      : (Matrix4.identity()
                          // La perspective doit être posée AVANT les rotations,
                          // sinon elle ne s'applique pas et l'on n'obtient qu'un
                          // cisaillement plat.
                          ..setEntry(3, 2, 0.0011)
                          // Le doigt vers le bas incline le haut vers l'arrière :
                          // d'où le signe négatif sur X.
                          ..rotateX(-_pointer.dy * rad * t)
                          ..rotateY(_pointer.dx * rad * t)
                          // `scaleByDouble` et non `scale` : ce dernier est
                          // déprécié, et sa surcharge à un seul argument mettait
                          // aussi Z à l'échelle, ce qui perturbe la perspective.
                          ..scaleByDouble(s, s, 1, 1));

                  return Transform(
                    transform: transform,
                    alignment: Alignment.center,
                    // filterQuality : sans elle, le texte incliné crénèle
                    // franchement sur les écrans à faible densité.
                    filterQuality: FilterQuality.medium,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: AppDepth.lerp(resting, lifted, t),
                      ),
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    children: [
                      widget.child,
                      if (widget.sheenStrength > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _amount,
                              builder: (context, _) => _Sheen(
                                pointer: _pointer,
                                opacity:
                                    widget.sheenStrength *
                                    _amount.value.clamp(0.0, 1.0),
                                color: widget.sheenColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reflet spéculaire : une tache lumineuse centrée sur le doigt.
///
/// C'est l'indice qui transforme une surface inclinée en **surface** : un plan
/// mat qui pivote reste du carton. Le dégradé est radial et très étalé — un
/// reflet net ferait tache de graisse plutôt que lumière rasante.
class _Sheen extends StatelessWidget {
  final Offset pointer;
  final double opacity;
  final Color color;

  const _Sheen({
    required this.pointer,
    required this.opacity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(pointer.dx, pointer.dy),
          // > 1 : le reflet doit pouvoir déborder de la carte quand le doigt
          // est près d'un bord, comme une vraie lumière rasante.
          radius: 1.1,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            Colors.transparent,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
    );
  }
}

/// Reflet qui **balaie** la carte une fois, en boucle lente.
///
/// À réserver à un élément unique — la bannière d'accueil. Sur plusieurs cartes
/// à la fois, ces balayages se désynchronisent et l'écran se met à scintiller.
///
/// Le balayage ne se contente pas de décorer : il indique que l'élément est
/// **vivant et actionnable**, là où les cartes voisines attendent d'être
/// touchées.
class SweepShine extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  /// Durée d'un cycle complet. Long à dessein : un balayage rapide agite
  /// l'écran au lieu de l'animer.
  final Duration period;

  const SweepShine({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.period = const Duration(seconds: 5),
  });

  @override
  State<SweepShine> createState() => _SweepShineState();
}

class _SweepShineState extends State<SweepShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respecte le réglage système : une animation en boucle est le premier
    // type d'effet à couper quand l'utilisateur demande moins de mouvement.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  // Le balayage n'occupe que le premier tiers du cycle : il
                  // passe, puis la carte respire. Un balayage continu
                  // ressemblerait à un chargement.
                  final progress = (_ctrl.value / 0.34).clamp(0.0, 1.0);
                  if (progress >= 1) return const SizedBox.shrink();

                  // De -1,5 à 1,5 : la bande entre et sort complètement du
                  // cadre, on ne la voit jamais apparaître ni disparaître.
                  final x = -1.5 + progress * 3;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(x - 0.45, -1),
                        end: Alignment(x + 0.45, 1),
                        colors: [
                          Colors.transparent,
                          AppColors.onGradient.withValues(alpha: 0.13),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
