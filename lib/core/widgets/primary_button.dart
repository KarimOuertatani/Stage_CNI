import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Bouton principal FitForge — dégradé, élévation colorée, réaction au toucher.
///
/// ## Le halo ne pulse plus (30 juillet 2026)
///
/// Il pulsait **en permanence**, sur les 19 écrans qui utilisent ce bouton.
/// Trois problèmes :
///
/// - **du bruit visuel** : un élément qui bouge sans raison attire l'œil en
///   continu, et un écran où tout clignote n'a plus de hiérarchie ;
/// - **un `AnimationController` qui tourne pour rien**, sur chaque écran, en
///   permanence — donc une image recomposée 60 fois par seconde sans que rien
///   ne change à l'écran ;
/// - **une esthétique datée** : le halo pulsant est un code « gamer », pas un
///   code de finition.
///
/// Le halo est désormais **fixe et riche** (deux couches, comme
/// `AppDepth`), et il **s'intensifie au toucher**. Le mouvement répond à
/// l'utilisateur au lieu de s'agiter tout seul — c'est ce qui distingue une
/// interface soignée d'une interface qui en fait trop.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final Color? glowColor;
  final Gradient? gradient;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.glowColor,
    this.gradient,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  /// Un seul contrôleur, et il ne tourne **que pendant l'appui**.
  ///
  /// Entrée vive (110 ms) pour que le bouton réponde sous le doigt, retour plus
  /// posé (240 ms) : un retour aussi rapide que l'aller donne une impression de
  /// claquement.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 240),
  );

  late final Animation<double> _amount = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _press.forward();
  void _onTapUp(TapUpDetails _) => _press.reverse();
  void _onTapCancel() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final effectiveGradient = widget.gradient ?? AppColors.heroGradient;
    final glowColor = widget.glowColor ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _amount,
      builder: (context, _) {
        final t = _amount.value.clamp(0.0, 1.0);
        return Transform.scale(
          // 0,975 et non 0,95 : un bouton pleine largeur qui rétrécit de 5 %
          // se décolle visiblement de ses marges. À 2,5 %, on sent l'appui
          // sans voir la mise en page bouger.
          scale: 1 - 0.025 * t,
          child: GestureDetector(
            onTapDown: enabled ? _onTapDown : null,
            onTapUp: enabled ? _onTapUp : null,
            onTapCancel: enabled ? _onTapCancel : null,
            onTap: enabled ? widget.onPressed : null,
            child: Container(
              width: widget.width ?? double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: enabled ? effectiveGradient : null,
                color: enabled ? null : AppColors.textDisabled,
                borderRadius: BorderRadius.circular(16),
                // Trois couches, même grammaire que `AppDepth` : un contact
                // sombre et serré, puis deux halos colorés de portées
                // différentes. Le halo seul ferait flotter le bouton sans le
                // poser ; le contact seul le collerait au fond.
                //
                // `t` intensifie l'ensemble à l'appui : le bouton s'éclaire
                // sous le doigt au lieu de simplement rétrécir.
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: AppColors.isDark ? 0.30 : 0.08,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.42 + t * 0.22),
                          blurRadius: 22 + t * 10,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.20 + t * 0.14),
                          blurRadius: 44 + t * 14,
                          spreadRadius: -4,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shimmer effect quand loading.
                  // Positioned.fill : l'overlay remplit la taille du bouton
                  // (définie par le Row) au lieu de la FORCER via SizedBox.expand
                  // — sinon, sous des contraintes non bornées (frame de largeur 0
                  // au démarrage sur certains appareils Android/Impeller), il
                  // exigeait une hauteur infinie et cassait tout le rendu.
                  if (widget.isLoading)
                    const Positioned.fill(
                      child: _ShimmerOverlay(borderRadius: 16),
                    ),
                  // Content
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isLoading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.onGradient,
                            strokeCap: StrokeCap.round,
                          ),
                        )
                      else ...[
                        if (widget.icon != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            widget.icon,
                            color: AppColors.onGradient,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.label,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.onGradient,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay shimmer animé pour le bouton en loading.
class _ShimmerOverlay extends StatefulWidget {
  final double borderRadius;
  const _ShimmerOverlay({required this.borderRadius});

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox.expand(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-2.0 + _ctrl.value * 4, 0),
                  end: Alignment(-1.0 + _ctrl.value * 4, 0),
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bouton secondaire outline avec glow au hover.
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.borderColor,
    this.textColor,
    this.width,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bColor = widget.borderColor ?? AppColors.border;
    final tColor = widget.textColor ?? AppColors.textSecondary;

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: _hovered ? bColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? AppColors.primary.withValues(alpha: 0.6) : bColor,
            width: 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: tColor, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: AppTextStyles.labelMedium.copyWith(color: tColor),
            ),
          ],
        ),
      ),
    );
  }
}
