import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/program_models.dart';
import '../providers/program_provider.dart';
import '../../../../core/widgets/screen_background.dart';

/// Création (ou édition) d'un programme personnel : titre, description,
/// objectif, niveau et durée. À la création, redirige vers le détail pour y
/// ajouter des séances.
class CreateProgramScreen extends ConsumerStatefulWidget {
  /// Programme existant à éditer (null = création).
  final ProgramModel? existing;

  /// Si renseigné : un COACH crée ce programme POUR cet adhérent.
  final String? forMemberUserId;
  final String? forMemberName;

  const CreateProgramScreen({
    super.key,
    this.existing,
    this.forMemberUserId,
    this.forMemberName,
  });

  @override
  ConsumerState<CreateProgramScreen> createState() =>
      _CreateProgramScreenState();
}

class _CreateProgramScreenState extends ConsumerState<CreateProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _weeks = TextEditingController(
    text: widget.existing?.durationWeeks?.toString() ?? '',
  );

  late String _goal = widget.existing?.goal ?? kGoalOptions.first.value;
  late String _level =
      widget.existing?.experienceLevel ?? kLevelOptions.first.value;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;
  bool get _forMember => widget.forMemberUserId != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _weeks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final notifier = ref.read(programsProvider.notifier);
    final title = _title.text.trim();
    final desc = _description.text.trim();
    final weeks = int.tryParse(_weeks.text.trim());
    try {
      if (_isEdit) {
        final updated = await ref
            .read(programApiProvider)
            .updateProgram(
              widget.existing!.id,
              title: title,
              description: desc,
              goal: _goal,
              experienceLevel: _level,
              durationWeeks: weeks,
            );
        notifier.upsertMyProgram(updated);
        if (mounted) context.pop(true);
      } else if (_forMember) {
        // Un coach compose un programme pour son adhérent.
        final created = await ref
            .read(programApiProvider)
            .createProgramForMember(
              widget.forMemberUserId!,
              title: title,
              description: desc,
              goal: _goal,
              experienceLevel: _level,
              durationWeeks: weeks,
            );
        if (mounted) {
          HapticFeedback.mediumImpact();
          context.pushReplacement('/coach/program/${created.id}');
        }
      } else {
        final created = await notifier.createProgram(
          title: title,
          description: desc,
          goal: _goal,
          experienceLevel: _level,
          durationWeeks: weeks,
        );
        if (mounted) {
          HapticFeedback.mediumImpact();
          context.pushReplacement('/programs/detail/${created.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
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
        title: Text(
          _isEdit
              ? 'Modifier le programme'
              : _forMember
              ? 'Programme pour ${widget.forMemberName ?? 'l\'adhérent'}'
              : 'Nouveau programme',
        ),
      ),
      body: ScreenBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                AppTextField(
                  controller: _title,
                  label: 'Nom du programme',
                  hint: 'Ex : Ma prise de masse',
                  prefixIcon: Icons.title_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Donnez un nom à votre programme'
                      : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _description,
                  label: 'Description (optionnel)',
                  hint: 'Objectif, fréquence, remarques…',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 20),
                Text('Objectif', style: AppTextStyles.labelSmall),
                const SizedBox(height: 8),
                _ChoiceChips(
                  options: kGoalOptions,
                  selected: _goal,
                  onSelected: (v) => setState(() => _goal = v),
                ),
                const SizedBox(height: 20),
                Text('Niveau', style: AppTextStyles.labelSmall),
                const SizedBox(height: 8),
                _ChoiceChips(
                  options: kLevelOptions,
                  selected: _level,
                  onSelected: (v) => setState(() => _level = v),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _weeks,
                  label: 'Durée en semaines (optionnel)',
                  hint: 'Ex : 6',
                  prefixIcon: Icons.calendar_today_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) {
                      return 'Nombre de semaines invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                PrimaryButton(
                  label: _isEdit ? 'Enregistrer' : 'Créer le programme',
                  icon: Icons.check_rounded,
                  isLoading: _busy,
                  onPressed: _busy ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

class _ChoiceChips extends StatelessWidget {
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChoiceChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o.value == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(o.value);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSel
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.card,
              border: Border.all(
                color: isSel ? AppColors.primary : AppColors.border,
                width: 1.2,
              ),
            ),
            child: Text(
              o.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSel ? AppColors.primaryText : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
