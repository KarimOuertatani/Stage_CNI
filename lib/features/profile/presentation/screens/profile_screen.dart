import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatar_picker.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/profile_provider.dart';
import '../../../../core/widgets/screen_background.dart';

/// Écran Profil : données physiques & sportives de l'adhérent.
/// Affiche les valeurs calculées (IMC, TDEE, âge) et le score, et permet
/// d'éditer le profil (le backend recalcule IMC/TDEE à l'enregistrement).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _weeklyTargetCtrl = TextEditingController();

  String? _gender;
  String? _goal;
  String? _activity;
  String? _experience;
  bool _initialized = false;

  // ── Libellés des enums (valeur backend -> libellé FR) ──────────
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
    _weeklyTargetCtrl.dispose();
    super.dispose();
  }

  /// Pré-remplit le formulaire une fois le profil chargé.
  void _initFromProfile() {
    final p = ref.read(profileProvider).profile;
    if (p == null || _initialized) return;
    _initialized = true;
    _heightCtrl.text = p.heightCm?.toStringAsFixed(0) ?? '';
    _weightCtrl.text = p.currentWeightKg?.toStringAsFixed(1) ?? '';
    _targetWeightCtrl.text = p.targetWeightKg?.toStringAsFixed(1) ?? '';
    _weeklyTargetCtrl.text = p.weeklyWorkoutTarget?.toString() ?? '';
    _gender = p.gender;
    _goal = p.goal;
    _activity = p.activityLevel;
    _experience = p.experienceLevel;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final fields = <String, dynamic>{
      'heightCm': double.tryParse(_heightCtrl.text.replaceAll(',', '.')),
      'currentWeightKg': double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
      'targetWeightKg': double.tryParse(
        _targetWeightCtrl.text.replaceAll(',', '.'),
      ),
      'weeklyWorkoutTarget': int.tryParse(_weeklyTargetCtrl.text),
      'gender': _gender,
      'goal': _goal,
      'activityLevel': _activity,
      'experienceLevel': _experience,
    };
    final ok = await ref.read(profileProvider.notifier).updateProfile(fields);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profil mis à jour' : 'Échec de la mise à jour'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    // Initialise le formulaire dès que le profil est disponible.
    _initFromProfile();

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ScreenBackground(child: SafeArea(child: _buildBody(state))),
    );
  }

  Widget _buildBody(ProfileState state) {
    if (state.isLoading && state.profile == null) {
      return const AppListSkeleton(itemCount: 4, itemHeight: 120);
    }
    if (state.profile == null) {
      return AppErrorState(
        message: 'Impossible de charger votre profil.',
        onRetry: () => ref.read(profileProvider.notifier).load(),
      );
    }

    final p = state.profile!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _header(p.fullName, p.age),
        const SizedBox(height: 20),

        // ── Indicateurs calculés ──────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _statCard(
                'IMC',
                p.bmi?.toStringAsFixed(1) ?? '—',
                Icons.monitor_weight_outlined,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'TDEE',
                p.tdee != null ? '${p.tdee}' : '—',
                Icons.local_fire_department_outlined,
                AppColors.accent,
                unit: 'kcal/j',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Poids',
                p.currentWeightKg != null ? '${p.currentWeightKg}' : '—',
                Icons.scale_outlined,
                Colors.blueAccent,
                unit: 'kg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Objectif',
                p.targetWeightKg != null ? '${p.targetWeightKg}' : '—',
                Icons.flag_outlined,
                AppColors.success,
                unit: 'kg',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Score d'entraînement ──────────────────────────────────
        _scoreCard(state),
        const SizedBox(height: 24),

        // ── Formulaire d'édition ──────────────────────────────────
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Mes informations', style: AppTextStyles.headingSmall),
          ],
        ),
        const SizedBox(height: 16),

        _dropdown(
          'Sexe',
          _genders,
          _gender,
          (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _heightCtrl,
                label: 'Taille (cm)',
                hint: '178',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _weightCtrl,
                label: 'Poids (kg)',
                hint: '74.5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _targetWeightCtrl,
                label: 'Poids visé (kg)',
                hint: '70',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _weeklyTargetCtrl,
                label: 'Séances / semaine',
                hint: '4',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _dropdown('Objectif', _goals, _goal, (v) => setState(() => _goal = v)),
        const SizedBox(height: 14),
        _dropdown(
          'Rythme de vie',
          _activities,
          _activity,
          (v) => setState(() => _activity = v),
        ),
        const SizedBox(height: 14),
        _dropdown(
          'Niveau',
          _experiences,
          _experience,
          (v) => setState(() => _experience = v),
        ),
        const SizedBox(height: 24),

        PrimaryButton(
          label: 'Enregistrer',
          icon: Icons.check_rounded,
          isLoading: state.isSaving,
          onPressed: _save,
          gradient: AppColors.primaryGradient,
          glowColor: AppColors.primary,
        ),

        const SizedBox(height: 28),

        // ── Aide ──────────────────────────────────────────────────
        //
        // Placé en bas du profil et non dans un menu : c'est là qu'on va
        // chercher « les réglages », et c'est le seul endroit stable de
        // l'application quand un écran ne répond plus.
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/signalements'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signaler un problème',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Un bug, une donnée fausse, une idée — on lit tout",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Widgets ──────────────────────────────────────────────────

  Widget _header(String name, int? age) {
    return Row(
      children: [
        AvatarPicker(
          size: 68,
          gradient: AppColors.heroGradient,
          onChanged: () => ref.read(profileProvider.notifier).load(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.headingMedium),
              const SizedBox(height: 4),
              Text(
                age != null ? '$age ans' : 'Âge non renseigné',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tuile de statistique (IMC, TDEE, Poids, Objectif).
  ///
  /// Ces tuiles vivent deux par ligne : sur un téléphone de 360 dp, chacune ne
  /// dispose que d'environ 122 px de contenu. Une valeur large comme « 2450 »
  /// suivie de « kcal/j » débordait horizontalement, et le libellé pouvait
  /// pousser l'icône hors du cadre. Trois protections :
  ///  • libellé `Expanded` + ellipsis ;
  ///  • valeur dans un `FittedBox(scaleDown)` — elle rétrécit au lieu de déborder ;
  ///  • unité `Flexible` + ellipsis.
  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? unit,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      backgroundColor: AppColors.glassSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTextStyles.statValue.copyWith(color: color),
                  maxLines: 1,
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard(ProfileState state) {
    final score = state.score;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Score d\'entraînement', style: AppTextStyles.headingSmall),
              const Spacer(),
              if (score != null)
                Text(
                  '${score.score}/100',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.accentText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            score?.insight ??
                'Aucun score encore. Enregistre une séance puis recalcule.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (score != null) ...[
            const SizedBox(height: 8),
            Text(
              '${score.sessionsCompleted} séance(s) • ${score.weeklyVolumeKg.toStringAsFixed(0)} kg de volume',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(profileProvider.notifier).recomputeScore();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Recalculer mon score'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentText),
          ),
        ],
      ),
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
}
