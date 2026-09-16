/// Les briques de l'assistant de génération.
///
/// Elles sont regroupées ici parce qu'elles partagent **une seule règle de
/// dessin** : un choix sélectionné s'éclaire de la couleur d'accent, prend une
/// bordure pleine et une ombre teintée ; un choix disponible reste sourd. Sur
/// un questionnaire de neuf écrans, c'est cette constance qui permet de
/// répondre sans relire — l'œil apprend la règle au premier écran et l'applique
/// aux huit suivants.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Barre de progression segmentée : un segment par étape.
///
/// Préférée à une barre continue parce qu'elle répond à la vraie question de
/// l'adhérent — « combien il en reste ? ». Une barre continue à 62 % ne le dit
/// pas ; six segments pleins sur neuf, si.
class AiWizardProgress extends StatelessWidget {
  final int total;
  final int current; // 0-based

  const AiWizardProgress({
    super.key,
    required this.total,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i <= current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: done ? AppColors.accentGradient : null,
              color: done ? null : AppColors.border,
              boxShadow: i == current
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// L'en-tête d'une étape : la question, puis ce qu'elle sert à décider.
///
/// Le sous-titre n'est pas décoratif. « Ça décide du découpage de ta semaine »
/// sous « Combien de séances ? » transforme une case à remplir en décision
/// comprise — et l'adhérent répond mieux quand il sait à quoi sa réponse sert.
class AiStepHeader extends StatelessWidget {
  final String overline;
  final String title;
  final String subtitle;

  const AiStepHeader({
    super.key,
    required this.overline,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(overline.toUpperCase(), style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Text(title, style: AppTextStyles.headingLarge),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Un choix pleine largeur : icône, libellé, précision, coche.
///
/// Pleine largeur et non en grille : ces choix portent une **précision**
/// (« moins d'un an de pratique régulière ») qui lève l'ambiguïté du libellé.
/// En grille, cette phrase ne tient pas, et « Intermédiaire » redevient un mot
/// que chacun interprète à sa façon.
class AiOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  const AiOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? color.withValues(alpha: AppColors.isDark ? 0.16 : 0.10)
                : AppColors.card,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 20,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AppColors.cardShadow,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.45),
                            color.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : AppColors.cardLight,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? color : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: AppColors.onGradient,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une pastille sélectionnable, avec icône optionnelle.
///
/// Sert aux choix multiples (matériel, zones à prioriser) et aux valeurs
/// courtes (durée de séance). Une pastille se lit dans un `Wrap` : le nombre
/// d'options peut varier sans que la mise en page bouge.
class AiPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  const AiPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.accent;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: icon == null ? 16 : 13,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? color.withValues(alpha: AppColors.isDark ? 0.20 : 0.13)
                : AppColors.card,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: -3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? AppColors.accentText
                      : AppColors.textHint,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de nombre de séances : sept pastilles rondes, de 1 à 7.
///
/// Un `Slider` aurait tenu moins de place, mais on ne choisit pas « quatre
/// séances » en glissant : c'est une valeur discrète, courte, qu'on veut
/// atteindre d'un seul geste — et voir toutes les options d'un coup dit
/// implicitement que sept est le maximum.
class AiCountPicker extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const AiCountPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(max - min + 1, (i) {
        final n = min + i;
        final selected = n == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: n == max ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(n);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: selected ? AppColors.heroGradient : null,
                  color: selected ? null : AppColors.card,
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : AppColors.border,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: -3,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.onGradient
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Petit intitulé de sous-section à l'intérieur d'une étape.
class AiFieldLabel extends StatelessWidget {
  final String label;
  final String? hint;

  const AiFieldLabel({super.key, required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.titleMedium),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(
            hint!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Champ numérique d'une charge de référence, avec son unité.
///
/// Volontairement dépouillé et court : ces quatre champs sont **facultatifs**,
/// et un formulaire qui a l'air obligatoire fait abandonner à l'étape 7.
class AiNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData icon;

  const AiNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 74,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                hintText: '—',
                hintStyle: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textDisabled,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              unit,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne du récapitulatif : ce qui a été répondu, et un raccourci pour y
/// revenir.
///
/// Le raccourci compte autant que la ligne. Un récapitulatif qu'on ne peut que
/// lire oblige à ressortir de l'assistant pour corriger une réponse ; ici, un
/// tap ramène directement à l'étape concernée.
class AiRecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const AiRecapRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onEdit!();
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.accentText),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.edit_rounded,
                size: 15,
                color: AppColors.textDisabled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
