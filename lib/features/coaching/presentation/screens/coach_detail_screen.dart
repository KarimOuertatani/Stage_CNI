import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/coaching_models.dart';
import '../providers/coaching_provider.dart';
import '../widgets/coach_avatar.dart';
import '../../../../core/widgets/screen_background.dart';

/// Profil complet d'un coach vu par un adhérent : CV + action (demande de suivi
/// ou accès à la conversation si le suivi est déjà actif).
class CoachDetailScreen extends ConsumerStatefulWidget {
  final String coachUserId;
  const CoachDetailScreen({super.key, required this.coachUserId});

  @override
  ConsumerState<CoachDetailScreen> createState() => _CoachDetailScreenState();
}

class _CoachDetailScreenState extends ConsumerState<CoachDetailScreen> {
  CoachProfile? _coach;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await ref
          .read(coachingApiProvider)
          .getCoachProfile(widget.coachUserId);
      if (!mounted) return;
      setState(() {
        _coach = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _requestCoaching() async {
    final message = await _askMessage();
    if (message == null || _busy) return;
    setState(() => _busy = true);
    try {
      final rel = await ref
          .read(coachingApiProvider)
          .requestCoaching(widget.coachUserId, message);
      invalidateCoachingW(ref);
      if (!mounted) return;
      setState(() {
        _coach = _coach == null
            ? null
            : _coachWithRelation(_coach!, rel.status, rel.id);
        _busy = false;
      });
      _snack('Demande envoyée à ${_coach?.fullName ?? 'ce coach'} !');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(_msg(e), isError: true);
      }
    }
  }

  Future<String?> _askMessage() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Demande de suivi', style: AppTextStyles.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Présentez votre objectif au coach (optionnel).',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: controller,
              hint: 'Ex : Je veux progresser en force…',
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Annuler',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              'Envoyer',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _coach;
    return Scaffold(
      appBar: AppBar(title: Text(c?.fullName ?? 'Coach')),
      body: ScreenBackground(child: SafeArea(top: false, child: _body(c))),
      bottomNavigationBar: c == null
          ? null
          : _ActionBar(
              coach: c,
              busy: _busy,
              onRequest: _requestCoaching,
              onOpenChat: () => context.push('/chat/${c.viewerRelationshipId}'),
            ),
    );
  }

  Widget _body(CoachProfile? c) {
    if (_loading) return const AppListSkeleton(itemCount: 3, itemHeight: 130);
    if (_error != null && c == null) {
      return AppErrorState(message: _error, onRetry: _load);
    }
    if (c == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        _Header(coach: c),
        if (c.specialties.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle('Spécialités'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: c.specialties
                .map(
                  (s) => NeonBadge(
                    label: specialtyLabel(s),
                    color: AppColors.primary,
                  ),
                )
                .toList(),
          ),
        ],
        if (c.bio != null && c.bio!.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle('À propos'),
          const SizedBox(height: 8),
          Text(
            c.bio!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (c.experiences.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle('Expériences'),
          const SizedBox(height: 10),
          ...c.experiences.map(
            (e) => _TimelineItem(
              icon: Icons.work_outline_rounded,
              title: e.title,
              subtitle: e.organization,
              trailing: e.periodLabel,
              description: e.description,
            ),
          ),
        ],
        if (c.certifications.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle('Certifications'),
          const SizedBox(height: 10),
          ...c.certifications.map(
            (e) => _TimelineItem(
              icon: Icons.workspace_premium_outlined,
              title: e.title,
              subtitle: e.organization,
              trailing: e.year?.toString(),
            ),
          ),
        ],
        if (c.educations.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionTitle('Formations'),
          const SizedBox(height: 10),
          ...c.educations.map(
            (e) => _TimelineItem(
              icon: Icons.school_outlined,
              title: e.degree,
              subtitle: [
                e.institution,
                e.fieldOfStudy,
              ].where((x) => x != null && x.isNotEmpty).join(' · '),
              trailing: e.year?.toString(),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static CoachProfile _coachWithRelation(
    CoachProfile c,
    String status,
    String relId,
  ) {
    return CoachProfile(
      userId: c.userId,
      profileId: c.profileId,
      fullName: c.fullName,
      avatarUrl: c.avatarUrl,
      headline: c.headline,
      bio: c.bio,
      yearsExperience: c.yearsExperience,
      hourlyRate: c.hourlyRate,
      city: c.city,
      acceptingClients: c.acceptingClients,
      ratingAverage: c.ratingAverage,
      ratingCount: c.ratingCount,
      specialties: c.specialties,
      certifications: c.certifications,
      educations: c.educations,
      experiences: c.experiences,
      viewerRelationStatus: status,
      viewerRelationshipId: relId,
    );
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

// ── Widgets internes ──────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final CoachProfile coach;
  const _Header({required this.coach});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CoachAvatar(
                initials: coach.initials,
                avatarUrl: coach.avatarUrl,
                size: 72,
                gradient: AppColors.accentGradient,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.fullName,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.onGradient,
                      ),
                    ),
                    if (coach.headline != null &&
                        coach.headline!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        coach.headline!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onGradient.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (coach.yearsExperience != null)
                _Stat(value: '${coach.yearsExperience}', label: 'Ans d\'exp.'),
              if (coach.city != null && coach.city!.isNotEmpty)
                _Stat(value: coach.city!, label: 'Zone', flex: 2),
              if (coach.hourlyRate != null)
                _Stat(
                  value: '${coach.hourlyRate!.toStringAsFixed(0)} DT',
                  label: '/ séance',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final int flex;
  const _Stat({required this.value, required this.label, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.onGradient,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.statLabel.copyWith(
              color: AppColors.onGradient.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppTextStyles.headingSmall);
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? description;

  const _TimelineItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.description,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTextStyles.titleMedium),
                    ),
                    if (trailing != null && trailing!.isNotEmpty)
                      Text(
                        trailing!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final CoachProfile coach;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onOpenChat;

  const _ActionBar({
    required this.coach,
    required this.busy,
    required this.onRequest,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final status = coach.viewerRelationStatus;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    Widget child;
    if (status == 'ACCEPTED') {
      child = PrimaryButton(
        label: 'Ouvrir la conversation',
        icon: Icons.chat_bubble_rounded,
        onPressed: onOpenChat,
      );
    } else if (status == 'PENDING') {
      child = _DisabledBanner(
        icon: Icons.hourglass_top_rounded,
        label: 'Demande en attente de réponse',
      );
    } else if (!coach.acceptingClients) {
      child = _DisabledBanner(
        icon: Icons.do_not_disturb_on_outlined,
        label: 'Ce coach n\'accepte pas de nouveaux adhérents',
      );
    } else {
      child = PrimaryButton(
        label: status == 'DECLINED' || status == 'ENDED'
            ? 'Renvoyer une demande'
            : 'Demander un suivi',
        icon: Icons.person_add_alt_1_rounded,
        isLoading: busy,
        onPressed: busy ? null : onRequest,
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}

class _DisabledBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DisabledBanner({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textHint, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
