import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../providers/ai_coach_provider.dart';
import '../providers/coaching_provider.dart';
import '../widgets/ai_coach_entry_card.dart';
import '../widgets/coach_card.dart';
import '../widgets/relationship_tile.dart';
import '../../../../core/widgets/screen_background.dart';

/// Onglet « Coaching » (adhérent) : **deux coachings, une seule page**.
///
/// L'écran distingue volontairement deux natures d'accompagnement, parce qu'elles
/// ne se choisissent pas de la même façon :
///
/// | | Coach humain | Coach IA |
/// |---|---|---|
/// | Accès | on parcourt, on compare, on demande, on attend | **immédiat** |
/// | Suivi | dans la durée, personnalisé | question / réponse |
/// | Emplacement | les deux onglets | **la carte en tête** |
///
/// La carte du coach IA est donc au-dessus des onglets, et non dans un troisième
/// onglet : un onglet le rangerait au même niveau qu'une liste à parcourir,
/// alors que c'est une action instantanée.
class CoachingHubScreen extends ConsumerWidget {
  const CoachingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le coach IA est masqué si le serveur n'a pas de clé configurée : mieux
    // vaut ne rien montrer qu'un bouton qui ne mène qu'à une erreur.
    final aiAvailable = ref.watch(aiCoachAvailableProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coaching'),
          actions: [
            IconButton(
              tooltip: 'Mes conversations',
              icon: const Icon(Icons.forum_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/conversations');
              },
            ),
          ],
        ),
        body: ScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (aiAvailable.value ?? false)
                  const AiCoachEntryCard()
                      .animate()
                      .fadeIn(duration: 380.ms)
                      .slideY(begin: -0.12, curve: Curves.easeOutCubic),

                // ── Les coachs humains ────────────────────────────────
                // Le titre de section n'est pas décoratif : sans lui, les
                // onglets qui suivent sembleraient s'appliquer aussi au coach IA
                // affiché juste au-dessus.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Coachs humains', style: AppTextStyles.headingSmall),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primaryText,
                  unselectedLabelColor: AppColors.textHint,
                  labelStyle: AppTextStyles.titleMedium,
                  unselectedLabelStyle: AppTextStyles.titleMedium,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Annuaire'),
                    Tab(text: 'Mes suivis'),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [_DirectoryTab(), _MyFollowsTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryTab extends ConsumerWidget {
  const _DirectoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coachDirectoryProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(coachDirectoryProvider),
      child: async.when(
        loading: () => const AppListSkeleton(itemCount: 4, itemHeight: 120),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            AppErrorState(
              message: _msg(e),
              onRetry: () => ref.invalidate(coachDirectoryProvider),
            ),
          ],
        ),
        data: (coaches) {
          if (coaches.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'Aucun coach disponible',
                  message:
                      'Aucun coach n\'est encore inscrit. Revenez bientôt !',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            itemCount: coaches.length,
            itemBuilder: (context, i) {
              final c = coaches[i];
              return CoachCard(
                    coach: c,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/coaches/${c.userId}');
                    },
                  )
                  .animate()
                  .fadeIn(delay: (i * 50).ms, duration: 300.ms)
                  .slideY(begin: 0.05);
            },
          );
        },
      ),
    );
  }
}

class _MyFollowsTab extends ConsumerWidget {
  const _MyFollowsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRelationshipsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(myRelationshipsProvider),
      child: async.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 84),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            AppErrorState(
              message: _msg(e),
              onRetry: () => ref.invalidate(myRelationshipsProvider),
            ),
          ],
        ),
        data: (rels) {
          if (rels.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'Aucun suivi',
                  message:
                      'Parcourez l\'onglet « Coachs » et envoyez une demande de suivi.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            itemCount: rels.length,
            itemBuilder: (context, i) {
              final r = rels[i];
              return RelationshipTile(
                    relationship: r,
                    asCoach: false,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (r.isAccepted) {
                        context.push('/chat/${r.id}');
                      } else {
                        context.push('/coaches/${r.coach.userId}');
                      }
                    },
                  )
                  .animate()
                  .fadeIn(delay: (i * 50).ms, duration: 300.ms)
                  .slideY(begin: 0.05);
            },
          );
        },
      ),
    );
  }
}

String _msg(Object e) {
  final s = e.toString();
  return s.startsWith('ApiException') ? s.split(': ').last : s;
}
