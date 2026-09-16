import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/sleep_models.dart';
import '../../data/sleep_prompt_store.dart';
import '../providers/sleep_provider.dart';

/// Le pop-up du matin : « comment as-tu dormi cette nuit ? »
///
/// ## Pourquoi une seule fois par jour, et pourquoi on peut passer
///
/// C'est la seule fonctionnalité de l'application qui **interrompt** l'adhérent
/// avant qu'il ait demandé quoi que ce soit. Une interruption se paie : elle
/// n'est acceptable que si elle est rare, courte, et refusable.
///
/// - **Rare** : une fois par jour, à la première ouverture. Le contrôle est
///   double — le serveur sait si la nuit est enregistrée, l'appareil se
///   souvient si la question a déjà été posée (voir [SleepPromptStore]). Sans
///   le second, appuyer sur « Plus tard » ne servirait à rien : le pop-up
///   reviendrait au prochain retour sur l'accueil.
/// - **Courte** : deux heures à choisir. Rien d'autre n'est demandé.
/// - **Refusable** : « Plus tard » est un vrai bouton, pas une croix cachée
///   dans un coin. Et il dit où retrouver la saisie, sinon refuser revient à
///   perdre la fonctionnalité.
///
/// ## Deux temps dans la même feuille
///
/// Saisie, puis conseil. Le conseil apparaît **là où on vient d'appuyer**,
/// sans changement d'écran : c'est ce qui fait comprendre qu'il découle de ce
/// qu'on a saisi. Affiché ailleurs, il se lirait comme un message générique.
Future<void> showSleepPromptSheet(
  BuildContext context,
  WidgetRef ref, {
  SleepEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Non refusable par un geste vers le bas : passer doit être un choix
    // explicite, parce que c'est lui qu'on mémorise pour la journée. Un
    // balayage accidentel ferait taire le rappel sans que personne l'ait voulu.
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _SleepPromptSheet(existing: existing),
  );
}

class _SleepPromptSheet extends ConsumerStatefulWidget {
  final SleepEntry? existing;

  const _SleepPromptSheet({this.existing});

  @override
  ConsumerState<_SleepPromptSheet> createState() => _SleepPromptSheetState();
}

class _SleepPromptSheetState extends ConsumerState<_SleepPromptSheet> {
  late TimeOfDay _bedTime =
      widget.existing?.bedTime ?? const TimeOfDay(hour: 23, minute: 0);
  late TimeOfDay _wakeTime =
      widget.existing?.wakeTime ?? const TimeOfDay(hour: 7, minute: 0);

  bool _saving = false;
  String? _error;

  /// Renseignée après l'enregistrement : la feuille bascule alors sur le conseil.
  SleepEntry? _result;

  /// Durée telle qu'elle s'affiche **pendant** la saisie.
  ///
  /// C'est le seul endroit de l'application qui reproduit la règle du passage
  /// de minuit, et c'est assumé : sans aperçu vivant, on choisit deux heures à
  /// l'aveugle et on découvre après coup qu'on a saisi 16 heures de sommeil.
  ///
  /// La valeur qui **fait foi** reste celle du serveur — c'est elle qui est
  /// enregistrée, et c'est elle qui revient dans [_result].
  int get _previewMinutes {
    final bed = _bedTime.hour * 60 + _bedTime.minute;
    final wake = _wakeTime.hour * 60 + _wakeTime.minute;
    final diff = wake - bed;
    return diff <= 0 ? diff + 24 * 60 : diff;
  }

  // ── Actions ─────────────────────────────────────────────────────

