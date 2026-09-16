import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Loader premium FitForge AI — 3 anneaux rotatifs avec glow.
class AppLoader extends StatefulWidget {
  final String? message;
  final double size;

  const AppLoader({super.key, this.message, this.size = 64});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with TickerProviderStateMixin {
  late final AnimationController _ring1;
  late final AnimationController _ring2;
  late final AnimationController _ring3;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _ring2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _ring3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                AnimatedBuilder(
                  animation: _ring1,
                  builder: (context, child) => Transform.rotate(
                    angle: _ring1.value * 2 * 3.14159,
                    child: CircularProgressIndicator(
                      value: 0.7,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.8),
                      ),
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
                // Middle ring
                SizedBox(
                  width: size * 0.72,
                  height: size * 0.72,
                  child: AnimatedBuilder(
                    animation: _ring2,
                    builder: (context, child) => Transform.rotate(
                      angle: -_ring2.value * 2 * 3.14159 * 0.8,
                      child: CircularProgressIndicator(
                        value: 0.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent.withValues(alpha: 0.7),
                        ),
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                ),
                // Inner dot pulsing
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    width: size * 0.22 + _pulse.value * 6,
                    height: size * 0.22 + _pulse.value * 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.heroGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.5 + _pulse.value * 0.3,
                          ),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 20),
            Text(
              widget.message!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textHint,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
