import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';

class MainShell extends StatelessWidget {
  /// Coquille de navigation gardant chaque onglet vivant (IndexedStack).
  final StatefulNavigationShell navigationShell;

  /// Gabarit de la barre de navigation : 92 px + 12 px de marge basse.
  ///
  /// Ne comprend **pas** la barre système Android : en bord à bord, celle-ci
  /// s'ajoute par-dessous et varie selon l'appareil (geste ou 3 boutons).
  /// Préférer [heightOf] partout où un contexte est disponible.
  static const double bottomBarHeight = 104;

  /// Hauteur réellement occupée par la barre de navigation sur cet appareil.
  ///
  /// **À dégager par tout élément ancré en bas d'un écran du shell.** Comme
  /// [Scaffold.extendBody] vaut `true`, le contenu des onglets s'étend
  /// *derrière* la barre : un bouton flottant posé au ras du bas se retrouve
  /// masqué. Les listes, elles, utilisent une marge basse de 120 px.
  static double heightOf(BuildContext context) =>
      bottomBarHeight + MediaQuery.viewPaddingOf(context).bottom;

  const MainShell({super.key, required this.navigationShell});

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    // initialLocation: true → un re-tap sur l'onglet courant le ramène à sa
    // racine (comportement standard des bottom-navs).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le contenu (AnimatedBranchContainer) est fourni par le
      // navigatorContainerBuilder du StatefulShellRoute : il empile toutes
      // les branches (gardées vivantes) et cross-fade vers l'onglet actif.
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: _GlassNavBar(
        selectedIndex: navigationShell.currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _GlassNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _GlassNavBar({required this.selectedIndex, required this.onTap});

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar> {
  static const _items = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Accueil'),
    _NavItem(
      Icons.fitness_center_rounded,
      Icons.fitness_center_outlined,
      'Séances',
    ),
    _NavItem(
      Icons.accessibility_new_rounded,
      Icons.accessibility_new_outlined,
      'Progression',
    ),
    // « Coaching » couvre deux choses : des coachs HUMAINS qu'on suit dans la
    // durée, et un coach IA disponible à toute heure. Une bulle de dialogue ne
    // disait que « messagerie » — or l'onglet contient un annuaire, des suivis
    // et un assistant.
    //
    // `support_agent` (une personne avec un casque) dit « quelqu'un qui
    // t'accompagne » : c'est le seul glyphe Material qui porte l'idée
    // d'accompagnement plutôt que celle de conversation, et il reste juste pour
    // les deux natures de coaching. Aucune icône ne dit « humain ET IA » à elle
    // seule ; c'est la carte du hub qui fait cette distinction, à l'endroit où
    // l'adhérent choisit.
    _NavItem(
      Icons.support_agent_rounded,
      Icons.support_agent_outlined,
      'Coaching',
    ),
    _NavItem(
      Icons.restaurant_rounded,
      Icons.restaurant_menu_outlined,
      'Nutrition',
    ),
  ];

  /// Applique le flou d'arrière-plan sauf sur le web (où BackdropFilter
  /// casse le mouse tracker et bloque les clics).
  Widget _maybeBlur(Widget child) {
    if (kIsWeb) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: child,
    );
  }

  /// Index de l'onglet central mis en avant (Progression), rendu comme un
  /// bouton flottant surélevé au lieu d'un item classique de la barre.
  static const int _centerIndex = 2;

