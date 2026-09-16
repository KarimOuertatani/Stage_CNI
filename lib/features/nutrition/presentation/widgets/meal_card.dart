import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/meal_model.dart';
import 'macro_chip.dart';
import 'meal_type_chips.dart';

/// Carte d'un aliment du journal.
///
/// Affiche la quantité réellement consommée et les macros calculées. Pour une
/// entrée issue du catalogue, un bouton permet d'**ajuster les grammes** :
/// le serveur recalcule alors toutes les valeurs (voir
/// `PATCH /nutrition/{id}/quantity`). Une saisie manuelle n'a pas ce bouton,
/// puisqu'il n'existe pas de valeurs de référence pour 100 g.
class MealCard extends StatelessWidget {
  final MealModel meal;

  /// Ouvre l'ajustement de quantité (entrées issues du catalogue uniquement).
  final VoidCallback? onEditQuantity;

  /// Supprime l'entrée du journal.
  final VoidCallback? onDelete;

  const MealCard({
    super.key,
    required this.meal,
    this.onEditQuantity,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(meal.id),
      // Glissement vers la gauche uniquement : on ne supprime jamais par erreur
      // en balayant dans le sens de la navigation.
      direction: onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) async => await _confirmDelete(context) ?? false,
      onDismissed: (_) => onDelete?.call(),
      child: SolidCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16.0),
        borderRadius: 18,
        // Teinte = couleur du moment de repas. Le journal se lit alors comme
        // une journée (ambre le matin, violet le soir) au lieu d'une pile de
        // lignes identiques.
        tintColor: mealTypeColor(meal.type),
        lightEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    mealTypeIcon(meal.type),
                    color: AppColors.accentText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      _quantityLine(),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${meal.calories}',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.accentText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'kcal',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            MacroChipRow(
              protein: meal.protein.toDouble(),
              carbs: meal.carbs.toDouble(),
              fat: meal.fat.toDouble(),
              fiber: meal.fiber > 0 ? meal.fiber.toDouble() : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne sous le nom : quantité consommée, et bouton d'ajustement quand
  /// l'entrée provient du catalogue.
  Widget _quantityLine() {
    final grams = meal.quantityGrams;

    if (grams == null || grams <= 0) {
      // Ancienne saisie manuelle sans quantité : on retombe sur l'heure.
      return Text(
        meal.time,
        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
      );
    }

    final text = '${grams.round()} g';
    if (!meal.isFromCatalog || onEditQuantity == null) {
      return Text(
        text,
        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
      );
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onEditQuantity!();
      },
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accentText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.tune_rounded, size: 13, color: AppColors.accentText),
          ],
        ),
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(right: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: AppColors.errorText,
        size: 24,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Supprimer cet aliment ?',
          style: AppTextStyles.headingSmall,
        ),
        content: Text(
          '« ${meal.name} » sera retiré de votre journal.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
