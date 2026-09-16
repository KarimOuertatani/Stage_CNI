import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../data/coaching_models.dart';
import 'coach_avatar.dart';

/// Carte d'un coach dans l'annuaire.
class CoachCard extends StatelessWidget {
  final CoachSummary coach;
  final VoidCallback? onTap;

  const CoachCard({super.key, required this.coach, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SolidCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      // Violet : la couleur du coaching humain dans toute l'app (le coach IA,
      // lui, est cyan). La distinction se lit jusque dans l'ombre des cartes.
      tintColor: AppColors.primary,
      lightEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachAvatar(
                initials: coach.initials,
                avatarUrl: coach.avatarUrl,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.fullName,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coach.headline != null &&
                        coach.headline!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        coach.headline!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (coach.yearsExperience != null) ...[
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${coach.yearsExperience} ans d\'exp.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                        if (coach.city != null && coach.city!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              coach.city!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textHint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!coach.acceptingClients)
                Icon(
                  Icons.do_not_disturb_on_outlined,
                  color: AppColors.textHint,
                  size: 18,
                ),
            ],
          ),
          if (coach.specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: coach.specialties
                  .take(3)
                  .map(
                    (s) => NeonBadge(
                      label: specialtyLabel(s),
                      color: AppColors.primary,
                      fontSize: 10,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
