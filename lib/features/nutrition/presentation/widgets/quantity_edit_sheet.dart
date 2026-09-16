import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/meal_model.dart';

/// Ajustement de la quantité d'une entrée **issue du catalogue**.
///
/// L'aperçu affiché pendant le réglage est extrapolé localement à partir des
/// valeurs déjà enregistrées (règle de trois sur la quantité initiale), pour un
/// retour instantané. La valeur définitive reste celle que **le serveur**
/// recalcule à la validation : c'est lui qui détient les valeurs pour 100 g.
Future<void> showQuantityEditSheet(
  BuildContext context, {
  required MealModel meal,

  /// Renvoie `null` en cas de succès, sinon le message d'erreur à afficher.
  required Future<String?> Function(double grams) onConfirm,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuantityEditSheet(meal: meal, onConfirm: onConfirm),
  );
}

class _QuantityEditSheet extends StatefulWidget {
  final MealModel meal;
  final Future<String?> Function(double grams) onConfirm;

  const _QuantityEditSheet({required this.meal, required this.onConfirm});

  @override
  State<_QuantityEditSheet> createState() => _QuantityEditSheetState();
}

class _QuantityEditSheetState extends State<_QuantityEditSheet> {
  static const double _sliderMax = 500;

  late double _grams = widget.meal.quantityGrams ?? 100;
  bool _submitting = false;

  /// Quantité d'origine : sert de base à l'extrapolation de l'aperçu.
  late final double _baseGrams = widget.meal.quantityGrams ?? 100;

  int get _previewCalories =>
      _extrapolate(widget.meal.calories.toDouble()).round();

  double _extrapolate(double value) {
    if (_baseGrams <= 0) return value;
    return value * _grams / _baseGrams;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    final error = await widget.onConfirm(_grams);
    if (!mounted) return;

    if (error != null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: AppTextStyles.bodyMedium),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ajuster la quantité', style: AppTextStyles.headingMedium),
            const SizedBox(height: 4),
            Text(
              widget.meal.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_previewCalories',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'kcal',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quantité', style: AppTextStyles.labelMedium),
                Text(
                  '${_grams.round()} g',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.accentText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: 0.18),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _grams.clamp(5, _sliderMax),
                min: 5,
                max: _sliderMax,
                divisions: ((_sliderMax - 5) / 5).round(),
                onChanged: (v) => setState(() => _grams = v.roundToDouble()),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? 'Enregistrement…' : 'Enregistrer',
              icon: Icons.check_rounded,
              gradient: AppColors.accentGradient,
              glowColor: AppColors.accent,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
