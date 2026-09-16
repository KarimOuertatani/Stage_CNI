import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/neon_badge.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../workout/data/workout_log_args.dart';
import '../../data/program_models.dart';
import '../providers/program_provider.dart';
import '../widgets/program_sheets.dart';
import '../../../../core/widgets/screen_background.dart';

/// Détail d'un programme : en-tête + liste des séances (chaque séance étant un
/// ensemble d'exercices). En mode [isTemplate], propose d'« adopter » le modèle.
/// En mode personnel, permet d'éditer les séances et leurs exercices.
class ProgramDetailScreen extends ConsumerStatefulWidget {
  final String programId;
  final bool isTemplate;

  /// true quand un COACH consulte/édite un programme composé pour un adhérent
  /// (on ne touche alors pas au provider « mes programmes » de l'adhérent).
  final bool coachMode;

  const ProgramDetailScreen({
    super.key,
    required this.programId,
    this.isTemplate = false,
    this.coachMode = false,
  });

  @override
  ConsumerState<ProgramDetailScreen> createState() =>
      _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  ProgramModel? _program;
  bool _loading = true;
  String? _error;
  bool _busy = false; // opération d'écriture en cours

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
      final api = ref.read(programApiProvider);
      final p = widget.isTemplate
          ? await api.getTemplate(widget.programId)
          : await api.getProgram(widget.programId);
      if (!mounted) return;
      setState(() {
        _program = p;
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

  bool get _editable => !widget.isTemplate;

  /// Applique le programme renvoyé par le backend + synchronise la liste.
  void _apply(ProgramModel updated) {
    setState(() => _program = updated);
    // Côté coach, la liste « mes programmes » de l'adhérent ne nous concerne pas.
    if (!widget.coachMode) {
      ref.read(programsProvider.notifier).upsertMyProgram(updated);
    }
  }

  Future<void> _run(Future<ProgramModel> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _apply(await action());
    } catch (e) {
      _snack(_msg(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Actions modèle ────────────────────────────────────────────

  Future<void> _adopt() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final copy = await ref
          .read(programsProvider.notifier)
          .adoptTemplate(widget.programId);
      if (!mounted) return;
      _snack('Programme ajouté à « Mes programmes » !');
      context.pushReplacement('/programs/detail/${copy.id}');
    } catch (e) {
      _snack(_msg(e), isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Actions programme personnel ───────────────────────────────

  Future<void> _editProgram() async {
    final p = _program!;
    final changed = await context.push<bool>(
      '/programs/edit/${p.id}',
      extra: p,
    );
    if (changed == true) _load();
  }

  Future<void> _deleteProgram() async {
    final ok = await _confirm(
      title: 'Supprimer le programme ?',
      message: 'Cette action supprimera le programme et toutes ses séances.',
    );
    if (ok != true) return;
    try {
      if (widget.coachMode) {
        await ref.read(programApiProvider).deleteProgram(widget.programId);
      } else {
        await ref
            .read(programsProvider.notifier)
            .deleteProgram(widget.programId);
      }
      if (mounted) context.pop();
    } catch (e) {
      _snack(_msg(e), isError: true);
    }
  }

  Future<void> _addSession() async {
    final data = await showSessionSheet(context);
    if (data == null) return;
    await _run(
      () => ref
          .read(programApiProvider)
          .addSession(
            widget.programId,
            title: data.title,
            dayOfWeek: data.dayOfWeek,
          ),
    );
  }

  Future<void> _editSession(SessionModel s) async {
    final data = await showSessionSheet(
      context,
      initial: (title: s.title, dayOfWeek: s.dayOfWeek),
    );
    if (data == null) return;
    await _run(
      () => ref
          .read(programApiProvider)
          .updateSession(s.id, title: data.title, dayOfWeek: data.dayOfWeek),
    );
  }

  Future<void> _deleteSession(SessionModel s) async {
    final ok = await _confirm(
      title: 'Supprimer la séance ?',
      message: '« ${s.title} » et ses exercices seront supprimés.',
    );
    if (ok != true) return;
    await _run(() => ref.read(programApiProvider).deleteSession(s.id));
  }

  Future<void> _addExercise(SessionModel s) async {
    final exercise = await showExercisePicker(context);
    if (exercise == null || !mounted) return;
    final targets = await showTargetsSheet(
      context,
      exerciseName: exercise.name,
    );
    if (targets == null) return;
    await _run(
      () => ref
          .read(programApiProvider)
          .addSessionExercise(
            s.id,
            exerciseId: exercise.id,
            targetSets: targets.sets,
            targetReps: targets.reps,
            targetWeightKg: targets.weight,
            restSeconds: targets.rest,
          ),
    );
  }

  Future<void> _editExercise(SessionExerciseModel se) async {
    final targets = await showTargetsSheet(
      context,
      exerciseName: se.exercise.name,
      initial: (
        sets: se.targetSets,
        reps: se.targetReps,
        weight: se.targetWeightKg,
        rest: se.restSeconds,
      ),
    );
    if (targets == null) return;
    await _run(
      () => ref
          .read(programApiProvider)
          .updateSessionExercise(
            se.id,
            exerciseId: se.exercise.id,
            targetSets: targets.sets,
            targetReps: targets.reps,
            targetWeightKg: targets.weight,
            restSeconds: targets.rest,
          ),
    );
  }

  Future<void> _deleteExercise(SessionExerciseModel se) async {
    await _run(() => ref.read(programApiProvider).deleteSessionExercise(se.id));
  }

  /// Lance un exercice de la séance en emportant TOUTE la séance.
  ///
  /// L'écran de saisie recevait auparavant le seul identifiant de l'exercice :
  /// il ignorait donc les objectifs prescrits (séries, répétitions, charge,
  /// repos) et proposait 4 × 10 à 20 kg quel que soit le programme. Il ignorait
  /// aussi qu'un exercice suivant existait, obligeant à revenir ici entre
  /// chaque mouvement.
  void _startExercise(SessionModel session, SessionExerciseModel tapped) {
    HapticFeedback.selectionClick();

    final queue = [
      for (final se in session.exercises)
        ProgramExerciseTarget(
          exerciseId: se.exercise.id,
          exerciseName: se.exercise.name,
          sets: se.targetSets,
          reps: se.targetReps,
          weightKg: se.targetWeightKg,
          restSeconds: se.restSeconds,
          notes: se.notes,
        ),
    ];
    final index = session.exercises.indexWhere((se) => se.id == tapped.id);

    context.push(
      '/workout/log/${tapped.exercise.id}',
      extra: WorkoutLogArgs(
        sessionTitle: session.title,
        queue: queue,
        // -1 impossible en pratique (l'exercice vient de cette séance), mais un
        // index négatif ferait planter la lecture de la file : 0 est un repli
        // sans conséquence.
        index: index < 0 ? 0 : index,
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = _program;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.title ?? 'Programme'),
        actions: [
          if (_editable && p != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Modifier',
              onPressed: _busy ? null : _editProgram,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Supprimer',
              onPressed: _busy ? null : _deleteProgram,
            ),
          ],
        ],
      ),
      floatingActionButton: (_editable && p != null)
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _addSession,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: AppColors.onGradient),
              label: Text(
                'Séance',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.onGradient,
                ),
              ),
            )
          : null,
      body: ScreenBackground(child: SafeArea(top: false, child: _buildBody(p))),
      bottomNavigationBar: widget.isTemplate && p != null
          ? _AdoptBar(busy: _busy, onAdopt: _adopt)
          : null,
    );
  }

  Widget _buildBody(ProgramModel? p) {
    if (_loading) {
      return const AppListSkeleton(itemCount: 3, itemHeight: 140);
    }
    if (_error != null && p == null) {
      return AppErrorState(message: _error, onRetry: _load);
    }
    if (p == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        _Header(program: p),
        if (p.aiRationale != null && p.aiRationale!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AiRationaleCard(rationale: p.aiRationale!),
        ],
        const SizedBox(height: 20),
        Text('Séances (${p.sessionCount})', style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),
        if (p.sessions.isEmpty)
          _EmptySessions(editable: _editable, onAdd: _addSession)
        else
          ...p.sessions.asMap().entries.map((e) {
            final s = e.value;
            return _SessionCard(
                  session: s,
                  index: e.key,
                  editable: _editable,
                  onEditSession: () => _editSession(s),
                  onDeleteSession: () => _deleteSession(s),
                  onAddExercise: () => _addExercise(s),
                  onEditExercise: _editExercise,
                  onDeleteExercise: _deleteExercise,
                  onTapExercise: (se) => _startExercise(s, se),
                )
                .animate()
                .fadeIn(delay: (e.key * 60).ms, duration: 300.ms)
                .slideY(begin: 0.05);
          }),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title, style: AppTextStyles.headingSmall),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Annuler',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Supprimer',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.errorText,
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

// ─────────────────────────────────────────────────────────────────
//  Widgets internes
// ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ProgramModel program;
  const _Header({required this.program});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.title,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.onGradient,
            ),
          ),
          if (program.description != null &&
              program.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              program.description!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onGradient.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderStat(value: '${program.sessionCount}', label: 'Séances'),
              _HeaderDivider(),
              _HeaderStat(
                value: '${program.totalExercises}',
                label: 'Exercices',
              ),
              if (program.durationWeeks != null) ...[
                _HeaderDivider(),
                _HeaderStat(
                  value: '${program.durationWeeks}',
                  label: 'Semaines',
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassTag(icon: Icons.flag_rounded, label: program.goalLabel),
              _GlassTag(
                icon: Icons.signal_cellular_alt_rounded,
                label: program.levelLabel,
              ),
              // L'auteur, coach humain ou IA FitForge : même étiquette, même
              // place. Ce qui importe à l'adhérent est de savoir que le
              // programme n'est pas de lui.
              if (program.generatedByAi)
                _GlassTag(
                  icon: Icons.auto_awesome_rounded,
                  label: 'IA FitForge',
                )
              else if (program.byCoach)
                _GlassTag(
                  icon: Icons.verified_user_rounded,
                  label: 'Coach ${program.createdByName ?? ''}'.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// L'explication du programme, écrite par l'IA au moment de le composer.
///
/// ## Pourquoi elle est en haut, et pas en bas
///
/// Un programme généré arrive sans personne pour le défendre. Un coach humain
/// explique ses choix de vive voix — l'IA, elle, n'a que cet encart. Placé sous
/// les séances, il ne serait jamais lu ; placé au-dessus, il répond aux
/// questions qu'on se pose en découvrant le programme : pourquoi ce découpage,
/// pourquoi ce volume, comment progresser, ce qui a été adapté aux blessures.
///
/// ## Pourquoi elle est repliée par défaut
///
/// Six à dix phrases occupent tout l'écran d'un téléphone. Quelqu'un qui
/// revient sur son programme pour la dixième fois veut ses séances, pas
/// l'explication qu'il a déjà lue. Trois lignes suffisent à signaler qu'elle
/// existe ; un tap la déroule.
class _AiRationaleCard extends StatefulWidget {
  final String rationale;

  const _AiRationaleCard({required this.rationale});

  @override
  State<_AiRationaleCard> createState() => _AiRationaleCardState();
}

class _AiRationaleCardState extends State<_AiRationaleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(
                alpha: AppColors.isDark ? 0.16 : 0.10,
              ),
              AppColors.accent.withValues(
                alpha: AppColors.isDark ? 0.09 : 0.06,
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.primaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pourquoi ce programme',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Text(
                widget.rationale,
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (!_expanded) ...[
              const SizedBox(height: 6),
              Text(
                'Lire l\'explication complète',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.statValue.copyWith(
              color: AppColors.onGradient,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.statLabel.copyWith(
              color: AppColors.onGradient.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppColors.onGradient.withValues(alpha: 0.25),
    );
  }
}

class _GlassTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.onGradient.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onGradient),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onGradient,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final int index;
  final bool editable;
  final VoidCallback onEditSession;
  final VoidCallback onDeleteSession;
  final VoidCallback onAddExercise;
  final void Function(SessionExerciseModel) onEditExercise;
  final void Function(SessionExerciseModel) onDeleteExercise;
  final void Function(SessionExerciseModel) onTapExercise;

  const _SessionCard({
    required this.session,
    required this.index,
    required this.editable,
    required this.onEditSession,
    required this.onDeleteSession,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onDeleteExercise,
    required this.onTapExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de séance
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (session.dayLabel != null)
                        Text(
                          session.dayLabel!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
                if (editable)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textHint,
                    ),
                    color: AppColors.card,
                    onSelected: (v) {
                      if (v == 'edit') onEditSession();
                      if (v == 'delete') onDeleteSession();
                    },
                    itemBuilder: (_) => [
                      _menuItem('edit', Icons.edit_rounded, 'Renommer'),
                      _menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        'Supprimer',
                        danger: true,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),

          // Exercices de la séance
          if (session.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Text(
                'Aucun exercice dans cette séance.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            )
          else
            ...session.exercises.map(
              (se) => _ExerciseRow(
                se: se,
                editable: editable,
                onTap: () => onTapExercise(se),
                onEdit: () => onEditExercise(se),
                onDelete: () => onDeleteExercise(se),
              ),
            ),

          if (editable)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: TextButton.icon(
                onPressed: onAddExercise,
                icon: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.primaryText,
                ),
                label: Text(
                  'Ajouter un exercice',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  static PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? AppColors.errorText : AppColors.textSecondary;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final SessionExerciseModel se;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExerciseRow({
    required this.se,
    required this.editable,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 18,
              color: AppColors.accentText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(se.exercise.name, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      NeonBadge(
                        label: se.setsRepsLabel,
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                      if (se.targetWeightKg != null &&
                          se.targetWeightKg! > 0) ...[
                        const SizedBox(width: 6),
                        _MiniInfo(
                          icon: Icons.monitor_weight_outlined,
                          label:
                              '${se.targetWeightKg!.toStringAsFixed(se.targetWeightKg! % 1 == 0 ? 0 : 1)} kg',
                        ),
                      ],
                      if (se.restSeconds != null) ...[
                        const SizedBox(width: 10),
                        _MiniInfo(
                          icon: Icons.timer_outlined,
                          label: '${se.restSeconds}s',
                        ),
                      ],
                    ],
                  ),
                  // La consigne de coach, quand il y en a une. C'est ce qui
                  // sépare un programme d'un tableau de séries : « garde 2
                  // répétitions en réserve » se lit là où on en a besoin,
                  // c'est-à-dire à côté de l'exercice.
                  if (se.notes != null && se.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 13,
                          color: AppColors.primaryText,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            se.notes!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (editable)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textHint,
                  size: 20,
                ),
                color: AppColors.card,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  _SessionCard._menuItem(
                    'edit',
                    Icons.tune_rounded,
                    'Modifier les objectifs',
                  ),
                  _SessionCard._menuItem(
                    'delete',
                    Icons.delete_outline_rounded,
                    'Retirer',
                    danger: true,
                  ),
                ],
              )
            else
              Icon(
                Icons.play_circle_outline_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _EmptySessions extends StatelessWidget {
  final bool editable;
  final VoidCallback onAdd;
  const _EmptySessions({required this.editable, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.event_note_rounded,
      title: 'Aucune séance',
      message: editable
          ? 'Ajoutez une séance pour commencer à composer votre programme.'
          : 'Ce programme ne contient pas encore de séance.',
      actionLabel: editable ? 'Ajouter une séance' : null,
      onAction: editable ? onAdd : null,
    );
  }
}

class _AdoptBar extends StatelessWidget {
  final bool busy;
  final VoidCallback onAdopt;
  const _AdoptBar({required this.busy, required this.onAdopt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: PrimaryButton(
        label: 'Utiliser ce programme',
        icon: Icons.download_done_rounded,
        isLoading: busy,
        onPressed: busy ? null : onAdopt,
      ),
    );
  }
}
