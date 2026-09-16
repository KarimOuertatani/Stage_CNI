import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/animated_progress_bar.dart';
import '../../../../core/widgets/neon_badge.dart';
import 'muscle_group_3d_mapper.dart';

/// Bottom sheet premium de détail d'une zone musculaire.
///
/// Partagée entre [Body2DWidget] et [Body3DWidget] pour garantir une
/// expérience identique quel que soit le mode de visualisation.
/// [trainable] distingue les muscles rattachés à un groupe d'entraînement de
/// ceux que le modèle 3D expose sans qu'on les cible (visage, main, larynx…) :
/// leur conseiller « intégrez-les à votre prochaine séance » n'aurait aucun
/// sens.
Future<void> showMuscleDetailSheet(
  BuildContext context, {
  required String muscleName,
  required String groupName,
  required double intensity,
  bool trainable = true,
}) {
  HapticFeedback.selectionClick();
  final color = colorFromIntensitySmooth(intensity);
  final label = labelFromIntensity(intensity);
  final percentage = (intensity * 100).round();

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    // `false` plafonnerait la feuille à 9/16 de l'écran : le contenu (dont le
    // bouton d'action ajouté en bas) débordait alors en bandes jaunes et
    // noires sur les petits écrans, et la moindre police système agrandie
    // aggravait le débordement. À `true`, la feuille prend la hauteur dont
    // elle a besoin — bornée par le `maxHeight` posé plus bas.
    isScrollControlled: true,
    builder: (_) => _MuscleDetailSheet(
      muscleName: muscleName,
      groupName: groupName,
      intensity: intensity,
      color: color,
      label: label,
      percentage: percentage,
      trainable: trainable,
    ),
  );
}

class _MuscleDetailSheet extends StatelessWidget {
  final String muscleName;
  final String groupName;
  final double intensity;
  final Color color;
  final String label;
  final int percentage;
  final bool trainable;

  const _MuscleDetailSheet({
    required this.muscleName,
    required this.groupName,
    required this.intensity,
    required this.color,
    required this.label,
    required this.percentage,
    required this.trainable,
  });

  String get _advice {
    if (!trainable) {
      return 'Ce muscle fait partie de la planche anatomique mais n\'est '
          'rattaché à aucun groupe d\'entraînement : il n\'entre pas dans '
          'le calcul de votre charge de travail.';
    }
    if (intensity == 0) {
      return 'Zone au repos complet cette semaine. Pensez à l\'intégrer '
          'à votre prochaine séance pour un développement équilibré.';
    }
    if (intensity < 0.3) {
      return 'Sollicitation légère. Vous pouvez augmenter le volume '
          'sur cette zone sans risque de surentraînement.';
    }
    if (intensity < 0.6) {
      return 'Bonne sollicitation. Maintenez ce rythme pour une '
          'progression régulière.';
    }
    if (intensity < 0.85) {
      return 'Zone très travaillée récemment. Prévoyez 48h de '
          'récupération avant de la solliciter à nouveau.';
    }
    return 'Sollicitation maximale ! Priorité à la récupération : '
        'sommeil, nutrition et étirements légers.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // La feuille ne dépasse jamais 88 % de l'écran : au-delà, elle ne se
        // lit plus comme une feuille posée sur la silhouette mais comme un
        // changement d'écran, et on perd le repère de ce qu'on vient de toucher.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: AppColors.isDark ? 0.18 : 0.10),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          // Défilement plutôt que hauteur figée : un nom de muscle long, une
          // police système agrandie ou un petit écran ne doivent pas produire
          // un débordement mais un contenu qu'on fait défiler.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ────────────────────────────────────────
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
                const SizedBox(height: 20),

                // ── Header : dot néon + nom + badge groupe ─────────────
                Row(
                  children: [
                    Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.25, 1.25),
                          duration: 900.ms,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        muscleName,
                        style: AppTextStyles.headingMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    NeonBadge(label: groupName, color: AppColors.primary),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15),
                const SizedBox(height: 24),

                // ── Intensité : gros % + label ─────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CountUpNumber(
                      to: percentage.toDouble(),
                      suffix: '%',
                      duration: const Duration(milliseconds: 800),
                      style: AppTextStyles.heroNumber.copyWith(
                        fontSize: 44,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        label.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: color,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('sur 7 jours', style: AppTextStyles.caption),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                const SizedBox(height: 14),

                // ── Barre de progression ───────────────────────────────
                AnimatedProgressBar(
                  value: intensity,
                  height: 10,
                  color: color,
                  showGlow: intensity > 0.05,
                  duration: const Duration(milliseconds: 800),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 20),

                // ── Conseil contextuel ─────────────────────────────────
                Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            size: 18,
                            color: AppColors.warningText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _advice,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 220.ms, duration: 350.ms)
                    .slideY(begin: 0.1),

                // ── Passage à l'action ─────────────────────────────────
                //
                // Le conseil ci-dessus dit quoi faire (« intégrez cette zone à
                // votre prochaine séance ») sans dire comment. Sans ce bouton, il
                // fallait mémoriser le muscle, fermer, ouvrir la bibliothèque et
                // y retrouver la bonne zone — un conseil qu'on ne peut pas suivre
                // sur place n'est pas un conseil.
                //
                // Réservé aux muscles rattachés à un groupe d'entraînement :
                // proposer « les exercices du larynx » n'aurait pas de sens.
                if (trainable) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        // On referme d'abord : revenir depuis la liste doit ramener
                        // à la silhouette, pas rouvrir cette feuille par-dessus.
                        Navigator.of(context).pop();
                        context.push(
                          '/workout/muscle/${Uri.encodeComponent(groupName)}',
                        );
                      },
                      icon: const Icon(Icons.fitness_center_rounded, size: 19),
                      // Une seule ligne, tronquée au besoin : « Exercices pour
                      // Abdominaux » ne tient pas sur un écran étroit, et un
                      // libellé de bouton qui passe à la ligne casse sa hauteur.
                      label: Text(
                        'Exercices pour $groupName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onGradient,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: AppTextStyles.titleMedium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 350.ms),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
