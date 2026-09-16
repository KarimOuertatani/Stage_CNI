import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/screen_background.dart';
import '../../data/sleep_models.dart';
import '../providers/sleep_provider.dart';
import '../widgets/sleep_bar_chart.dart';
import '../widgets/sleep_prompt_sheet.dart';

/// L'écran Sommeil : l'histogramme de la semaine, le score, les conseils.
///
/// ## L'ordre de lecture
///
/// Score et moyenne d'abord, histogramme ensuite, conseils à la fin. C'est
/// l'inverse de l'ordre dans lequel les données sont produites, et c'est
/// voulu : quelqu'un qui ouvre cet écran veut d'abord savoir **où il en est**.
/// Le détail ne l'intéresse qu'une fois cette réponse obtenue, et les conseils
/// n'ont de sens qu'après avoir vu le détail.
///
/// ## Le jour sélectionné
///
/// Taper une barre ouvre sa fiche sous le graphique — heures de coucher et de
/// lever, durée, tranche. Un histogramme qu'on ne peut que regarder oblige à
/// deviner à quoi correspond une barre ; ici la question se pose en la
/// touchant.
///
/// Par défaut, la sélection porte sur **la nuit la plus récente saisie** de la
/// semaine affichée : c'est celle qu'on vient de vivre, donc celle qu'on
/// cherche en ouvrant l'écran.
class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  /// Jour mis en avant. `null` = on retombe sur la nuit la plus récente.
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final weekAsync = ref.watch(sleepWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sommeil'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer une nuit',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openPrompt(context),
          ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          top: false,
          child: weekAsync.when(
            loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 160),
            error: (e, _) => AppErrorState(
              message: 'Impossible de charger ton sommeil.',
              onRetry: () => ref.read(sleepWeekProvider.notifier).reload(),
            ),
            data: (week) => _content(week),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrompt(BuildContext context) async {
    HapticFeedback.selectionClick();
    await showSleepPromptSheet(context, ref);
    if (!mounted) return;
    // La semaine affichée doit refléter la nuit qu'on vient d'ajouter, sans
    // quoi l'histogramme resterait figé sur l'état d'avant la saisie.
    await ref.read(sleepWeekProvider.notifier).reload();
  }

  // ── Contenu ─────────────────────────────────────────────────────

  Widget _content(SleepWeek week) {
    final selected = _resolveSelected(week);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () => ref.read(sleepWeekProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _WeekNavigator(
            week: week,
            onPrevious: () {
              HapticFeedback.selectionClick();
              setState(() => _selected = null);
              ref.read(sleepWeekProvider.notifier).previousWeek();
            },
            onNext: week.currentWeek
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = null);
                    ref.read(sleepWeekProvider.notifier).nextWeek();
                  },
          ),
          const SizedBox(height: 16),
          _SummaryCard(week: week)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: 16),
          _ChartCard(
            week: week,
            selectedDate: selected?.date,
            onSelect: (day) => setState(() => _selected = day.date),
          ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.06),
          if (selected != null) ...[
            const SizedBox(height: 14),
            _DayDetailCard(day: selected),
          ],
          if (week.weekendCatchUpMinutes != null &&
              week.weekendCatchUpMinutes!.abs() >= 45) ...[
            const SizedBox(height: 14),
            _WeekendCatchUpCard(minutes: week.weekendCatchUpMinutes!),
          ],
          if (week.tips.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Conseils', style: AppTextStyles.headingSmall),
            const SizedBox(height: 12),
            ...week.tips.asMap().entries.map(
              (e) => _TipCard(index: e.key, text: e.value)
                  .animate()
                  .fadeIn(delay: (120 + e.key * 70).ms, duration: 350.ms)
                  .slideX(begin: 0.04),
            ),
          ],
        ],
      ),
    );
  }

  /// Le jour affiché dans la fiche de détail.
  ///
  /// À défaut de sélection explicite, **la nuit la plus récente saisie** de la
  /// semaine — pas le premier jour de la semaine, qui serait presque toujours
  /// le moins intéressant.
  SleepDay? _resolveSelected(SleepWeek week) {
    if (_selected != null) {
      for (final day in week.days) {
        if (_isSameDay(day.date, _selected!)) return day;
      }
    }
    SleepDay? latest;
    for (final day in week.days) {
      if (day.hasData) latest = day;
    }
    return latest;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════════════════════
//  Navigation entre les semaines
// ═══════════════════════════════════════════════════════════════════

/// Flèches et libellé de la semaine.
///
/// La flèche « suivant » est **désactivée** sur la semaine en cours plutôt que
/// masquée : un bouton qui disparaît fait sauter la mise en page à chaque
/// navigation, et on perd le repère de l'endroit où appuyer.
class _WeekNavigator extends StatelessWidget {
  final SleepWeek week;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const _WeekNavigator({
    required this.week,
    required this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Column(
            children: [
              Text(
                week.currentWeek ? 'Cette semaine' : 'Semaine du',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 2),
              Text(
                formatWeekRange(week.weekStart, week.weekEnd),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? AppColors.card : Colors.transparent,
          border: Border.all(
            color: enabled ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Score et moyenne
// ═══════════════════════════════════════════════════════════════════

/// L'en-tête chiffré : score, moyenne, nuits enregistrées.
class _SummaryCard extends StatelessWidget {
  final SleepWeek week;

  const _SummaryCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final score = week.score;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: AppColors.isDark ? 0.22 : 0.13),
            AppColors.info.withValues(alpha: AppColors.isDark ? 0.12 : 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          _ScoreRing(score: score),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  week.headline,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _MetricLine(
                  icon: Icons.schedule_rounded,
                  label: 'Moyenne',
                  value: week.averageLabel,
                ),
                const SizedBox(height: 6),
                _MetricLine(
                  icon: Icons.event_available_rounded,
                  label: 'Nuits notées',
                  value: '${week.nightsLogged} / 7',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// L'anneau de score.
///
/// Sans score (aucune nuit saisie), l'anneau reste vide et affiche « — » plutôt
/// que zéro : zéro se lirait comme « tu dors très mal », alors que la vérité
/// est « on ne sait pas encore ».
class _ScoreRing extends StatelessWidget {
  final int? score;

  const _ScoreRing({required this.score});

  Color get _color {
    final value = score;
    if (value == null) return AppColors.textDisabled;
    if (value >= 80) return AppColors.success;
    if (value >= 60) return AppColors.accent;
    if (value >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final value = score;
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              color: AppColors.border,
            ),
          ),
          SizedBox(
            width: 86,
            height: 86,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value == null ? 0 : value / 100),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (context, ratio, _) => CircularProgressIndicator(
                value: ratio,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                color: _color,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value?.toString() ?? '—',
                style: AppTextStyles.statValue.copyWith(
                  fontSize: 26,
                  color: _color,
                ),
              ),
              Text('score', style: AppTextStyles.caption.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textHint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Graphique
// ═══════════════════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final SleepWeek week;
  final DateTime? selectedDate;
  final ValueChanged<SleepDay> onSelect;

  const _ChartCard({
    required this.week,
    required this.onSelect,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 17,
                  color: AppColors.primaryText,
                ),
                const SizedBox(width: 8),
                Text('Nuit par nuit', style: AppTextStyles.titleMedium),
                const Spacer(),
                Text(
                  'Touche une barre',
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
          SleepBarChart(
            week: week,
            selectedDate: selectedDate,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

/// La fiche du jour sélectionné, sous le graphique.
class _DayDetailCard extends StatelessWidget {
  final SleepDay day;

  const _DayDetailCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final color = day.band?.color ?? AppColors.textDisabled;

    return Container(
      key: ValueKey(day.date),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day.dayLabel, style: AppTextStyles.labelSmall),
              const SizedBox(height: 2),
              Text(
                day.durationMinutes == null
                    ? '—'
                    : formatDuration(day.durationMinutes!),
                style: AppTextStyles.headingMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: day.hasData
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _TimePill(
                        icon: Icons.nights_stay_rounded,
                        label: formatTimeOfDay(day.bedTime!),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      _TimePill(
                        icon: Icons.wb_twilight_rounded,
                        label: formatTimeOfDay(day.wakeTime!),
                      ),
                    ],
                  )
                : Text(
                    'Aucune nuit enregistrée ce jour-là.',
                    textAlign: TextAlign.end,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 240.ms);
  }
}

class _TimePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TimePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassWhiteMid,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// L'écart week-end / semaine, quand il est assez marqué pour vouloir dire
/// quelque chose (au moins trois quarts d'heure).
///
/// C'est le motif le plus courant et le plus invisible : une moyenne correcte
/// peut cacher cinq nuits trop courtes rattrapées par deux grasses matinées.
class _WeekendCatchUpCard extends StatelessWidget {
  final int minutes;

  const _WeekendCatchUpCard({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final catchingUp = minutes > 0;
    final color = catchingUp ? AppColors.warning : AppColors.info;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.weekend_rounded, size: 18, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              catchingUp
                  ? 'Tu dors ${formatDuration(minutes)} de plus le week-end. '
                        'C\'est souvent le signe d\'une dette accumulée en '
                        'semaine : mieux vaut avancer le coucher en semaine que '
                        'rattraper d\'un coup.'
                  : 'Tu dors ${formatDuration(minutes.abs())} de moins le '
                        'week-end qu\'en semaine. Sorties tardives ? Ton corps '
                        'ne fait pas la différence entre les jours.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final int index;
  final String text;

  const _TipCard({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.16),
            ),
            child: Text(
              '${index + 1}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accentText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
