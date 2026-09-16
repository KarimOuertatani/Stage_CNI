import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_logo.dart';
import '../widgets/auth_shell.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  double _passwordStrength = 0.0;
  DateTime? _birthDate; // date de naissance (requise pour un adhérent)
  String _role = 'ADHERENT'; // ADHERENT | COACH

  bool get _isCoach => _role == 'COACH';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final val = _passwordController.text;
    double strength = 0;
    if (val.length >= 6) strength += 0.25;
    if (val.length >= 10) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(val)) strength += 0.25;
    if (RegExp(r'[0-9!@#\$%&*]').hasMatch(val)) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  Color get _strengthColor {
    if (_passwordStrength <= 0.25) return AppColors.error;
    if (_passwordStrength <= 0.5) return AppColors.warning;
    if (_passwordStrength <= 0.75) return AppColors.info;
    return AppColors.success;
  }

  String get _strengthLabel {
    if (_passwordStrength <= 0.25) return 'Faible';
    if (_passwordStrength <= 0.5) return 'Moyen';
    if (_passwordStrength <= 0.75) return 'Fort';
    return 'Très fort';
  }

  /// Ouvre le sélecteur de date de naissance (par défaut ~20 ans en arrière).
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: now, // date passée uniquement
      helpText: 'Date de naissance',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    // La date de naissance (adhérent uniquement) n'est pas un champ texte :
    // on la valide à part. Un coach n'a pas à la renseigner.
    if (!_isCoach && _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez indiquer votre date de naissance'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      final notifier = ref.read(authProvider.notifier);
      final bool success;
      if (_isCoach) {
        success = await notifier.signupCoach(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        success = await notifier.signup(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _birthDate!,
        );
      }
      if (success && mounted) {
        // Le compte est créé mais DÉSACTIVÉ : on passe d'abord par la saisie
        // du code reçu par email. C'est cette étape qui délivre le JWT, puis
        // enchaîne sur l'onboarding du bon rôle.
        context.go(
          '/verify-email',
          extra: {'email': _emailController.text.trim(), 'isCoach': _isCoach},
        );
      } else if (mounted) {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Erreur d\'inscription'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return AuthShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Identité ────────────────────────────────────────────
            // Logo en CYAN ici, violet à la connexion : les deux écrans
            // restent distinguables d'un coup d'œil, sans lire le titre.
            Center(
              child:
                  const AuthLogo(
                        size: 84,
                        gradient: AppColors.accentGradient,
                        glowColor: AppColors.accent,
                      )
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        curve: Curves.easeOutBack,
                        duration: 900.ms,
                      ),
            ),

            // Titre
            Text(
                  'Créer un compte',
                  style: AppTextStyles.displayMedium.copyWith(
                    foreground: Paint()
                      ..shader = AppColors.accentGradient.createShader(
                        const Rect.fromLTWH(0, 0, 300, 50),
                      ),
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.3),

            const SizedBox(height: 8),
            Text(
              'Rejoignez FitForge et sculptez votre physique',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 350.ms, duration: 600.ms),
            const SizedBox(height: 32),

            // Card glassmorphisme
            AuthGlassCard(
                  tint: AppColors.accent,
                  children: [
                    Text(
                      'Je m\'inscris en tant que',
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: 12),
                    _RoleSelector(
                      role: _role,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 20),
                    Text('Informations', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _nameController,
                      hint: 'John Doe',
                      label: 'Nom complet',
                      prefixIcon: Icons.person_outline,
                      accentColor: AppColors.accent,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Veuillez saisir votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date de naissance — adhérent uniquement
                    if (!_isCoach) ...[
                      _BirthDateField(value: _birthDate, onTap: _pickBirthDate),
                      const SizedBox(height: 16),
                    ],
                    AppTextField(
                      controller: _emailController,
                      hint: 'votre.email@exemple.com',
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      accentColor: AppColors.accent,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Veuillez saisir votre email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(val)) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      hint: '••••••••',
                      label: 'Mot de passe',
                      prefixIcon: Icons.lock_outlined,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      accentColor: AppColors.accent,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Veuillez saisir votre mot de passe';
                        }
                        if (val.length < 6) {
                          return 'Minimum 6 caractères';
                        }
                        return null;
                      },
                    ),
                    // Indicateur force mot de passe
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _PasswordStrengthIndicator(
                        strength: _passwordStrength,
                        color: _strengthColor,
                        label: _strengthLabel,
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Créer mon compte',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: authState.isLoading,
                      onPressed: _submit,
                      gradient: AppColors.accentGradient,
                      glowColor: AppColors.accent,
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 550.ms)
                .slideY(begin: 0.12, curve: Curves.easeOutCubic),
            const SizedBox(height: 26),

            // ── Vers la connexion ───────────────────────────────────
            _LoginCallout(
              onTap: () => context.go('/login'),
            ).animate().fadeIn(delay: 540.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}

/// Invitation à se connecter, pendant du bloc équivalent de la connexion.
///
/// Une simple ligne « Déjà inscrit ? Se connecter » se perd sous le bouton
/// principal. En faire une surface cliquable entière double la cible et pose
/// clairement la seconde issue de l'écran, sans concurrencer le bouton
/// d'inscription — elle reste sans fond plein.
class _LoginCallout extends StatelessWidget {
  final VoidCallback onTap;

  const _LoginCallout({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            color: AppColors.glassWhite,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login_rounded, size: 17, color: AppColors.primaryText),
              const SizedBox(width: 10),
              // Même raison qu'à la connexion : deux `Text` rigides dans une
              // `Row` débordent sur écran étroit ou grande police système.
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Déjà inscrit ? ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Se connecter',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de rôle à l'inscription (Adhérent / Coach).
class _RoleSelector extends StatelessWidget {
  final String role;
  final ValueChanged<String> onChanged;

  const _RoleSelector({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleOption(
            icon: Icons.self_improvement_rounded,
            label: 'Adhérent',
            selected: role == 'ADHERENT',
            onTap: () => onChanged('ADHERENT'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleOption(
            icon: Icons.sports_gymnastics_rounded,
            label: 'Coach',
            selected: role == 'COACH',
            onTap: () => onChanged('COACH'),
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.glassWhite,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.accentText : AppColors.textHint,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected
                    ? AppColors.accentText
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final double strength;
  final Color color;
  final String label;

  const _PasswordStrengthIndicator({
    required this.strength,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Force du mot de passe', style: AppTextStyles.caption),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: strength,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

/// Champ tappable de sélection de la date de naissance (ouvre un DatePicker).
/// Style aligné sur [AppTextField] pour rester cohérent dans le formulaire.
class _BirthDateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;

  const _BirthDateField({required this.value, required this.onTap});

  String _format(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Date de naissance',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, color: AppColors.textHint, size: 22),
                const SizedBox(width: 14),
                Text(
                  hasValue ? _format(value!) : 'JJ/MM/AAAA',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: hasValue
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
