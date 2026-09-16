import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/coaching_models.dart';
import '../../data/presence_models.dart';
import '../providers/coaching_provider.dart';
import '../widgets/coach_avatar.dart';
import '../../../../core/widgets/screen_background.dart';

/// Accès rapide à toutes mes conversations (coach ou adhérent).
///
/// Liste les suivis ACCEPTÉS avec aperçu du dernier message, badge de non-lus,
/// horodatage et **pastille de présence**. Un tap ouvre le fil correspondant.
///
/// **Pourquoi un rafraîchissement périodique et pas le WebSocket ?** Ouvrir un
/// second socket rien que pour cet écran ferait une deuxième session STOMP en
/// parallèle de celle de la conversation. Pour une liste, un appel groupé
/// (`GET /presence/partners`) toutes les 20 s suffit largement et coûte une
/// seule requête. Le temps réel à la seconde est réservé au fil de discussion,
/// là où il se voit.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  /// Présence par identifiant d'utilisateur. Vide tant que rien n'est chargé :
  /// aucune pastille ne s'affiche, plutôt qu'un « hors ligne » inventé.
  Map<String, Presence> _presence = const {};
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _loadPresence();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadPresence(),
    );
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPresence() async {
    try {
      final list = await ref.read(coachingApiProvider).getPartnersPresence();
      if (!mounted) return;
      setState(() {
        _presence = {for (final p in list) p.userId: p};
      });
    } catch (_) {
      // Présence indisponible : la liste reste parfaitement utilisable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCoach = ref.watch(authProvider).user?.role == 'COACH';
    final myId = ref.watch(authProvider).user?.id;
    final provider = isCoach
        ? coachRelationshipsProvider
        : myRelationshipsProvider;
    final async = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes conversations')),
      body: ScreenBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              ref.invalidate(provider);
              await _loadPresence();
            },
            child: async.when(
              loading: () =>
                  const AppListSkeleton(itemCount: 6, itemHeight: 76),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  AppErrorState(
                    message: _msg(e),
                    onRetry: () => ref.invalidate(provider),
                  ),
                ],
              ),
              data: (rels) {
                final active = rels.where((r) => r.isAccepted).toList()
                  ..sort(
                    (a, b) => (b.lastMessageAt ?? b.createdAt ?? DateTime(0))
                        .compareTo(
                          a.lastMessageAt ?? a.createdAt ?? DateTime(0),
                        ),
                  );
                if (active.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 80),
                      AppEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Aucune conversation',
                        message:
                            'Vos discussions actives apparaîtront ici dès qu\'un suivi est accepté.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = active[i];
                    final other = _other(r, myId, isCoach);
                    return _ConversationTile(
                          relationship: r,
                          other: other,
                          presence: _presence[other.userId],
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/chat/${r.id}');
                          },
                        )
                        .animate()
                        .fadeIn(delay: (i * 40).ms, duration: 260.ms)
                        .slideY(begin: 0.04);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// L'autre participant du fil selon mon rôle.
  PersonRef _other(CoachingRelationship r, String? myId, bool isCoach) {
    if (myId != null) {
      return r.coach.userId == myId ? r.member : r.coach;
    }
    return isCoach ? r.member : r.coach;
  }
}

class _ConversationTile extends StatelessWidget {
  final CoachingRelationship relationship;
  final PersonRef other;

  /// `null` tant que la présence n'est pas connue : aucune pastille affichée.
  final Presence? presence;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.relationship,
    required this.other,
    required this.presence,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = relationship.unreadCount;
    final hasUnread = unread > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasUnread
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              CoachAvatar(
                initials: other.initials,
                avatarUrl: other.avatarUrl,
                size: 50,
                online: presence?.online,
                dotRingColor: AppColors.card,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            other.fullName,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (relationship.lastMessageAt != null)
                          Text(
                            _timeAgo(relationship.lastMessageAt!),
                            style: AppTextStyles.caption.copyWith(
                              color: hasUnread
                                  ? AppColors.primaryText
                                  : AppColors.textHint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            relationship.lastMessage ??
                                'Démarrez la conversation',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onGradient,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'maintenant';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} j';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

String _msg(Object e) {
  final s = e.toString();
  return s.startsWith('ApiException') ? s.split(': ').last : s;
}
