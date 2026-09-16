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

/// Écran de connexion — la **première impression** de l'application.
///
/// Le décor (fond animé, largeur maximale, gestion du clavier) est porté par
/// [AuthShell], partagé avec l'inscription : cet écran ne contient plus que son
/// formulaire.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Referme le clavier : sinon il masque le message d'erreur qui arrive
      // juste après un échec.
      FocusScope.of(context).unfocus();
      HapticFeedback.selectionClick();

      final success = await ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
      if (success && mounted) {
        context.go('/home');
      } else if (mounted) {
        final authState = ref.read(authProvider);

        // Compte existant mais email jamais vérifié : plutôt qu'une erreur
        // sans issue, on emmène l'utilisateur saisir son code (et un nouveau
        // code peut être demandé depuis cet écran).
        final pending = authState.pendingVerificationEmail;
        if (pending != null) {
          context.go('/verify-email', extra: {'email': pending});
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                authState.errorMessage ?? 'Erreur d\'authentification',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  /// « Mot de passe oublié ? » — dit la vérité.
  ///
  /// Ce lien était un **bouton mort** (`onPressed: () {}`) : il ne faisait
  /// strictement rien. Un utilisateur qui a réellement oublié son mot de passe
  /// tape dessus, ne voit rien se produire, et conclut que l'application est
  /// cassée — ce qui est pire que de ne rien proposer.
  ///
  /// Le backend n'expose aucune route de réinitialisation. Tant qu'elle
  /// n'existe pas, la seule réponse honnête est de le dire et de donner un
  /// chemin réel.
  void _showPasswordHelp() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.primaryText,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  // `Expanded` : avec une grande police système, un titre
                  // rigide dans une `Row` déborde (mesuré à 6 px de trop).
                  Expanded(
                    child: Text(
                      'Mot de passe oublié',
                      style: AppTextStyles.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'La réinitialisation automatique n\'est pas encore disponible. '
                'Écrivez-nous à l\'adresse ci-dessous avec l\'email de votre '
                'compte, nous le réinitialisons manuellement.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: AppColors.accentText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        'unityforce.dev@gmail.com',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'J\'ai compris',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
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
            Center(
              child: const AuthLogo(size: 100)
                  .animate()
                  .fadeIn(duration: 700.ms)
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    curve: Curves.easeOutBack,
                    duration: 900.ms,
                  ),
            ),
            const SizedBox(height: 20),

            // Le nom porte le dégradé de la marque. `Rect` généreux : un
            // shader plus étroit que le texte laisserait la fin du mot sans
            // couleur sur un grand écran ou une police agrandie.
            Text(
                  'FitForge',
                  style: AppTextStyles.displayLarge.copyWith(
                    foreground: Paint()
                      ..shader = AppColors.heroGradient.createShader(
                        const Rect.fromLTWH(0, 0, 420, 70),
                      ),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 180.ms, duration: 550.ms)
                .slideY(begin: 0.25, curve: Curves.easeOutCubic),
            const SizedBox(height: 6),
            Text(
              'Votre coach intelligent & personnalisé',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 320.ms, duration: 550.ms),
            const SizedBox(height: 34),

            // ── Le formulaire ───────────────────────────────────────
            AuthGlassCard(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: AppColors.primaryGlow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Connexion', style: AppTextStyles.headingSmall),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _emailController,
                      hint: 'votre.email@exemple.com',
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      // `next` : le clavier propose d'enchaîner sur le mot de passe
                      // au lieu de se refermer au milieu du formulaire.
                      textInputAction: TextInputAction.next,
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
                      suffix: IconButton(
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
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
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showPasswordHelp,
                        child: Text(
                          'Mot de passe oublié ?',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Se connecter',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: authState.isLoading,
                      onPressed: _submit,
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 420.ms, duration: 550.ms)
                .slideY(begin: 0.12, curve: Curves.easeOutCubic),
            const SizedBox(height: 26),

            // ── Vers l'inscription ──────────────────────────────────
            // Le séparateur « OU » a été retiré : il annonçait une alternative
            // de connexion (« ou avec Google »), alors qu'il ne précédait qu'un
            // lien vers la création de compte. Un intitulé qui promet autre
            // chose que ce qui suit est une fausse piste.
            _SignupCallout(
              onTap: () => context.go('/signup'),
            ).animate().fadeIn(delay: 540.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}

/// Invitation à créer un compte.
///
/// Une simple ligne « Pas encore de compte ? S'inscrire » se perd sous le bouton
/// principal. En faire une **surface cliquable entière** double la cible et pose
/// clairement la seconde issue de l'écran — sans jamais concurrencer le bouton
/// de connexion, puisqu'elle reste sans fond plein.
class _SignupCallout extends StatelessWidget {
  final VoidCallback onTap;

  const _SignupCallout({required this.onTap});

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
              Icon(
                Icons.person_add_alt_rounded,
                size: 17,
                color: AppColors.accentText,
              ),
              const SizedBox(width: 10),
              // `Flexible` + `Text.rich` et non deux `Text` côte à côte : sur un
              // écran étroit ou avec une grande police système, deux textes
              // rigides dans une `Row` débordent (mesuré à 67 px de trop). Une
              // seule phrase riche se replie sur deux lignes.
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Pas encore de compte ? ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'S\'inscrire',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.accentText,
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
