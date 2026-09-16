import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

/// Saisie du code à 6 chiffres reçu par email.
///
/// Écran charnière du parcours d'inscription : le compte existe déjà mais est
/// désactivé, et c'est la validation du code qui l'active **et** délivre le
/// JWT. On arrive ici :
///  • juste après une inscription (adhérent ou coach) ;
///  • depuis la connexion, si le compte n'a jamais été vérifié.
///
/// [isCoach] détermine la destination une fois le compte activé :
/// `/coach/onboarding` pour un coach, `/onboarding` pour un adhérent.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  final bool isCoach;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.isCoach = false,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  /// Délai anti-renvoi, aligné sur la limite du backend (60 s).
  static const int _resendCooldownSeconds = 60;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _error;
  bool _submitting = false;
  int _secondsLeft = _resendCooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  String get _code => _controller.text.trim();

  Future<void> _submit() async {
    if (_code.length != 6 || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    final error = await ref
        .read(authProvider.notifier)
        .verifyEmail(widget.email, _code);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      HapticFeedback.heavyImpact();
      // Le code est faux : on vide le champ pour une nouvelle saisie.
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }

    // Compte activé et connecté : on enchaîne sur l'onboarding du bon rôle.
    context.go(widget.isCoach ? '/coach/onboarding' : '/onboarding');
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    HapticFeedback.selectionClick();

    final error = await ref
        .read(authProvider.notifier)
        .resendCode(widget.email);
    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nouveau code envoyé !',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _code.length == 6 && !_submitting;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.screenGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                // Borne la largeur : sur tablette/desktop le formulaire reste
                // une colonne lisible au lieu de s'étirer sur tout l'écran.
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _icon(),
                    const SizedBox(height: 24),
                    Text(
                      'Vérifiez votre email',
                      style: AppTextStyles.displayMedium,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                    const SizedBox(height: 10),
                    _subtitle(),
                    const SizedBox(height: 28),
                    _codeField(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _errorBanner(),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _submitting
                          ? 'Vérification…'
                          : 'Vérifier mon email',
                      icon: Icons.verified_rounded,
                      gradient: AppColors.accentGradient,
                      glowColor: AppColors.accent,
                      onPressed: canSubmit ? _submit : null,
                    ).animate().fadeIn(delay: 250.ms),
                    const SizedBox(height: 18),
                    _resendRow(),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Revenir à la connexion'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    return Center(
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          shape: BoxShape.circle,
          boxShadow: AppColors.accentGlow,
        ),
        child: const Icon(
          Icons.mark_email_unread_rounded,
          size: 40,
          color: AppColors.onGradient,
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _subtitle() {
    return Column(
      children: [
        Text(
          'Nous avons envoyé un code à 6 chiffres à',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.accentText,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ).animate().fadeIn(delay: 120.ms);
  }

  /// Champ de saisie du code : un seul `TextField` centré, en monospace et
  /// très espacé. Plus fiable que six cases séparées (copier-coller,
  /// remplissage automatique du code SMS/email, correction au clavier).
  Widget _codeField() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 20,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        // Chiffres uniquement : évite les codes invalides côté serveur.
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        // Permet le remplissage automatique du code par le système.
        autofillHints: const [AutofillHints.oneTimeCode],
        style: AppTextStyles.displayMedium.copyWith(
          letterSpacing: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••••',
          hintStyle: AppTextStyles.displayMedium.copyWith(
            letterSpacing: 12,
            color: AppColors.textHint.withValues(alpha: 0.35),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: (_) {
          // Efface l'erreur dès que l'utilisateur recommence à taper.
          if (_error != null) setState(() => _error = null);
          setState(() {}); // réévalue l'état du bouton
        },
        onSubmitted: (_) => _submit(),
      ),
    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.06);
  }

  Widget _errorBanner() {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.errorText,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.errorText,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 250.ms)
        .shake(hz: 3, offset: const Offset(2, 0));
  }

  /// Renvoi du code, avec compte à rebours visible : l'utilisateur sait
  /// exactement quand il pourra réessayer, au lieu de se heurter à un refus.
  Widget _resendRow() {
    final waiting = _secondsLeft > 0;
    return Column(
      children: [
        Text(
          'Vous n\'avez rien reçu ? Pensez à vérifier vos spams.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: waiting ? null : _resend,
          icon: Icon(
            waiting ? Icons.timer_outlined : Icons.refresh_rounded,
            size: 18,
          ),
          label: Text(
            waiting
                ? 'Renvoyer le code dans ${_secondsLeft}s'
                : 'Renvoyer le code',
          ),
          style: TextButton.styleFrom(
            foregroundColor: waiting
                ? AppColors.textHint
                : AppColors.accentText,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 320.ms);
  }
}
