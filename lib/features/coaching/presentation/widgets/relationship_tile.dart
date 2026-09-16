import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../data/coaching_models.dart';
import 'coach_avatar.dart';

/// Tuile d'une relation de suivi. [asCoach] = true si le lecteur est le coach
/// (on affiche alors l'adhérent), false s'il est l'adhérent (on affiche le coach).
class RelationshipTile extends StatelessWidget {
  final CoachingRelationship relationship;
  final bool asCoach;
  final VoidCallback? onTap;

  const RelationshipTile({
    super.key,
    required this.relationship,
    required this.asCoach,
    this.onTap,
  });

  PersonRef get other => asCoach ? relationship.member : relationship.coach;

  Color get _statusColor {
    switch (relationship.status) {
      case 'PENDING':
        return AppColors.warning;
      case 'ACCEPTED':
        return AppColors.success;
      case 'DECLINED':
        return AppColors.error;
      default:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview =
        relationship.lastMessage ??
        (relationship.requestMessage != null &&
                relationship.requestMessage!.isNotEmpty
            ? relationship.requestMessage!
            : null);

    return SolidCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      // Teinte = couleur du statut. Une demande en attente et un suivi accepté
      // ne se ressemblent plus, sans avoir à lire la pastille.
      tintColor: _statusColor,
      lightEdge: true,
      child: Row(
        children: [
          CoachAvatar(
            initials: other.initials,
            avatarUrl: other.avatarUrl,
            size: 50,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        other.fullName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!relationship.isAccepted)
                      NeonBadge(
                        label: coachingStatusLabel(relationship.status),
                        color: _statusColor,
                        fontSize: 9,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  preview ?? 'Aucun message',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: relationship.unreadCount > 0
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight: relationship.unreadCount > 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (relationship.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${relationship.unreadCount}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.onGradient,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
