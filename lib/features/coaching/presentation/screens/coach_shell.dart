import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/avatar_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/coaching_models.dart';
import '../providers/coaching_provider.dart';
import '../widgets/coach_avatar.dart';
import '../widgets/relationship_tile.dart';

/// Espace COACH : tableau de bord, demandes de suivi, adhérents et profil.
class CoachShell extends ConsumerStatefulWidget {
  const CoachShell({super.key});

  @override
  ConsumerState<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends ConsumerState<CoachShell> {
  int _index = 0;

  static const _titles = [
    'Tableau de bord',
    'Demandes',
    'Mes adhérents',
    'Profil',
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    // Compteurs pour les badges de la barre de navigation.
    final dash = ref.watch(coachDashboardProvider).asData?.value;
    final pending = dash?.pendingRequests ?? 0;
    final unread = dash?.unreadMessages ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Mes conversations',
            icon: unread > 0
                ? Badge(
                    label: Text('$unread'),
                    child: const Icon(Icons.forum_rounded),
                  )
                : const Icon(Icons.forum_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/conversations');
            },
          ),
          if (_index != 3)
            IconButton(
              tooltip: 'Mon profil',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => _go(3),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.screenGradient),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              _DashboardView(onNavigate: _go),
              const _RequestsView(),
              const _ClientsView(),
              const _ProfileView(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          _go(i);
        },
        backgroundColor: AppColors.bottomBar,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Bord',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.mark_email_unread_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.mark_email_unread_rounded),
            ),
            label: 'Demandes',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.groups_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.groups_rounded),
            ),
            label: 'Adhérents',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Tableau de bord
// ═════════════════════════════════════════════════════════════════════

