import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_depth.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/tilt_card.dart';

/// Tuile de statistique de l'accueil (Séances, Calories, Objectif, Sommeil).
///
/// ── Relief ──────────────────────────────────────────────────────────────
/// La tuile s'incline vers le doigt et se soulève ([TiltCard]). Son ombre est
/// **teintée de la couleur de son icône** ([AppDepth.tinted]) : une tuile
/// « Calories » projette une lueur cyan, « Sommeil » une lueur ambrée. C'est ce
/// qui fait qu'un même gabarit répété quatre fois ne donne pas quatre cartes
/// identiques — chacune éclaire son propre morceau de fond.
///
/// Un liseré lumineux en haut simule une arête qui accroche la lumière : c'est
/// l'indice qui donne une **épaisseur** au bord de la carte, là où une simple
/// bordure uniforme la laisse plate.
///
/// ── Règles de robustesse ────────────────────────────────────────────────
/// Cette carte vit dans une grille à 2 colonnes : sa largeur peut descendre
/// sous 140 px sur un petit téléphone, et sa hauteur est imposée par la
/// grille. Trois protections évitent tout débordement :
///
///  • le **titre** est `Expanded` + `ellipsis` — il ne pousse jamais l'icône
///    hors du cadre ;
///  • la **valeur** est dans un `FittedBox(scaleDown)` — un texte long
///    (« 12 / 5 », « 2450 ») rétrécit au lieu de déborder ;
///  • l'**unité** est limitée à une ligne avec ellipsis.
///
/// Le contenu ne réclame plus de hauteur minimale via `Expanded` : la carte
/// s'adapte à la place qu'on lui donne, y compris quand l'utilisateur a
/// agrandi la police du système.
class QuickStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final LinearGradient? gradient;

  /// Destination au tap. Une statistique sans action est une impasse : voir
  /// « 1 240 kcal » donne envie d'ouvrir le journal, pas de fixer le chiffre.
  final VoidCallback? onTap;

  const QuickStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Valeur numérique pure -> animation de comptage. Sinon (« 3 / 5 », « — »)
    // on affiche le texte tel quel.
    final double? numericValue = double.tryParse(value.replaceAll(' ', ''));
    final isFractional = value.contains('.');

    final valueStyle = AppTextStyles.statValue.copyWith(
      shadows: [Shadow(color: iconColor.withValues(alpha: 0.3), blurRadius: 8)],
    );

    return TiltCard(
      onTap: onTap,
      borderRadius: 18,
      // Ombre teintée : c'est elle qui différencie les quatre tuiles.
      restingShadow: AppDepth.tinted(iconColor, strength: 0.55),
      liftedShadow: AppDepth.tinted(iconColor, strength: 1.15),
      // Le reflet prend la teinte de l'icône : un reflet blanc pur sur une
      // tuile colorée donne un voile gris.
      sheenColor: Color.lerp(Colors.white, iconColor, 0.35)!,
      // `boxShadow: []` — l'élévation est portée par le TiltCard ci-dessus.
      // Deux ombres empilées se lisent comme une salissure, pas comme deux
      // hauteurs.
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        backgroundColor: AppColors.glassSurface,
        boxShadow: const [],
        tintColor: iconColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── En-tête : titre + pastille d'icône ──────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    // La pastille flotte à son tour, légèrement : elle se
                    // détache de la carte au lieu d'y être imprimée.
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Valeur + unité ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // scaleDown : la valeur rétrécit si elle ne tient pas, au
                // lieu de provoquer un débordement.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: numericValue != null
                      ? CountUpNumber(
                          to: numericValue,
                          decimals: isFractional ? 1 : 0,
                          style: valueStyle,
                        )
                      : Text(value, style: valueStyle, maxLines: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
