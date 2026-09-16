import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../programs/data/program_models.dart';
import '../../../programs/presentation/providers/program_provider.dart';
import '../../../programs/presentation/widgets/program_card.dart';
import '../../data/coaching_models.dart';
import '../widgets/coach_avatar.dart';
import '../../../../core/widgets/screen_background.dart';

/// Fiche d'un adhérent suivi (vue coach) : accès à la conversation et gestion
/// des programmes que le coach a composés pour lui.
class CoachClientScreen extends ConsumerStatefulWidget {
  final String memberUserId;
  final CoachingRelationship? relationship;

  const CoachClientScreen({
    super.key,
    required this.memberUserId,
    this.relationship,
  });

  @override
  ConsumerState<CoachClientScreen> createState() => _CoachClientScreenState();
}

class _CoachClientScreenState extends ConsumerState<CoachClientScreen> {
  List<ProgramModel> _programs = [];
  bool _loading = true;
  String? _error;

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
      final list = await ref
          .read(programApiProvider)
          .getProgramsForMember(widget.memberUserId);
      if (!mounted) return;
      setState(() {
        _programs = list;
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

  Future<void> _createProgram() async {
    await context.push(
      '/coach/member/${widget.memberUserId}/new-program',
      extra: widget.relationship?.member.fullName,
    );
    // Au retour, on rafraîchit la liste (un programme a pu être créé).
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.relationship?.member;
    return Scaffold(
      appBar: AppBar(title: Text(member?.fullName ?? 'Adhérent')),
      body: ScreenBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                if (member != null) _Header(member: member),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.relationship == null
                            ? null
                            : () => context.push(
                                '/chat/${widget.relationship!.id}',
                              ),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                        label: const Text('Conversation'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onGradient,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _createProgram,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Programme'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryText,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Programmes que je lui ai créés',
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: 12),
                _programsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _programsSection() {
    if (_loading) {
      return const AppListSkeleton(itemCount: 2, itemHeight: 120);
    }
    if (_error != null) {
      return AppErrorState(message: _error, onRetry: _load);
    }
    if (_programs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 30,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 8),
            Text(
              'Aucun programme pour cet adhérent',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Créez-en un pour structurer son entraînement.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Column(
      children: _programs
          .map(
            (p) => ProgramCard(
              program: p,
              onTap: () => context.push('/coach/program/${p.id}'),
            ),
          )
          .toList(),
    );
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

class _Header extends StatelessWidget {
  final PersonRef member;
  const _Header({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CoachAvatar(
            initials: member.initials,
            avatarUrl: member.avatarUrl,
            size: 60,
            gradient: AppColors.accentGradient,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.onGradient,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Adhérent suivi',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onGradient.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
