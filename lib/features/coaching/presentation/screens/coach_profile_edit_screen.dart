import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/coaching_models.dart';
import '../providers/coaching_provider.dart';
import '../../../../core/widgets/screen_background.dart';

/// Construction / édition du profil professionnel du coach : accroche, bio,
/// expérience, spécialités, certifications, formations et expériences.
class CoachProfileEditScreen extends ConsumerStatefulWidget {
  /// true = juste après l'inscription (redirige vers le dashboard après save).
  final bool firstTime;
  const CoachProfileEditScreen({super.key, this.firstTime = false});

  @override
  ConsumerState<CoachProfileEditScreen> createState() =>
      _CoachProfileEditScreenState();
}

class _CoachProfileEditScreenState
    extends ConsumerState<CoachProfileEditScreen> {
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _years = TextEditingController();
  final _rate = TextEditingController();
  final _city = TextEditingController();
  bool _accepting = true;
  final Set<String> _specialties = {};
  final List<Certification> _certs = [];
  final List<Education> _edus = [];
  final List<ExperienceItem> _exps = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(coachingApiProvider).getMyCoachProfile();
      if (!mounted) return;
      setState(() {
        _headline.text = p.headline ?? '';
        _bio.text = p.bio ?? '';
        _years.text = p.yearsExperience?.toString() ?? '';
        _rate.text = p.hourlyRate?.toStringAsFixed(0) ?? '';
        _city.text = p.city ?? '';
        _accepting = p.acceptingClients;
        _specialties.addAll(p.specialties);
        _certs.addAll(p.certifications);
        _edus.addAll(p.educations);
        _exps.addAll(p.experiences);
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

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    _years.dispose();
    _rate.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(coachingApiProvider)
          .upsertMyCoachProfile(
            headline: _headline.text.trim().isEmpty
                ? null
                : _headline.text.trim(),
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            yearsExperience: int.tryParse(_years.text.trim()),
            hourlyRate: double.tryParse(_rate.text.trim().replaceAll(',', '.')),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            acceptingClients: _accepting,
            specialties: _specialties.toList(),
            certifications: _certs,
            educations: _edus,
            experiences: _exps,
          );
      ref.invalidate(myCoachProfileProvider);
      invalidateCoachingW(ref);
      if (!mounted) return;
      if (widget.firstTime) {
        context.go('/coach');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstTime ? 'Créer mon profil coach' : 'Mon profil'),
      ),
      body: ScreenBackground(child: SafeArea(child: _body())),
    );
  }

  Widget _body() {
    if (_loading) {
      return const AppListSkeleton(itemCount: 4, itemHeight: 80);
    }
    if (_error != null) {
      return AppErrorState(message: _error, onRetry: _load);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        AppTextField(
          controller: _headline,
          label: 'Accroche',
          hint: 'Ex : Coach force & prise de masse',
          prefixIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _bio,
          label: 'À propos de vous',
          hint: 'Parcours, méthode, philosophie…',
          prefixIcon: Icons.notes_rounded,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _years,
                label: 'Années d\'expérience',
                hint: '8',
                prefixIcon: Icons.workspace_premium_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _rate,
                label: 'Tarif (DT/séance)',
                hint: '40',
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _city,
          label: 'Ville / zone',
          hint: 'Tunis',
          prefixIcon: Icons.place_outlined,
        ),
        const SizedBox(height: 20),

        // Disponibilité
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: Text(
              'J\'accepte de nouveaux adhérents',
              style: AppTextStyles.bodyMedium,
            ),
            value: _accepting,
            onChanged: (v) => setState(() => _accepting = v),
          ),
        ),
        const SizedBox(height: 22),

        // Spécialités
        _SectionLabel('Spécialités'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSpecialties.map((s) {
            final sel = _specialties.contains(s.value);
            return GestureDetector(
              onTap: () => setState(() {
                sel ? _specialties.remove(s.value) : _specialties.add(s.value);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: sel
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.card,
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  s.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: sel
                        ? AppColors.primaryText
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Certifications
        _EditableSection(
          title: 'Certifications',
          items: _certs
              .map(
                (c) => _itemLabel(c.title, c.organization, c.year?.toString()),
              )
              .toList(),
          onAdd: _addCertification,
          onRemove: (i) => setState(() => _certs.removeAt(i)),
        ),
        const SizedBox(height: 20),

        // Formations
        _EditableSection(
          title: 'Formations',
          items: _edus
              .map(
                (e) => _itemLabel(e.degree, e.institution, e.year?.toString()),
              )
              .toList(),
          onAdd: _addEducation,
          onRemove: (i) => setState(() => _edus.removeAt(i)),
        ),
        const SizedBox(height: 20),

        // Expériences
        _EditableSection(
          title: 'Expériences',
          items: _exps
              .map((e) => _itemLabel(e.title, e.organization, e.periodLabel))
              .toList(),
          onAdd: _addExperience,
          onRemove: (i) => setState(() => _exps.removeAt(i)),
        ),
        const SizedBox(height: 30),

        PrimaryButton(
          label: widget.firstTime ? 'Créer mon profil' : 'Enregistrer',
          icon: Icons.check_rounded,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  static String _itemLabel(String title, String? sub, String? trailing) {
    final parts = [title];
    if (sub != null && sub.isNotEmpty) parts.add(sub);
    if (trailing != null && trailing.isNotEmpty) parts.add(trailing);
    return parts.join(' · ');
  }

  // ── Dialogs d'ajout ────────────────────────────────────────────

  Future<void> _addCertification() async {
    final res = await _multiFieldDialog(
      'Ajouter une certification',
      const ['Intitulé *', 'Organisme', 'Année'],
      const [TextInputType.text, TextInputType.text, TextInputType.number],
    );
    if (res == null || res[0].trim().isEmpty) return;
    setState(
      () => _certs.add(
        Certification(
          title: res[0].trim(),
          organization: res[1].trim().isEmpty ? null : res[1].trim(),
          year: int.tryParse(res[2].trim()),
        ),
      ),
    );
  }

  Future<void> _addEducation() async {
    final res = await _multiFieldDialog(
      'Ajouter une formation',
      const ['Diplôme *', 'Établissement', 'Domaine', 'Année'],
      const [
        TextInputType.text,
        TextInputType.text,
        TextInputType.text,
        TextInputType.number,
      ],
    );
    if (res == null || res[0].trim().isEmpty) return;
    setState(
      () => _edus.add(
        Education(
          degree: res[0].trim(),
          institution: res[1].trim().isEmpty ? null : res[1].trim(),
          fieldOfStudy: res[2].trim().isEmpty ? null : res[2].trim(),
          year: int.tryParse(res[3].trim()),
        ),
      ),
    );
  }

  Future<void> _addExperience() async {
    final res = await _multiFieldDialog(
      'Ajouter une expérience',
      const ['Poste *', 'Structure', 'Année début', 'Année fin', 'Description'],
      const [
        TextInputType.text,
        TextInputType.text,
        TextInputType.number,
        TextInputType.number,
        TextInputType.multiline,
      ],
    );
    if (res == null || res[0].trim().isEmpty) return;
    setState(
      () => _exps.add(
        ExperienceItem(
          title: res[0].trim(),
          organization: res[1].trim().isEmpty ? null : res[1].trim(),
          startYear: int.tryParse(res[2].trim()),
          endYear: int.tryParse(res[3].trim()),
          description: res[4].trim().isEmpty ? null : res[4].trim(),
        ),
      ),
    );
  }

  Future<List<String>?> _multiFieldDialog(
    String title,
    List<String> labels,
    List<TextInputType> types,
  ) {
    final controllers = List.generate(
      labels.length,
      (_) => TextEditingController(),
    );
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: AppTextStyles.headingSmall),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                AppTextField(
                  controller: controllers[i],
                  hint: labels[i],
                  keyboardType: types[i],
                  maxLines: types[i] == TextInputType.multiline ? 3 : 1,
                  textInputAction: types[i] == TextInputType.multiline
                      ? TextInputAction.newline
                      : TextInputAction.next,
                ),
              ],
            ],
          ),
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
            onPressed: () =>
                Navigator.of(ctx).pop(controllers.map((c) => c.text).toList()),
            child: Text(
              'Ajouter',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.headingSmall);
}

class _EditableSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _EditableSection({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.headingSmall)),
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.primaryText,
              ),
              label: Text(
                'Ajouter',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        if (items.isEmpty)
          Text(
            'Rien pour le moment.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          )
        else
          ...items.asMap().entries.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.value,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => onRemove(e.key),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
