import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'ai_coach_avatar.dart';

/// Carte d'entrée vers le coach IA, en tête de l'onglet Coaching.
///
/// **Pourquoi une carte pleine largeur et non un onglet ou un bouton d'AppBar.**
/// Les deux coachings ne se choisissent pas de la même façon. Un coach humain se
/// choisit — on parcourt l'annuaire, on compare, on envoie une demande, on
/// attend. Le coach IA, lui, est **déjà disponible** : il n'y a rien à décider.
///
/// Le mettre dans un troisième onglet le rangerait au même niveau qu'une liste à
/// parcourir, alors que c'est une action immédiate. La carte le dit : elle
/// s'ouvre d'un tap, et elle est la première chose qu'on voit.
///
/// Elle assume aussi de préciser **ce que l'IA n'est pas** (« en complément de
/// ton coach ») : c'est l'endroit où l'adhérent découvre les deux options, donc
/// l'endroit où la distinction doit être posée.
class AiCoachEntryCard extends StatelessWidget {
  const AiCoachEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/coach-ai');
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(
                    alpha: AppColors.isDark ? 0.20 : 0.13,
                  ),
                  AppColors.primary.withValues(
                    alpha: AppColors.isDark ? 0.15 : 0.09,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                const AiCoachAvatar(size: 48, glow: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Coach IA',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // « Disponible » n'est pas un ornement : c'est la
                          // différence concrète avec un coach humain, qui
                          // demande une acceptation puis une réponse.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Disponible 24/7',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successText,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Entraînement, nutrition, douleurs. En complément de '
                        'ton coach, pas à sa place.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.accentText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
