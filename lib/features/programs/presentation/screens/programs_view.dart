import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../providers/ai_program_provider.dart';
import '../providers/program_provider.dart';
import '../widgets/ai_program_cta.dart';
import '../widgets/program_card.dart';

/// Onglet « Programmes » : mes programmes personnels + programmes prêts à
/// l'emploi (modèles). L'utilisateur peut créer le sien ou adopter un modèle.
class ProgramsView extends ConsumerWidget {
  const ProgramsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(programsProvider);
    final notifier = ref.read(programsProvider.notifier);
    // Affichée par défaut, et masquée seulement si le serveur répond
    // explicitement qu'il n'a pas de clé Gemini. Voir le commentaire de
    // aiProgramAvailableProvider : un bouton absent ne se diagnostique pas.
    final aiAvailable = ref.watch(aiProgramAvailableProvider).value ?? true;
    // La bande d'annonce se masque pour la session ; le bouton « IA » de
    // l'en-tête, lui, reste — c'est l'entrée permanente.
    final ctaDismissed = ref.watch(aiCtaDismissedProvider);

    void openAiWizard() {
      HapticFeedback.selectionClick();
      context.push('/programs/ai');
    }

    if (state.isLoading) {
      return const AppListSkeleton(itemCount: 4, itemHeight: 150);
    }

    if (state.errorMessage != null &&
        state.myPrograms.isEmpty &&
        state.templates.isEmpty) {
      return AppErrorState(
        message: state.errorMessage,
        onRetry: notifier.loadAll,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: notifier.loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // ── Bande d'annonce de la génération IA ───────────────
          // Une ANNONCE, pas l'entrée de la fonctionnalité : elle fait
          // découvrir, puis elle se tait. L'entrée permanente est le bouton
          // « IA » de l'en-tête juste en dessous.
          if (aiAvailable && !ctaDismissed) ...[
            AiProgramCta(
                  onDismiss: ref.read(aiCtaDismissedProvider.notifier).dismiss,
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.08),
            const SizedBox(height: 22),
          ],

          // ── Mes programmes ────────────────────────────────────
          _SectionHeader(
            icon: Icons.person_rounded,
            title: 'Mes programmes',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CreateButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/programs/new');
                  },
                ),
                if (aiAvailable) ...[
                  const SizedBox(width: 8),
                  AiCreateButton(onTap: openAiWizard),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (state.myPrograms.isEmpty)
            _EmptyMine(
              onCreate: () {
                HapticFeedback.selectionClick();
                context.push('/programs/new');
              },
            )
          else
            ...state.myPrograms.asMap().entries.map((e) {
              final p = e.value;
              return ProgramCard(
                    program: p,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/programs/detail/${p.id}');
                    },
                  )
                  .animate()
                  .fadeIn(delay: (e.key * 50).ms, duration: 300.ms)
                  .slideY(begin: 0.05);
            }),

          const SizedBox(height: 24),

          // ── Programmes prêts (modèles) ────────────────────────
          _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Programmes prêts',
            subtitle: 'Push/Pull/Legs, Full Body… prêts à démarrer',
          ),
          const SizedBox(height: 12),
          if (state.templates.isEmpty)
            Text(
              'Aucun programme prêt pour le moment.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
            )
          else
            ...state.templates.asMap().entries.map((e) {
              final p = e.value;
              return ProgramCard(
                    program: p,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/programs/template/${p.id}');
                    },
                  )
                  .animate()
                  .fadeIn(delay: (e.key * 50).ms, duration: 300.ms)
                  .slideY(begin: 0.05);
            }),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primaryText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // L'en-tête porte désormais deux boutons : sur un écran étroit
              // ou avec un texte agrandi, c'est le titre qui doit céder.
              Text(
                title,
                style: AppTextStyles.headingSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.primary.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: AppColors.primaryText),
              const SizedBox(width: 4),
              Text(
                'Créer',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMine extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyMine({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCreate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.card,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 34,
              color: AppColors.primaryText,
            ),
            const SizedBox(height: 10),
            Text(
              'Créez votre première séance',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              // Pas de « ci-dessus » : la bande d'annonce peut avoir été
              // masquée, et une consigne qui désigne quelque chose d'absent
              // est pire que pas de consigne du tout.
              'Trois chemins : le bouton IA le compose pour vous, « Créer » vous laisse l\'assembler exercice par exercice, ou adoptez un modèle plus bas.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
