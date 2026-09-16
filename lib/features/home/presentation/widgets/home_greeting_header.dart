import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/neon_badge.dart';

class HomeGreetingHeader extends StatelessWidget {
  final String userName;
  final String? avatarUrl;
  final VoidCallback? onProfileTap;

  const HomeGreetingHeader({
    super.key,
    required this.userName,
    this.avatarUrl,
    this.onProfileTap,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Bonne nuit';
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  String _formatDate() {
    final now = DateTime.now();
    final months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    final days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // Prénom seul pour le bonjour : évite de faire déborder l'en-tête quand
    // le nom complet est long.
    final firstName = userName.trim().isEmpty
        ? 'Utilisateur'
        : userName.trim().split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date avec style overline néon
              Row(
                children: [
                  PulseDot(color: AppColors.success, size: 7),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatDate().toUpperCase(),
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.accentText,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Greeting (prénom en dégradé), tronqué si trop long.
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: AppTextStyles.headingLarge,
                  children: [
                    TextSpan(text: '${_getGreeting()}, '),
                    TextSpan(
                      text: firstName,
                      style: AppTextStyles.headingLarge.copyWith(
                        foreground: Paint()
                          ..shader = AppColors.heroGradient.createShader(
                            const Rect.fromLTWH(0, 0, 200, 40),
                          ),
                      ),
                    ),
                    const TextSpan(text: ' 👋'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Avatar avec anneau gradient animé
        GestureDetector(
          onTap: onProfileTap,
          child: _AnimatedAvatarRing(
            initials: userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            avatarUrl: ApiConstants.mediaUrl(avatarUrl),
          ),
        ),
      ],
    );
  }
}

class _AnimatedAvatarRing extends StatefulWidget {
  final String initials;
  final String? avatarUrl;
  const _AnimatedAvatarRing({required this.initials, this.avatarUrl});

  @override
  State<_AnimatedAvatarRing> createState() => _AnimatedAvatarRingState();
}

class _AnimatedAvatarRingState extends State<_AnimatedAvatarRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating gradient ring
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.rotate(angle: _ctrl.value * 6.28318, child: child),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.primaryLight,
                  AppColors.primary,
                ],
              ),
            ),
          ),
        ),
        // Inner white gap
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.background,
          ),
        ),
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.avatarUrl == null ? AppColors.cardGradient : null,
            image: widget.avatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(widget.avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.avatarUrl != null
              ? null
              : Center(
                  child: Text(
                    widget.initials,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
