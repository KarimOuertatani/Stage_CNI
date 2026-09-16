import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Barre de progression animée avec gradient et glow.
///
/// Anime la valeur de 0 → [value] au premier rendu avec [Curves.easeOutCubic].
class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final double height;
  final Gradient? gradient;
  final Color? color;
  final Color? trackColor;
  final double borderRadius;
  final bool showGlow;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.gradient,
    this.color,
    this.trackColor,
    this.borderRadius = 100,
    this.showGlow = true,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: 0,
      end: widget.value.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.value.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppColors.primaryGradient;
    final trackColor = widget.trackColor ?? AppColors.border;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _anim.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.color == null ? effectiveGradient : null,
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: widget.showGlow && _anim.value > 0.05
                    ? [
                        BoxShadow(
                          color: (widget.color ?? AppColors.primary).withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Anneau de progression circulaire animé avec glow.
class AnimatedRingProgress extends StatefulWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? center;
  final bool showGlow;
  final Duration duration;

  const AnimatedRingProgress({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.color,
    this.trackColor,
    this.center,
    this.showGlow = true,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedRingProgress> createState() => _AnimatedRingProgressState();
}

class _AnimatedRingProgressState extends State<AnimatedRingProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: 0,
      end: widget.value.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedRingProgress old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.value.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    final trackColor = widget.trackColor ?? AppColors.border;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showGlow)
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2 * _anim.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              CircularProgressIndicator(
                value: _anim.value,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: widget.strokeWidth,
                strokeCap: StrokeCap.round,
              ),
              if (widget.center != null) widget.center!,
            ],
          );
        },
      ),
    );
  }
}
