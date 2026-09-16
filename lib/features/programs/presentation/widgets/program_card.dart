import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../data/program_models.dart';

/// Carte présentant un programme (personnel ou modèle) : titre, objectif,
/// niveau, nombre de séances / exercices et durée.
class ProgramCard extends StatelessWidget {
  final ProgramModel program;
  final VoidCallback? onTap;

  const ProgramCard({super.key, required this.program, this.onTap});

  Color get _accent {
    // Une teinte par objectif pour différencier visuellement les programmes.
    switch (program.goal) {
      case 'PRISE_MASSE':
        return AppColors.primary;
      case 'FORCE':
        return AppColors.error;
      case 'PERTE_POIDS':
        return AppColors.accent;
      case 'ENDURANCE':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  IconData get _icon {
    switch (program.goal) {
      case 'PRISE_MASSE':
        return Icons.fitness_center_rounded;
      case 'FORCE':
        return Icons.bolt_rounded;
      case 'PERTE_POIDS':
        return Icons.local_fire_department_rounded;
      case 'ENDURANCE':
        return Icons.directions_run_rounded;
      default:
        return Icons.list_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return SolidCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      // Teinte dérivée de l'objectif du programme : une liste de programmes
      // cesse d'être une pile de rectangles identiques, chacun éclaire le fond
      // de sa propre couleur.
      tintColor: accent,
      lightEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.25),
                      accent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(_icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.title,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        NeonBadge(
                          label: program.goalLabel,
                          color: accent,
                          fontSize: 10,
                        ),
                        NeonBadge(
                          label: program.levelLabel,
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint,
                size: 15,
              ),
            ],
          ),
          // L'auteur du programme, quel qu'il soit — coach humain ou IA
          // FitForge. Même ligne, même place, même traitement : ce n'est pas
          // la nature de l'auteur qui compte pour l'adhérent, c'est de savoir
          // que le programme n'est pas de lui.
          if (program.authorLabel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  program.generatedByAi
                      ? Icons.auto_awesome_rounded
                      : Icons.verified_user_rounded,
                  size: 14,
                  color: program.generatedByAi
                      ? AppColors.primaryText
                      : AppColors.accentText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    program.authorLabel!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: program.generatedByAi
                          ? AppColors.primaryText
                          : AppColors.accentText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (program.description != null &&
              program.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              program.description!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaChip(
                icon: Icons.event_note_rounded,
                label:
                    '${program.sessionCount} séance${program.sessionCount > 1 ? 's' : ''}',
              ),
              const SizedBox(width: 14),
              _MetaChip(
                icon: Icons.fitness_center_rounded,
                label: '${program.totalExercises} exos',
              ),
              if (program.durationWeeks != null) ...[
                const SizedBox(width: 14),
                _MetaChip(
                  icon: Icons.calendar_today_rounded,
                  label: '${program.durationWeeks} sem.',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}
