import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/meal_model.dart';

/// Libellé français d'un moment de repas.
String mealTypeLabel(MealType type) => switch (type) {
  MealType.breakfast => 'Petit-déj',
  MealType.lunch => 'Déjeuner',
  MealType.snack => 'Collation',
  MealType.dinner => 'Dîner',
};

/// Icône associée à un moment de repas.
IconData mealTypeIcon(MealType type) => switch (type) {
  MealType.breakfast => Icons.coffee_outlined,
  MealType.lunch => Icons.lunch_dining_outlined,
  MealType.snack => Icons.cookie_outlined,
  MealType.dinner => Icons.dinner_dining_outlined,
};

/// Couleur associée à un moment de repas.
///
/// Elle suit la **lumière du jour** : ambre au petit-déjeuner, cyan en pleine
/// journée, violet le soir. Ce n'est pas un code arbitraire à mémoriser — on
/// reconnaît le moment sans lire le libellé.
///
/// Sert de teinte à l'ombre des cartes du journal : une liste de repas cesse
/// d'être une pile de rectangles gris et se lit comme une journée.
Color mealTypeColor(MealType type) => switch (type) {
  MealType.breakfast => AppColors.warning,
  MealType.lunch => AppColors.accent,
  MealType.snack => AppColors.success,
  MealType.dinner => AppColors.primary,
};

/// Ordre d'affichage : l'ordre chronologique de la journée.
const List<MealType> orderedMealTypes = [
  MealType.breakfast,
  MealType.lunch,
  MealType.snack,
  MealType.dinner,
];

/// Sélecteur du moment de repas (petit-déj / déjeuner / collation / dîner).
///
/// Extrait en composant partagé : la recherche d'aliment et la saisie manuelle
/// doivent proposer exactement le même sélecteur.
class MealTypeChips extends StatelessWidget {
  final MealType selected;
  final ValueChanged<MealType> onChanged;

  const MealTypeChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in orderedMealTypes) ...[
          Expanded(
            child: _Chip(
              label: mealTypeLabel(type),
              icon: mealTypeIcon(type),
              selected: selected == type,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(type);
              },
            ),
          ),
          if (type != orderedMealTypes.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : AppColors.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: AppColors.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.onGradient : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: selected
                    ? AppColors.onGradient
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