  @override
  Widget build(BuildContext context) {
    // En bord à bord, la fenêtre passe SOUS la barre de gestes Android : sans
    // ce dégagement, la barre en verre se retrouverait à cheval dessus.
    final systemInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + systemInset),
      // Un peu de hauteur en plus pour laisser le bouton central déborder
      // au-dessus de la barre (Stack sans clipping).
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Barre en verre ────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                // Pas de BackdropFilter sur le web (bug mouse tracker qui bloque
                // les clics) : la barre est déjà quasi opaque (alpha 0.85).
                child: _maybeBlur(
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.bottomBar.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      ),
                      // Les ombres restent SOUS la barre. Une lueur portée
                      // vers le haut (offset négatif + grand flou) peignait
                      // une bande au-dessus, qui masquait le contenu qu'on
                      // doit justement voir défiler derrière.
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: AppColors.isDark ? 0.4 : 0.12,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        // L'onglet central laisse un espace : le bouton flottant
                        // vient se positionner au-dessus (voir plus bas).
                        if (i == _centerIndex) {
                          return const Expanded(child: SizedBox());
                        }
                        return Expanded(
                          child: _NavBarItem(
                            item: _items[i],
                            isSelected: widget.selectedIndex == i,
                            onTap: () => widget.onTap(i),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bouton central surélevé + animé ───────────────────
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _CenterNavButton(
                  item: _items[_centerIndex],
                  isSelected: widget.selectedIndex == _centerIndex,
                  onTap: () => widget.onTap(_centerIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton central « Progression » : le bouton **est** l'indicateur.
///
/// L'anneau qui l'entoure affiche le score d'entraînement de la semaine, si
/// bien que sa lueur traduit une donnée réelle au lieu d'être décorative — et
/// que l'onglet annonce ce qu'il contient avant même d'être ouvert.
class _CenterNavButton extends ConsumerStatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  ConsumerState<_CenterNavButton> createState() => _CenterNavButtonState();
}

class _CenterNavButtonState extends ConsumerState<_CenterNavButton>
    with TickerProviderStateMixin {
  /// Remplissage de l'anneau : joué une fois à l'arrivée du score, puis à
  /// chaque recalcul.
  late final AnimationController _fillCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fill = CurvedAnimation(
    parent: _fillCtrl,
    curve: Curves.easeOutCubic,
  );

  /// Point lumineux qui parcourt l'anneau en boucle lente. Il ne repeint qu'un
  /// `CustomPaint` de 72 px — aucun layout — donc la barre reste vivante sans
  /// le coût d'un dégradé plein écran animé en permanence.
  late final AnimationController _sweepCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  double _target = 0;
  bool _pressed = false;

  @override
  void dispose() {
    _fillCtrl.dispose();
    _sweepCtrl.dispose();
    super.dispose();
  }

  /// Réarme l'animation quand le score change (première arrivée ou recalcul).
  void _syncTo(double value) {
    if (value == _target) return;
    _target = value;
    _fillCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(profileProvider.select((s) => s.score?.score));
    final ratio = ((score ?? 0) / 100).clamp(0.0, 1.0);
    if (ratio != _target) {
      // Relancer une animation pendant le build est interdit : on attend la
      // fin de la frame courante.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTo(ratio);
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: Listenable.merge([_fill, _sweepCtrl]),
        builder: (context, _) {
          final filled = _target * _fill.value;
          final scale = _pressed ? 0.92 : (widget.isSelected ? 1.06 : 1.0);
          // Respiration douce, calée sur le passage du point lumineux.
          final breath = 0.5 - 0.5 * math.cos(_sweepCtrl.value * 2 * math.pi);

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 74,
              height: 74,
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  progress: filled,
                  sweep: _sweepCtrl.value,
                  track: AppColors.glassBorder,
                  // Fond assombri : redonne au bouton l'effet « découpé »
                  // dans la barre, sans anneau opaque qui flotterait.
                  backplate: AppColors.background.withValues(alpha: 0.55),
                ),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Dégradé radial décentré : la lumière tombe d'en haut
                      // à gauche, le bouton se lit comme une bille et non
                      // comme une pastille plate.
                      gradient: const RadialGradient(
                        center: Alignment(-0.35, -0.45),
                        radius: 1.1,
                        colors: [
                          AppColors.primaryLight,
                          AppColors.primary,
                          AppColors.accentDark,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.28 + 0.22 * filled + 0.10 * breath,
                          ),
                          blurRadius: 16 + 6 * breath,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha:
                                (0.10 + 0.14 * filled) * (0.5 + 0.5 * breath),
                          ),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.item.activeIcon,
                      color: AppColors.onGradient,
                      size: 27,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Anneau de score autour du bouton central.
///
/// Quatre passes : un fond assombri qui « découpe » le bouton dans la barre,
/// la piste sourde du score restant, l'arc rempli en dégradé de marque, puis
/// un point lumineux qui **parcourt cet arc** en boucle.
///
/// Le point est ce qui rend le bouton vivant, et il reste porteur de sens : il
/// balaie la portion acquise du score, pas un cercle décoratif. Score à 0, il
/// fait le tour de la piste — le bouton respire même sans donnée.
class _ScoreRingPainter extends CustomPainter {
  /// Part de l'anneau remplie, 0.0 → 1.0.
  final double progress;

  /// Position du point lumineux le long de l'arc, 0.0 → 1.0 en boucle.
  final double sweep;
  final Color track;
  final Color backplate;

  const _ScoreRingPainter({
    required this.progress,
    required this.sweep,
    required this.track,
    required this.backplate,
  });

  static const double _stroke = 3.5;
  static const double _start = -math.pi / 2; // midi

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Fond plein plutôt qu'un anneau opaque : l'anneau flottait au-dessus de
    // la barre sans rien détacher, le disque redonne l'effet « découpé ».
    canvas.drawCircle(center, radius + 1, Paint()..color = backplate);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        _start,
        2 * math.pi * progress,
        false,
        Paint()
          ..shader = const SweepGradient(
            startAngle: _start,
            endAngle: _start + 2 * math.pi,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
              AppColors.accent,
            ],
            transform: GradientRotation(_start),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _stroke,
      );
    }

    // ── Point lumineux ────────────────────────────────────────────
    // Il court sur l'arc rempli, ou sur toute la piste tant qu'aucun score
    // n'est arrivé. Il naît et meurt en fondu : sans ça, le retour au début
    // de la boucle se verrait comme un saut.
    final fade = math.sin(math.pi * sweep);
    if (fade <= 0.01) return;

    const cometSpan = 0.42; // radians
    final travel = 2 * math.pi * (progress > 0.02 ? progress : 1.0);
    final head = _start + travel * sweep;
    final tail = math.max(_start, head - cometSpan);

    canvas.drawArc(
      rect,
      tail,
      head - tail,
      false,
      Paint()
        ..color = AppColors.accentLight.withValues(alpha: 0.85 * fade)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + 1.5 * fade),
    );
    canvas.drawCircle(
      center + Offset(math.cos(head), math.sin(head)) * radius,
      _stroke * 0.9,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress ||
      old.sweep != sweep ||
      old.track != track ||
      old.backplate != backplate;
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;

  const _NavItem(this.activeIcon, this.icon, this.label);
}

class _NavBarItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.isSelected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_NavBarItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with animated indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glow background
                  if (_glowAnim.value > 0)
                    Container(
                      width: 44 * _glowAnim.value,
                      height: 32 * _glowAnim.value,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primary.withValues(
                          alpha: 0.15 * _glowAnim.value,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: 0.2 * _glowAnim.value,
                            ),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  // Icon
                  Transform.scale(
                    scale: _scaleAnim.value,
                    child: Icon(
                      widget.isSelected
                          ? widget.item.activeIcon
                          : widget.item.icon,
                      color: widget.isSelected
                          ? AppColors.primary
                          : AppColors.textHint,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTextStyles.labelSmall.copyWith(
                  color: widget.isSelected
                      ? AppColors.primary
                      : AppColors.textHint,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  fontSize: widget.isSelected ? 11 : 10,
                ),
                child: Text(widget.item.label),
              ),
            ],
          );
        },
      ),
    );
  }
}