  Future<void> _pick({required bool isBedTime}) async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedTime ? _bedTime : _wakeTime,
      helpText: isBedTime ? 'Heure de coucher' : 'Heure de lever',
      // Format 24 h imposé : « 23:30 » est la façon dont on parle de son
      // coucher en français, et le passage en AM/PM au milieu de la nuit est
      // une source d'erreur de saisie.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isBedTime) {
        _bedTime = picked;
      } else {
        _wakeTime = picked;
      }
    });
  }

  /// Ajuste une heure de quelques minutes sans rouvrir le sélecteur.
  ///
  /// Le sélecteur système est précis mais coûte trois gestes. « Je me suis
  /// couché un quart d'heure plus tard » doit coûter un seul appui.
  void _nudge({required bool isBedTime, required int minutes}) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = isBedTime ? _bedTime : _wakeTime;
      final total = (current.hour * 60 + current.minute + minutes + 1440) % 1440;
      final adjusted = TimeOfDay(hour: total ~/ 60, minute: total % 60);
      if (isBedTime) {
        _bedTime = adjusted;
      } else {
        _wakeTime = adjusted;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = await ref
          .read(sleepStatusProvider.notifier)
          .save(bedTime: _bedTime, wakeTime: _wakeTime);
      await SleepPromptStore.instance.markAskedToday();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _result = entry;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFrom(e);
        _saving = false;
      });
    }
  }

  Future<void> _skip() async {
    // On mémorise le refus AVANT de fermer : c'est tout l'intérêt du bouton.
    await SleepPromptStore.instance.markAskedToday();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.card,
          content: Text(
            'Pas de souci. Tu pourras l\'ajouter quand tu veux depuis la '
            'tuile « Sommeil » de l\'accueil.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
  }

  // ── Construction ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Remonte la feuille au-dessus du clavier si le sélecteur en ouvre un.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          // Un dégradé de nuit plutôt que la carte habituelle : c'est le seul
          // écran qui parle du sommeil, il a le droit d'en avoir la couleur.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.isDark
                ? const [Color(0xFF1A1740), Color(0xFF0F1428)]
                : const [Color(0xFFEAE6FF), Color(0xFFFFFFFF)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: SafeArea(
          top: false,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _result == null ? _askStep() : _resultStep(_result!),
          ),
        ),
      ),
    );
  }

  // ── Temps 1 : la saisie ─────────────────────────────────────────

  Widget _askStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 18),
          Row(
            children: [
              const _MoonBadge(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour !', style: AppTextStyles.headingMedium),
                    const SizedBox(height: 3),
                    Text(
                      'Comment as-tu dormi cette nuit ?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Couché à',
                  icon: Icons.nights_stay_rounded,
                  time: _bedTime,
                  onTap: () => _pick(isBedTime: true),
                  onNudge: (m) => _nudge(isBedTime: true, minutes: m),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeField(
                  label: 'Réveillé à',
                  icon: Icons.wb_twilight_rounded,
                  time: _wakeTime,
                  onTap: () => _pick(isBedTime: false),
                  onNudge: (m) => _nudge(isBedTime: false, minutes: m),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DurationPreview(minutes: _previewMinutes),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorLine(message: _error!),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Enregistrer ma nuit',
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _saving ? null : _skip,
            child: Text(
              'Plus tard',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Temps 2 : le conseil ────────────────────────────────────────

  Widget _resultStep(SleepEntry entry) {
    final color = entry.band?.color ?? AppColors.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 20),
          Center(
            child:
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            entry.durationLabel,
                            style: AppTextStyles.heroNumber.copyWith(
                              fontSize: 44,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.headline ?? '',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .scale(
                      duration: 420.ms,
                      curve: Curves.easeOutBack,
                      begin: const Offset(0.7, 0.7),
                    )
                    .fadeIn(duration: 260.ms),
          ),
          const SizedBox(height: 20),
          if (entry.advice != null)
            Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        size: 18,
                        color: AppColors.accentText,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          entry.advice!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 200.ms, duration: 380.ms)
                .slideY(begin: 0.12),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Voir mon sommeil',
            icon: Icons.insights_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/sleep');
            },
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Fermer',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _messageFrom(Object e) {
    final s = e.toString();
    if (s.contains('message')) {
      // Le backend renvoie un message utile (durée invraisemblable, nuit
      // future) : il vaut toujours mieux que « une erreur est survenue ».
      final match = RegExp(r'message: ([^,}]+)').firstMatch(s);
      if (match != null) return match.group(1)!.trim();
    }
    return 'Enregistrement impossible. Vérifie ta connexion.';
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Composants de la feuille
// ═══════════════════════════════════════════════════════════════════

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textDisabled,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

/// La lune de l'en-tête. Même objet que l'icône de la tuile d'accueil, pour
/// qu'on reconnaisse d'où vient ce pop-up.
class _MoonBadge extends StatelessWidget {
  const _MoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Icon(
            Icons.bedtime_rounded,
            color: AppColors.onGradient,
            size: 24,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.06, 1.06),
          duration: 2000.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// Une heure : grand chiffre tapable, plus deux boutons de réglage fin.
///
/// Le sélecteur système est précis mais coûte trois gestes. « Je me suis
/// couché un quart d'heure plus tard » doit coûter un seul appui — d'où les
/// −15 / +15 de part et d'autre.
class _TimeField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final VoidCallback onTap;
  final ValueChanged<int> onNudge;

  const _TimeField({
    required this.label,
    required this.icon,
    required this.time,
    required this.onTap,
    required this.onNudge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              formatTimeOfDay(time),
              textAlign: TextAlign.center,
              style: AppTextStyles.displayMedium.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NudgeButton(label: '−15', onTap: () => onNudge(-15)),
              const SizedBox(width: 8),
              _NudgeButton(label: '+15', onTap: () => onNudge(15)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NudgeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// L'aperçu vivant de la durée : il change à chaque réglage.
///
/// C'est lui qui évite de choisir deux heures à l'aveugle et de découvrir après
/// coup qu'on a saisi seize heures de sommeil.
class _DurationPreview extends StatelessWidget {
  final int minutes;

  const _DurationPreview({required this.minutes});

  @override
  Widget build(BuildContext context) {
    // Bornes du serveur (15 min à 16 h) : on prévient AVANT l'envoi plutôt que
    // de laisser partir un appel qui reviendra en erreur.
    final plausible = minutes >= 15 && minutes <= 960;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: plausible
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        border: Border.all(
          color: plausible
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text('DURÉE DE LA NUIT', style: AppTextStyles.overline),
          const SizedBox(height: 4),
          Text(
            formatDuration(minutes),
            style: AppTextStyles.heroNumber.copyWith(
              fontSize: 38,
              color: plausible ? AppColors.primaryText : AppColors.errorText,
            ),
          ),
          if (!plausible) ...[
            const SizedBox(height: 4),
            Text(
              'Vérifie tes deux heures : as-tu inversé le coucher et le lever ?',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.errorText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String message;

  const _ErrorLine({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: AppColors.errorText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorText),
          ),
        ),
      ],
    );
  }
}
