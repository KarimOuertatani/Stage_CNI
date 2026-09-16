import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/body_part_model.dart';

/// Carte visuelle d'une zone du corps (grille « Parcourir par zone »).
///
/// Illustration officielle ExerciseDB **embarquée en local** (PNG dans
/// `assets/images/bodyparts/`) → affichage fiable, hors-ligne, sans dépendre
/// du CDN. Repli gradient + icône si l'asset manque.
class BodyPartCard extends StatelessWidget {
  final BodyPartModel bodyPart;
  final VoidCallback onTap;

  const BodyPartCard({super.key, required this.bodyPart, required this.onTap});

  /// Chemin de l'asset local dérivé du code de zone (ex : "FULL BODY" ->
  /// assets/images/bodyparts/FULL_BODY.png).
  String get _assetPath =>
      'assets/images/bodyparts/${bodyPart.name.replaceAll(' ', '_')}.png';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                // ── Illustration (fond clair pour lisibilité des schémas) ──
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      _assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => _fallback(),
                    ),
                  ),
                ),
                // ── Libellé + nombre d'exercices ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bodyPart.labelFr,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${bodyPart.exerciseCount} exercice${bodyPart.exerciseCount > 1 ? 's' : ''}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fitness_center_rounded,
        color: AppColors.onGradient,
        size: 36,
      ),
    );
  }
}