class _DashboardView extends ConsumerWidget {
  final void Function(int) onNavigate;
  const _DashboardView({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(coachDashboardProvider);
    final me = ref.watch(authProvider).user;
    final profile = ref.watch(myCoachProfileProvider).asData?.value;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => invalidateCoachingW(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          _HeroCard(
            name: me?.fullName ?? 'Coach',
            profile: profile,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04),

          // Nudge de complétion du profil.
          if (profile != null && _incomplete(profile)) ...[
            const SizedBox(height: 14),
            _CompletionNudge(onTap: () => context.push('/coach/profile/edit')),
          ],

          const SizedBox(height: 20),

          // Statistiques (tuiles cliquables → onglet correspondant).
          dash.when(
            loading: () => const _StatsSkeleton(),
            error: (e, _) => AppErrorState(
              message: _msg(e),
              onRetry: () => ref.invalidate(coachDashboardProvider),
            ),
            data: (d) => Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.hourglass_top_rounded,
                    value: d.pendingRequests,
                    label: 'Demandes',
                    color: AppColors.warning,
                    onTap: () => onNavigate(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.groups_rounded,
                    value: d.activeClients,
                    label: 'Adhérents',
                    color: AppColors.success,
                    onTap: () => onNavigate(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.mark_chat_unread_rounded,
                    value: d.unreadMessages,
                    label: 'Non lus',
                    color: AppColors.primary,
                    onTap: () => onNavigate(2),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Demandes récentes.
          _SectionHeader(
            title: 'Demandes récentes',
            actionLabel: 'Tout voir',
            onAction: () => onNavigate(1),
          ),
          const SizedBox(height: 12),
          _PendingPreview(onSeeAll: () => onNavigate(1)),

          const SizedBox(height: 24),

          // Adhérents actifs.
          _SectionHeader(
            title: 'Mes adhérents',
            actionLabel: 'Tout voir',
            onAction: () => onNavigate(2),
          ),
          const SizedBox(height: 12),
          _ClientsPreview(),
        ],
      ),
    );
  }

  static bool _incomplete(CoachProfile p) =>
      (p.headline == null || p.headline!.isEmpty) ||
      (p.bio == null || p.bio!.isEmpty) ||
      p.specialties.isEmpty;
}

class _HeroCard extends StatelessWidget {
  final String name;
  final CoachProfile? profile;
  const _HeroCard({required this.name, this.profile});

  @override
  Widget build(BuildContext context) {
    final accepting = profile?.acceptingClients ?? true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachAvatar(
                initials: profile?.initials ?? _initials(name),
                avatarUrl: profile?.avatarUrl,
                size: 58,
                gradient: AppColors.accentGradient,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour 👋',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onGradient.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      name,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.onGradient,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile?.headline != null && profile!.headline!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile!.headline!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onGradient.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.onGradient.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  accepting
                      ? Icons.check_circle_rounded
                      : Icons.do_not_disturb_on_rounded,
                  size: 14,
                  color: AppColors.onGradient,
                ),
                const SizedBox(width: 6),
                Text(
                  accepting
                      ? 'Ouvert aux nouvelles demandes'
                      : 'Fermé aux nouvelles demandes',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onGradient,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _CompletionNudge extends StatelessWidget {
  final VoidCallback onTap;
  const _CompletionNudge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                color: AppColors.warningText,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complétez votre profil',
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(
                      'Un profil complet attire plus d\'adhérents (bio, spécialités…).',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: AppTextStyles.statValue.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.statLabel,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingPreview extends ConsumerWidget {
  final VoidCallback onSeeAll;
  const _PendingPreview({required this.onSeeAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rels = ref.watch(coachRelationshipsProvider);
    return rels.when(
      loading: () => const AppListSkeleton(itemCount: 2, itemHeight: 120),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) {
        final pending = list.where((r) => r.isPending).take(2).toList();
        if (pending.isEmpty) {
          return _MiniEmpty(
            icon: Icons.inbox_outlined,
            text: 'Aucune demande en attente.',
          );
        }
        return Column(
          children: pending
              .map(
                (r) => _RequestCard(
                  relationship: r,
                  onAccept: () => respondToRequest(ref, context, r.id, true),
                  onDecline: () => respondToRequest(ref, context, r.id, false),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ClientsPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rels = ref.watch(coachRelationshipsProvider);
    return rels.when(
      loading: () => const AppListSkeleton(itemCount: 2, itemHeight: 76),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) {
        final active = list.where((r) => r.isAccepted).take(3).toList();
        if (active.isEmpty) {
          return _MiniEmpty(
            icon: Icons.groups_outlined,
            text: 'Vos adhérents apparaîtront ici.',
          );
        }
        return Column(
          children: active
              .map(
                (r) => RelationshipTile(
                  relationship: r,
                  asCoach: true,
                  onTap: () => context.push(
                    '/coach/member/${r.member.userId}',
                    extra: r,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textHint, size: 26),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.headingSmall)),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Demandes (accept / refus)
// ═════════════════════════════════════════════════════════════════════

/// Répond à une demande (partagé dashboard + onglet Demandes).
Future<void> respondToRequest(
  WidgetRef ref,
  BuildContext context,
  String id,
  bool accept,
) async {
  try {
    final api = ref.read(coachingApiProvider);
    accept ? await api.accept(id) : await api.decline(id);
    invalidateCoachingW(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(accept ? 'Demande acceptée ✅' : 'Demande refusée'),
            backgroundColor: accept ? AppColors.success : AppColors.textHint,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_msg(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _RequestsView extends ConsumerWidget {
  const _RequestsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rels = ref.watch(coachRelationshipsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(coachRelationshipsProvider),
      child: rels.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 130),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            AppErrorState(
              message: _msg(e),
              onRetry: () => ref.invalidate(coachRelationshipsProvider),
            ),
          ],
        ),
        data: (list) {
          final pending = list.where((r) => r.isPending).toList();
          if (pending.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Aucune demande',
                  message: 'Les nouvelles demandes de suivi apparaîtront ici.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            itemCount: pending.length,
            itemBuilder: (context, i) {
              final r = pending[i];
              return _RequestCard(
                relationship: r,
                onAccept: () => respondToRequest(ref, context, r.id, true),
                onDecline: () => respondToRequest(ref, context, r.id, false),
              ).animate().fadeIn(delay: (i * 50).ms, duration: 300.ms);
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final CoachingRelationship relationship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.relationship,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachAvatar(
                initials: relationship.member.initials,
                avatarUrl: relationship.member.avatarUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relationship.member.fullName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (relationship.createdAt != null)
                      Text(
                        _timeAgo(relationship.createdAt!),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (relationship.requestMessage != null &&
              relationship.requestMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '« ${relationship.requestMessage!} »',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorText,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accepter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onGradient,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Adhérents (suivis actifs → fiche adhérent)
// ═════════════════════════════════════════════════════════════════════

class _ClientsView extends ConsumerWidget {
  const _ClientsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rels = ref.watch(coachRelationshipsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(coachRelationshipsProvider),
      child: rels.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 84),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            AppErrorState(
              message: _msg(e),
              onRetry: () => ref.invalidate(coachRelationshipsProvider),
            ),
          ],
        ),
        data: (list) {
          final active = list.where((r) => r.isAccepted).toList();
          if (active.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Aucun adhérent',
                  message:
                      'Acceptez des demandes pour commencer à suivre des adhérents.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            itemCount: active.length,
            itemBuilder: (context, i) {
              final r = active[i];
              return RelationshipTile(
                relationship: r,
                asCoach: true,
                onTap: () =>
                    context.push('/coach/member/${r.member.userId}', extra: r),
              ).animate().fadeIn(delay: (i * 50).ms, duration: 300.ms);
            },
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Profil coach
// ═════════════════════════════════════════════════════════════════════

class _ProfileView extends ConsumerWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCoachProfileProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async => ref.invalidate(myCoachProfileProvider),
      child: async.when(
        loading: () => const AppListSkeleton(itemCount: 2, itemHeight: 120),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            AppErrorState(
              message: _msg(e),
              onRetry: () => ref.invalidate(myCoachProfileProvider),
            ),
          ],
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  AvatarPicker(
                    size: 88,
                    gradient: AppColors.accentGradient,
                    onChanged: () => ref.invalidate(myCoachProfileProvider),
                  ),
                  const SizedBox(height: 12),
                  Text(p.fullName, style: AppTextStyles.headingMedium),
                  if (p.headline != null && p.headline!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        p.headline!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (p.specialties.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: p.specialties
                          .take(4)
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                specialtyLabel(s),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primaryText,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.workspace_premium_rounded,
              label: 'Expérience',
              value: p.yearsExperience != null
                  ? '${p.yearsExperience} ans'
                  : 'Non renseignée',
            ),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Certifications',
              value: '${p.certifications.length}',
            ),
            _InfoRow(
              icon: Icons.school_outlined,
              label: 'Formations',
              value: '${p.educations.length}',
            ),
            _InfoRow(
              icon: Icons.toggle_on_rounded,
              label: 'Nouveaux adhérents',
              value: p.acceptingClients ? 'Ouvert' : 'Fermé',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/coach/profile/edit'),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Éditer mon profil'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onGradient,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 12),
            // Accès au dossier de candidature, même une fois validé : un coach
            // doit pouvoir relire ce qu'il a envoyé, et voir le motif si son
            // compte venait à être suspendu.
            OutlinedButton.icon(
              onPressed: () => context.push('/coach/application'),
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Mon dossier de candidature'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 12),
            // Signaler un problème : ouvert au coach comme à l'adhérent, et
            // placé au même endroit (le bas du profil) dans les deux espaces.
            OutlinedButton.icon(
              onPressed: () => context.push('/signalements'),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Signaler un problème'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryText, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'À l\'instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _msg(Object e) {
  final s = e.toString();
  return s.startsWith('ApiException') ? s.split(': ').last : s;
}
