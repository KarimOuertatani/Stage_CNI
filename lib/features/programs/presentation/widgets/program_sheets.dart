import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../workout/data/exercise_query.dart';
import '../../../workout/data/workout_model.dart';
import '../../../workout/presentation/providers/exercise_favorites_provider.dart';
import '../../../workout/presentation/providers/workout_provider.dart';
import '../../../workout/presentation/widgets/exercise_search.dart';
import '../../../workout/presentation/widgets/exercise_visuals.dart';
import '../../data/program_models.dart';

/// Enveloppe commune des bottom sheets : coins arrondis, poignée, fond carte.
class _SheetShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headingSmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Résultat de l'édition d'une séance.
typedef SessionData = ({String title, int? dayOfWeek});

/// Formulaire d'ajout / modification d'une séance (titre + jour prévu).
Future<SessionData?> showSessionSheet(
  BuildContext context, {
  SessionData? initial,
}) {
  return showModalBottomSheet<SessionData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SessionSheet(initial: initial),
  );
}

class _SessionSheet extends StatefulWidget {
  final SessionData? initial;
  const _SessionSheet({this.initial});

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  int? _day;

  @override
  void initState() {
    super.initState();
    _day = widget.initial?.dayOfWeek;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: widget.initial == null ? 'Nouvelle séance' : 'Modifier la séance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _title,
            label: 'Nom de la séance',
            hint: 'Ex : Push - Pectoraux / Épaules',
            prefixIcon: Icons.event_note_rounded,
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          Text('Jour prévu (optionnel)', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int d = 1; d <= 7; d++)
                _DayChip(
                  label: dayOfWeekLabelFr(d)!.substring(0, 3),
                  selected: _day == d,
                  onTap: () => setState(() => _day = _day == d ? null : d),
                ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Enregistrer',
            icon: Icons.check_rounded,
            onPressed: () {
              final title = _title.text.trim();
              if (title.isEmpty) return;
              Navigator.of(context).pop((title: title, dayOfWeek: _day));
            },
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.primaryText : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Sélecteur d'exercice depuis le référentiel (recherche + filtrage simple).
/// Renvoie l'exercice choisi (id + nom + groupe) ou null si annulé.
Future<WorkoutModel?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<WorkoutModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ExercisePickerSheet(),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet();

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  // Le même moteur que la bibliothèque : recherche insensible aux accents,
  // classement par pertinence, filtres niveau/matériel. Composer un programme
  // et parcourir le catalogue ne doivent pas obéir à deux logiques différentes.
  ExerciseQuery _query = const ExerciseQuery();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);
    final all = state.exercises;
    final filtered = _query.apply(all, favoriteIds: favoriteIds);

    final height = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Choisir un exercice', style: AppTextStyles.headingSmall),
                const Spacer(),
                Text(
                  '${filtered.length}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ExerciseSearchField(
              value: _query.text,
              onChanged: (v) =>
                  setState(() => _query = _query.copyWith(text: v)),
              hint: 'Rechercher (nom, muscle, matériel)…',
            ),
            const SizedBox(height: 10),
            ExerciseFilterBar(
              query: _query,
              onChanged: (q) => setState(() => _query = q),
              catalog: all,
              horizontalPadding: 0,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun exercice trouvé.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        return _PickerRow(
                          exercise: e,
                          onTap: () => Navigator.of(context).pop(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final WorkoutModel exercise;
  final VoidCallback onTap;

  const _PickerRow({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ExerciseThumbnail(exercise: exercise, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: levelColor(exercise.level),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [
                              exercise.muscleGroup,
                              if (exercise.equipmentLabel != null)
                                exercise.equipmentLabel!,
                            ].join(' · '),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primaryText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Objectifs d'un exercice placé.
typedef TargetsData = ({int? sets, int? reps, double? weight, int? rest});

/// Saisie des objectifs (séries / répétitions / charge / repos) d'un exercice.
Future<TargetsData?> showTargetsSheet(
  BuildContext context, {
  required String exerciseName,
  TargetsData? initial,
}) {
  return showModalBottomSheet<TargetsData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _TargetsSheet(exerciseName: exerciseName, initial: initial),
  );
}

class _TargetsSheet extends StatefulWidget {
  final String exerciseName;
  final TargetsData? initial;
  const _TargetsSheet({required this.exerciseName, this.initial});

  @override
  State<_TargetsSheet> createState() => _TargetsSheetState();
}

class _TargetsSheetState extends State<_TargetsSheet> {
  late final TextEditingController _sets = TextEditingController(
    text: widget.initial?.sets?.toString() ?? '4',
  );
  late final TextEditingController _reps = TextEditingController(
    text: widget.initial?.reps?.toString() ?? '10',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.initial?.weight != null
        ? widget.initial!.weight!.toStringAsFixed(
            widget.initial!.weight! % 1 == 0 ? 0 : 1,
          )
        : '',
  );
  late final TextEditingController _rest = TextEditingController(
    text: widget.initial?.rest?.toString() ?? '90',
  );

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: widget.exerciseName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _sets,
                  label: 'Séries',
                  hint: '4',
                  prefixIcon: Icons.repeat_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _reps,
                  label: 'Répétitions',
                  hint: '10',
                  prefixIcon: Icons.tag_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _weight,
                  label: 'Charge (kg)',
                  hint: 'ex : 60',
                  prefixIcon: Icons.monitor_weight_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _rest,
                  label: 'Repos (s)',
                  hint: '90',
                  prefixIcon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Ajouter à la séance',
            icon: Icons.check_rounded,
            onPressed: () {
              Navigator.of(context).pop((
                sets: int.tryParse(_sets.text.trim()),
                reps: int.tryParse(_reps.text.trim()),
                weight: double.tryParse(
                  _weight.text.trim().replaceAll(',', '.'),
                ),
                rest: int.tryParse(_rest.text.trim()),
              ));
            },
          ),
        ],
      ),
    );
  }
}
