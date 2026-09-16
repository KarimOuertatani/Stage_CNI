import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/meal_photo_models.dart';
import 'macro_chip.dart';

/// Carte d'un aliment proposé par une analyse automatique.
///
/// Partagée par l'analyse de **photo** et l'ajout **vocal** : les deux
/// produisent exactement le même objet ([AnalyzedFood]) et doivent offrir
/// exactement les mêmes gestes — cocher, régler la quantité, voir les macros
/// se recalculer en direct.
///
/// Deux partis pris d'interface qui comptent :
/// - **Le libellé du catalogue est toujours affiché** sous le nom compris.
///   C'est le seul moyen pour l'adhérent de repérer un mauvais rapprochement
///   (« tomate » → « Tomate en poudre ») et de le décocher.
/// - **Un aliment non résolu reste visible**, grisé et non cochable : il a
///   bien été compris, mais aucune base ne le connaît. Le faire disparaître
///   donnerait l'impression que le modèle ne l'a pas vu.
class AnalyzedFoodCard extends StatelessWidget {
  final AnalyzedFood food;
  final double grams;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<double> onGramsChanged;

  const AnalyzedFoodCard({
    super.key,
    required this.food,
    required this.grams,
    required this.selected,
    required this.onToggle,
    required this.onGramsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final preview = food.previewFor(grams);
    final usable = food.matched;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.55)
              : AppColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Opacity(
        opacity: usable ? 1 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (usable)
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.accentGradient : null,
                        color: selected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: selected
                              ? Colors.transparent
                              : AppColors.textHint,
                          width: 1.6,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: AppColors.onGradient,
                            )
                          : null,
                    ),
                  )
                else
                  Icon(
                    Icons.help_outline_rounded,
                    size: 22,
                    color: AppColors.textHint,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalize(food.detectedLabel),
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        usable
                            ? (food.foodName ?? '')
                            : 'Non trouvé dans la base nutritionnelle',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (usable) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${preview.calories}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.accentText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'kcal',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (usable) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${grams.round()} g',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (food.confidence != null) ...[
                    const SizedBox(width: 10),
                    _ConfidenceChip(confidence: food.confidence!),
                  ],
                  const Spacer(),
                  MacroChipRow(
                    protein: preview.protein,
                    carbs: preview.carbs,
                    fat: preview.fat,
                    fiber: preview.fiber,
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: selected
                      ? AppColors.accent
                      : AppColors.textDisabled,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: selected
                      ? AppColors.accent
                      : AppColors.textDisabled,
                  overlayColor: AppColors.accent.withValues(alpha: 0.18),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: grams.clamp(5, 600),
                  min: 5,
                  max: 600,
                  divisions: (600 - 5) ~/ 5,
                  onChanged: (v) => onGramsChanged(v.roundToDouble()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Indice de confiance du modèle, en trois paliers lisibles.
///
/// Un nombre entre 0 et 1 ne dit rien à personne ; « incertain » se comprend
/// d'un coup d'œil et invite à vérifier la ligne.
class _ConfidenceChip extends StatelessWidget {
  final double confidence;
  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      >= 0.8 => ('sûr', AppColors.successText),
      >= 0.5 => ('probable', AppColors.warningText),
      _ => ('incertain', AppColors.errorText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color, fontSize: 9),
      ),
    );
  }
}
