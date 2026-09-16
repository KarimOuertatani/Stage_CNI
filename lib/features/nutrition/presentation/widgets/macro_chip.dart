import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Pastille compacte d'un macronutriment : une puce de couleur + la valeur.
///
/// Composant partagé par la recherche d'aliments, l'aperçu de quantité et les
/// cartes de repas, pour que le code couleur (P / G / L / F) soit strictement
/// le même partout dans l'app.
class MacroChip extends StatelessWidget {
  /// Initiale affichée : `P`, `G`, `L` ou `F`.
  final String letter;

  /// Valeur en grammes.
  final double grams;

  final Color color;

  /// Version dense (listes de résultats) ou aérée (aperçu).
  final bool compact;

  const MacroChip({
    super.key,
    required this.letter,
    required this.grams,
    required this.color,
    this.compact = true,
  });

  /// Arrondi lisible : une décimale sous 10 g, entier au-delà.
  String get _value {
    if (grams >= 10 || grams == 0) return '${grams.round()}';
    return grams.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark ? 0.16 : 0.13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter,
            style: AppTextStyles.caption.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            '$_value g',
            style: AppTextStyles.caption.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Les trois macros principales alignées (protéines, glucides, lipides),
/// avec les fibres en option quand la donnée existe.
class MacroChipRow extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final bool compact;

  const MacroChipRow({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: 6,
      children: [
        MacroChip(
          letter: 'P',
          grams: protein,
          color: AppColors.macroProtein,
          compact: compact,
        ),
        MacroChip(
          letter: 'G',
          grams: carbs,
          color: AppColors.macroCarbs,
          compact: compact,
        ),
        MacroChip(
          letter: 'L',
          grams: fat,
          color: AppColors.macroFat,
          compact: compact,
        ),
        // Les fibres sont absentes de nombreux aliments USDA : on n'affiche la
        // pastille que si la donnée existe réellement.
        if (fiber != null && fiber! > 0)
          MacroChip(
            letter: 'F',
            grams: fiber!,
            color: AppColors.macroFiber,
            compact: compact,
          ),
      ],
    );
  }
}
