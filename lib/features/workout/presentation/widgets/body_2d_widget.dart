import 'package:flutter/material.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/workout_model.dart';
import 'muscle_detail_sheet.dart';
import 'muscle_group_3d_mapper.dart'
    show colorFromIntensitySmooth, labelFromIntensity, sameIntensities;
import 'muscle_group_mapper.dart';

/// Silhouette anatomique SVG haute-fidélité en 2D (vue avant + arrière),
/// colorée en heatmap continue selon l'intensité d'entraînement, avec
/// animation de révélation et zones tactiles.
class Body2DWidget extends StatefulWidget {
  final List<MuscleIntensity> intensities;

  const Body2DWidget({super.key, required this.intensities});

  @override
  State<Body2DWidget> createState() => _Body2DWidgetState();
}

class _Body2DWidgetState extends State<Body2DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(covariant Body2DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ne rejoue la révélation que si les données ont réellement changé
    // (pas à chaque rebuild du parent).
    if (!sameIntensities(oldWidget.intensities, widget.intensities)) {
      _animationController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showMuscleDetails(BuildContext context, MuscleInfo muscleInfo) {
    final intensity = MuscleGroupMapper.getMuscleIntensity(
      muscleInfo,
      widget.intensities,
    );
    showMuscleDetailSheet(
      context,
      muscleName: MuscleGroupMapper.getFrenchMuscleName(muscleInfo),
      groupName: MuscleGroupMapper.getFrenchGroupForMuscle(muscleInfo),
      intensity: intensity,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Intensité max pour la lueur d'ambiance derrière les silhouettes.
    final maxIntensity = widget.intensities.isEmpty
        ? 0.0
        : widget.intensities
              .map((e) => e.intensity)
              .reduce((a, b) => a > b ? a : b);
    final glowColor = colorFromIntensitySmooth(maxIntensity);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Table de couleurs animées (heatmap continue) pour chaque muscle.
        final neutral = AppColors.muscleNone;
        final colorMapping = <MuscleInfo, Color>{};
        for (final info in MuscleCatalog.all) {
          final intensity = MuscleGroupMapper.getMuscleIntensity(
            info,
            widget.intensities,
          );
          final targetColor = colorFromIntensitySmooth(intensity);
          colorMapping[info] =
              Color.lerp(neutral, targetColor, _animation.value) ?? neutral;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildFigureCard(
                      context: context,
                      label: 'AVANT',
                      isFront: true,
                      colorMapping: colorMapping,
                      glowColor: glowColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildFigureCard(
                      context: context,
                      label: 'ARRIÈRE',
                      isFront: false,
                      colorMapping: colorMapping,
                      glowColor: glowColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(labelFromIntensity(0), AppColors.muscleNone),
                _buildLegendItem(labelFromIntensity(0.2), AppColors.muscleLow),
                _buildLegendItem(
                  labelFromIntensity(0.45),
                  AppColors.muscleMedium,
                ),
                _buildLegendItem(labelFromIntensity(0.7), AppColors.muscleHigh),
                _buildLegendItem(labelFromIntensity(1), AppColors.muscleMax),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Illustrations sous licence CC BY 4.0 par Ryan Graves',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textHint.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFigureCard({
    required BuildContext context,
    required String label,
    required bool isFront,
    required Map<MuscleInfo, Color> colorMapping,
    required Color glowColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.overline.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surface,
                Color.lerp(
                      AppColors.surface,
                      AppColors.isDark ? Colors.black : AppColors.cardLight,
                      0.15,
                    ) ??
                    AppColors.surface,
              ],
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Lueur d'ambiance en arrière-plan
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          glowColor.withValues(
                            alpha:
                                (AppColors.isDark ? 0.12 : 0.08) *
                                _animation.value,
                          ),
                          glowColor.withValues(alpha: 0.0),
                        ],
                        center: const Alignment(0.0, -0.1),
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),
                // Silhouette SVG du corps
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 8,
                  ),
                  child: BodyAtlasView<MuscleInfo>(
                    view: isFront
                        ? AtlasAsset.musclesFront
                        : AtlasAsset.musclesBack,
                    resolver: const MuscleResolver(),
                    colorMapping: colorMapping,
                    onTapElement: (muscleInfo) =>
                        _showMuscleDetails(context, muscleInfo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: AppColors.isDark ? Colors.white24 : Colors.black12,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
