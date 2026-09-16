import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/profile_provider.dart';
import '../../../../core/widgets/screen_background.dart';

/// Écran d'onboarding affiché juste après l'inscription : collecte les données
/// physiques et sportives de l'adhérent (genre, poids, taille, objectif...).
/// À la validation, on fait un PUT /profile (le backend calcule IMC/TDEE et
/// marque l'onboarding terminé), puis on entre dans l'application.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();

  String? _gender;
  String? _goal;
  String? _activity;
  String? _experience;
  int _weeklyTarget = 3;

  static const _genders = {
    'HOMME': 'Homme',
    'FEMME': 'Femme',
    'AUTRE': 'Autre',
  };
  static const _goals = {
    'PERTE_POIDS': 'Perte de poids',
    'PRISE_MASSE': 'Prise de masse',
    'MAINTIEN': 'Maintien',
    'FORCE': 'Force',
    'ENDURANCE': 'Endurance',
  };
  static const _activities = {
    'SEDENTAIRE': 'Sédentaire',
    'LEGER': 'Léger',
    'MODERE': 'Modéré',
    'ACTIF': 'Actif',
    'TRES_ACTIF': 'Très actif',
  };
  static const _experiences = {
    'DEBUTANT': 'Débutant',
    'INTERMEDIAIRE': 'Intermédiaire',
    'AVANCE': 'Avancé',
  };

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    final fields = <String, dynamic>{
      'gender': _gender,
      'heightCm': double.tryParse(_heightCtrl.text.replaceAll(',', '.')),
      'currentWeightKg': double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
      'targetWeightKg': double.tryParse(
        _targetWeightCtrl.text.replaceAll(',', '.'),
      ),
      'goal': _goal,
      'activityLevel': _activity,
      'experienceLevel': _experience,
      'weeklyWorkoutTarget': _weeklyTarget,
    };
    final ok = await ref.read(profileProvider.notifier).updateProfile(fields);
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer. Réessayez.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(profileProvider).isSaving;

    return Scaffold(
      body: ScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── En-tête ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bienvenue 👋',
                          style: AppTextStyles.overline.copyWith(
                            color: AppColors.accentText,
                            letterSpacing: 1.5,
                          ),
                        ),
                        TextButton(
                          onPressed: saving ? null : () => context.go('/home'),
                          child: Text(
                            'Plus tard',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Parlez-nous de vous',
                      style: AppTextStyles.displayMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ces infos personnalisent vos calculs (IMC, calories) et vos programmes.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

              // ── Formulaire ──────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            'Mon corps',
                            Icons.accessibility_new_rounded,
                          ),
                          const SizedBox(height: 14),
                          _chips(
                            'Sexe',
                            _genders,
                            _gender,
                            (v) => setState(() => _gender = v),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _heightCtrl,
                                  label: 'Taille (cm)',
                                  hint: '178',
                                  keyboardType: TextInputType.number,
                                  accentColor: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  controller: _weightCtrl,
                                  label: 'Poids (kg)',
                                  hint: '74.5',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  accentColor: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _targetWeightCtrl,
                            label: 'Poids visé (kg)',
                            hint: '70',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            accentColor: AppColors.accent,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                    const SizedBox(height: 16),

                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Mon objectif', Icons.flag_rounded),
                          const SizedBox(height: 14),
                          _chips(
                            'Objectif principal',
                            _goals,
                            _goal,
                            (v) => setState(() => _goal = v),
                          ),
                          const SizedBox(height: 16),
                          _chips(
                            'Niveau',
                            _experiences,
                            _experience,
                            (v) => setState(() => _experience = v),
                          ),
                          const SizedBox(height: 16),
                          _dropdown(
                            'Rythme de vie',
                            _activities,
                            _activity,
                            (v) => setState(() => _activity = v),
                          ),
                          const SizedBox(height: 18),
                          _weeklyStepper(),
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                  ],
                ),
              ),

              // ── CTA ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  label: 'C\'est parti',
                  icon: Icons.rocket_launch_rounded,
                  isLoading: saving,
                  onPressed: _finish,
                  gradient: AppColors.accentGradient,
                  glowColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headingSmall),
      ],
    );
  }

  Widget _chips(
    String label,
    Map<String, String> options,
    String? selected,
    ValueChanged<String> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((e) {
            final isSel = selected == e.key;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(e.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSel ? AppColors.accentGradient : null,
                  color: isSel ? null : AppColors.glassWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Text(
                  e.value,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSel
                        ? AppColors.onGradient
                        : AppColors.textSecondary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    Map<String, String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                'Sélectionner',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
              dropdownColor: AppColors.surface,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textHint,
              ),
              style: AppTextStyles.bodyLarge,
              items: options.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _weeklyStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Séances par semaine', style: AppTextStyles.labelMedium),
            const SizedBox(height: 2),
            Text(
              'Votre objectif d\'assiduité',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
        Row(
          children: [
            _stepBtn(Icons.remove_rounded, () {
              if (_weeklyTarget > 1) setState(() => _weeklyTarget--);
            }),
            SizedBox(
              width: 36,
              child: Text(
                '$_weeklyTarget',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingSmall,
              ),
            ),
            _stepBtn(Icons.add_rounded, () {
              if (_weeklyTarget < 14) setState(() => _weeklyTarget++);
            }),
          ],
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.accentText),
      ),
    );
  }
}
