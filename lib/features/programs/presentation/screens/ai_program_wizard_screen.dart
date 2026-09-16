import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/screen_background.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/ai_program_models.dart';
import '../../data/program_models.dart';
import '../providers/ai_program_provider.dart';
import '../providers/program_provider.dart';
import '../widgets/ai_wizard_widgets.dart';

/// L'assistant de création d'un programme par l'IA FitForge.
///
/// ## Pourquoi un questionnaire et pas un simple bouton
///
/// Un bouton « génère-moi un programme » produit un programme générique — le
/// même pour tout le monde, ou presque. Ce qui rend un programme utilisable,
/// c'est le nombre de jours réellement disponibles, la durée réelle d'une
/// séance, le matériel réellement là, et les charges que la personne soulève
/// vraiment. Aucune de ces réponses ne se devine.
///
/// ## Pourquoi neuf écrans et pas un formulaire
///
/// Les mêmes questions dans un seul formulaire donnent un mur de champs qu'on
/// abandonne. Une question par écran, avec une phrase qui dit **à quoi la
/// réponse sert**, se répond en un geste. Le prix à payer est la sensation de
/// longueur : d'où la barre segmentée en haut, qui montre en permanence
/// combien il reste.
///
/// ## Ce que l'adhérent ne saisit pas
///
/// Son profil : âge, poids, taille, blessures déclarées, matériel enregistré,
/// sommeil. Le serveur le joint tout seul à la demande. Le redemander ici
/// serait pénible **et** une source de contradiction — deux réponses pour la
/// même question, et plus personne ne sait laquelle fait foi.
///
/// ## Trois temps, un seul écran
///
/// Questionnaire → génération → résultat. La génération dure des dizaines de
/// secondes : elle a droit à son propre temps d'écran, animé, avec l'étape en
/// cours annoncée. Un simple `CircularProgressIndicator` pendant une minute se
/// lit comme une application bloquée.
class AiProgramWizardScreen extends ConsumerStatefulWidget {
  const AiProgramWizardScreen({super.key});

  @override
  ConsumerState<AiProgramWizardScreen> createState() =>
      _AiProgramWizardScreenState();
}

enum _Phase { questions, generating, done }

/// Nombre maximum de zones que l'adhérent peut mettre en avant.
///
/// Au-delà de trois, « prioriser » ne veut plus rien dire : si tout est
/// prioritaire, le volume se répartit comme s'il n'y avait aucune priorité.
const int _maxFocusMuscles = 3;

class _AiProgramWizardScreenState extends ConsumerState<AiProgramWizardScreen> {
  static const int _stepCount = 9;

  final PageController _pages = PageController();
  int _step = 0;

  late AiProgramBrief _brief;
  _Phase _phase = _Phase.questions;

  ProgramModel? _result;
  String? _error;
  CancelToken? _cancelToken;

  final _bench = TextEditingController();
  final _squat = TextEditingController();
  final _deadlift = TextEditingController();
  final _pullUps = TextEditingController();
  final _constraints = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pré-rempli depuis le profil : les trois premières questions sont déjà
    // répondues, l'adhérent les confirme ou les change POUR CE PROGRAMME sans
    // que son profil bouge.
    _brief = aiBriefFromProfile(ref.read(profileProvider).profile);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _pages.dispose();
    _bench.dispose();
    _squat.dispose();
    _deadlift.dispose();
    _pullUps.dispose();
    _constraints.dispose();
    super.dispose();
  }

  // ── Navigation entre les étapes ─────────────────────────────────

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step.clamp(0, _stepCount - 1));
    _pages.animateToPage(
      _step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _generate();
      return;
    }
    HapticFeedback.selectionClick();
    _goTo(_step + 1);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    _goTo(_step - 1);
  }

  void _update(AiProgramBrief brief) => setState(() => _brief = brief);

  // ── Génération ──────────────────────────────────────────────────

  /// Recopie les champs de saisie libre dans le brief, puis lance l'appel.
  ///
  /// Les `TextEditingController` ne sont lus qu'ici, au dernier moment : les
  /// synchroniser à chaque frappe ferait reconstruire tout l'assistant à
  /// chaque caractère, sans que personne y gagne quoi que ce soit.
  Future<void> _generate() async {
    FocusScope.of(context).unfocus();

    final brief = _brief.copyWith(
      benchPressKg: _parseDouble(_bench.text),
      squatKg: _parseDouble(_squat.text),
      deadliftKg: _parseDouble(_deadlift.text),
      maxPullUps: _parseInt(_pullUps.text),
      constraints: _constraints.text,
    );

    setState(() {
      _brief = brief;
      _phase = _Phase.generating;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    _cancelToken = CancelToken();
    try {
      final program = await ref
          .read(programsProvider.notifier)
          .generateAiProgram(brief, cancelToken: _cancelToken);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _result = program;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      if (!mounted) return;
      setState(() {
        _error = _messageFrom(e);
        _phase = _Phase.generating; // on reste sur l'écran, avec l'erreur
      });
    }
  }

  void _cancelGeneration() {
    _cancelToken?.cancel();
    _cancelToken = null;
    setState(() {
      _phase = _Phase.questions;
      _error = null;
    });
  }

  void _openResult() {
    final program = _result;
    if (program == null) return;
    context.pushReplacement('/programs/detail/${program.id}');
  }

  // ── Construction ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Pendant la génération, un retour arrière laisserait l'appel courir et
      // consommerait un quota pour rien : on l'intercepte pour proposer
      // d'abandonner explicitement.
      canPop: _phase != _Phase.generating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.generating) _cancelGeneration();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _phase == _Phase.done
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _phase == _Phase.generating
                      ? _cancelGeneration
                      : _back,
                ),
          title: Text(switch (_phase) {
            _Phase.questions => 'Créer avec l\'IA',
            _Phase.generating => 'Composition en cours',
            _Phase.done => 'Ton programme est prêt',
          }),
        ),
        body: ScreenBackground(
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              child: switch (_phase) {
                _Phase.questions => _questions(),
                _Phase.generating => _GeneratingView(
                  key: const ValueKey('generating'),
                  error: _error,
                  onRetry: _generate,
                  onCancel: _cancelGeneration,
                ),
                _Phase.done => _DoneView(
                  key: const ValueKey('done'),
                  program: _result!,
                  onOpen: _openResult,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Le questionnaire ────────────────────────────────────────────

  Widget _questions() {
    return Column(
      key: const ValueKey('questions'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiWizardProgress(total: _stepCount, current: _step),
              const SizedBox(height: 8),
              Text(
                'Étape ${_step + 1} sur $_stepCount',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _step = i),
            children: [
              _stepGoal(),
              _stepLevel(),
              _stepRhythm(),
              _stepDays(),
              _stepPlace(),
              _stepFocus(),
              _stepLifts(),
              _stepConstraints(),
              _stepRecap(),
            ],
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  Widget _bottomBar() {
    final isLast = _step == _stepCount - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.bottomBar.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            TextButton(
              onPressed: _back,
              child: Text(
                'Retour',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: PrimaryButton(
              label: isLast ? 'Générer mon programme' : 'Continuer',
              icon: isLast
                  ? Icons.auto_awesome_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }

  /// Enveloppe commune d'une étape : marges, défilement, en-tête.
  Widget _page({
    required String overline,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        AiStepHeader(overline: overline, title: title, subtitle: subtitle),
        const SizedBox(height: 22),
        ...children,
      ],
    );
  }

  // ── Étape 1 : objectif ──────────────────────────────────────────

  Widget _stepGoal() {
    return _page(
      overline: 'Ton objectif',
      title: 'Qu\'est-ce que tu veux obtenir ?',
      subtitle:
          'C\'est ce qui décide des répétitions, des temps de repos et du '
          'choix des exercices. Tout le reste en découle.',
      children: [
        for (final option in kAiGoalOptions)
          AiOptionTile(
            icon: option.icon,
            label: option.label,
            hint: option.hint,
            selected: _brief.goal == option.value,
            onTap: () => _update(_brief.copyWith(goal: option.value)),
          ),
      ],
    );
  }

  // ── Étape 2 : niveau ────────────────────────────────────────────

  Widget _stepLevel() {
    return _page(
      overline: 'Ton niveau',
      title: 'Où en es-tu ?',
      subtitle:
          'Un débutant et un pratiquant avancé ne supportent pas le même '
          'volume. C\'est cette réponse qui évite de te blesser — ou de te '
          'faire stagner.',
      children: [
        for (final option in kAiLevelOptions)
          AiOptionTile(
            icon: option.icon,
            label: option.label,
            hint: option.hint,
            selected: _brief.experienceLevel == option.value,
            accent: AppColors.accent,
            onTap: () => _update(
              _brief.copyWith(experienceLevel: option.value),
            ),
          ),
      ],
    );
  }

  // ── Étape 3 : rythme ────────────────────────────────────────────

  Widget _stepRhythm() {
    return _page(
      overline: 'Ton rythme',
      title: 'Combien de temps peux-tu y consacrer ?',
      subtitle:
          'Sois honnête plutôt qu\'ambitieux : un programme de 5 séances '
          'suivi 2 fois vaut moins qu\'un programme de 3 séances suivi en '
          'entier.',
      children: [
        const AiFieldLabel(label: 'Séances par semaine'),
        AiCountPicker(
          value: _brief.daysPerWeek,
          onChanged: (v) => _update(_brief.copyWith(daysPerWeek: v)),
        ),
        const SizedBox(height: 10),
        // Annoncer le découpage rend la réponse tangible : « 4 » devient
        // « haut / bas deux fois », c'est-à-dire une semaine qu'on se
        // représente avant même que le programme existe.
        _HintBanner(
          icon: Icons.calendar_view_week_rounded,
          text: 'Découpage prévu : ${_splitPreview(_brief.daysPerWeek)}',
        ),
        const SizedBox(height: 26),
        const AiFieldLabel(
          label: 'Durée d\'une séance',
          hint: 'Échauffement et temps de repos compris.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in const [30, 45, 60, 75, 90])
              AiPill(
                label: '$minutes min',
                selected: _brief.sessionMinutes == minutes,
                onTap: () => _update(
                  _brief.copyWith(sessionMinutes: minutes),
                ),
              ),
          ],
        ),
        const SizedBox(height: 26),
        const AiFieldLabel(
          label: 'Durée du programme',
          hint: 'La période sur laquelle tu suivras ce plan avant d\'en '
              'changer.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final weeks in const [4, 6, 8, 12])
              AiPill(
                label: '$weeks semaines',
                selected: _brief.durationWeeks == weeks,
                accent: AppColors.primary,
                onTap: () => _update(_brief.copyWith(durationWeeks: weeks)),
              ),
          ],
        ),
      ],
    );
  }

  /// Le découpage que l'IA appliquera pour ce nombre de séances.
  ///
  /// Repris tel quel de la consigne donnée au modèle : afficher ici une règle
  /// différente de celle qu'il suit produirait une promesse non tenue.
  String _splitPreview(int days) {
    return switch (days) {
      1 => 'full body — tout le corps en une séance',
      2 => 'full body — tout le corps, deux fois',
      3 => 'full body, ou push / pull / jambes',
      4 => 'haut / bas, deux fois dans la semaine',
      5 => 'push / pull / jambes, plus haut / bas',
      6 => 'push / pull / jambes, répété deux fois',
      _ => 'push / pull / jambes deux fois, avec un jour de repos',
    };
  }

  // ── Étape 4 : jours de la semaine ───────────────────────────────

  Widget _stepDays() {
    final chosen = _brief.preferredDays;
    final mismatch = chosen.isNotEmpty && chosen.length != _brief.daysPerWeek;

    return _page(
      overline: 'Ton planning',
      title: 'Quels jours t\'arrangent ?',
      subtitle:
          'Facultatif. Si tu choisis des jours, l\'IA y place tes séances en '
          'évitant deux séances lourdes à la suite sur les mêmes muscles.',
      children: [
        Row(
          children: [
            for (final day in kAiWeekDays)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: day.value == 7 ? 0 : 7),
                  child: _DayToggle(
                    label: day.short,
                    tooltip: day.label,
                    selected: chosen.contains(day.value),
                    onTap: () => _toggleDay(day.value),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (mismatch)
          _HintBanner(
            icon: Icons.info_outline_rounded,
            color: AppColors.warning,
            text:
                'Tu as coché ${chosen.length} jour${chosen.length > 1 ? 's' : ''} '
                'pour ${_brief.daysPerWeek} séance'
                '${_brief.daysPerWeek > 1 ? 's' : ''}. L\'IA fera au mieux — '
                'ajuste l\'un ou l\'autre si tu veux qu\'ils coïncident.',
          )
        else if (chosen.isEmpty)
          const _HintBanner(
            icon: Icons.all_inclusive_rounded,
            text:
                'Aucun jour coché : l\'IA répartira les séances librement dans '
                'la semaine.',
          ),
      ],
    );
  }

  void _toggleDay(int day) {
    final days = [..._brief.preferredDays];
    days.contains(day) ? days.remove(day) : days.add(day);
    days.sort();
    _update(_brief.copyWith(preferredDays: days));
  }

  // ── Étape 5 : lieu et matériel ──────────────────────────────────

  Widget _stepPlace() {
    return _page(
      overline: 'Ton environnement',
      title: 'Où t\'entraînes-tu, et avec quoi ?',
      subtitle:
          'L\'IA ne choisira que des exercices réalisables avec ce matériel. '
          'Rien d\'inutilisable ne se retrouvera dans ton programme.',
      children: [
        for (final option in kAiLocationOptions)
          AiOptionTile(
            icon: option.icon,
            label: option.label,
            hint: option.hint,
            selected: _brief.location == option.value,
            onTap: () => _update(_brief.copyWith(location: option.value)),
          ),
        const SizedBox(height: 18),
        const AiFieldLabel(
          label: 'Matériel disponible',
          hint: 'Rien de coché = tout le matériel d\'une salle complète.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in kAiEquipmentOptions)
              AiPill(
                label: option.label,
                icon: option.icon,
                selected: _brief.equipment.contains(option.value),
                onTap: () => _toggleEquipment(option.value),
              ),
          ],
        ),
      ],
    );
  }

  void _toggleEquipment(String value) {
    final list = [..._brief.equipment];
    list.contains(value) ? list.remove(value) : list.add(value);
    _update(_brief.copyWith(equipment: list));
  }

  // ── Étape 6 : priorités ─────────────────────────────────────────

  Widget _stepFocus() {
    final chosen = _brief.focusMuscles;
    final full = chosen.length >= _maxFocusMuscles;

    return _page(
      overline: 'Tes priorités',
      title: 'Quelque chose à faire ressortir ?',
      subtitle:
          'Facultatif. Les zones choisies reçoivent plus de séries que les '
          'autres. Au-delà de trois, « prioritaire » ne veut plus rien dire.',
      children: [
        Row(
          children: [
            Expanded(
              child: AiFieldLabel(
                label: 'Zones à prioriser',
                hint: full
                    ? 'Maximum atteint — décoche une zone pour en choisir une '
                          'autre.'
                    : '${chosen.length} sur $_maxFocusMuscles choisie'
                          '${chosen.length > 1 ? 's' : ''}.',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in kAiFocusOptions)
              AiPill(
                label: option.label,
                selected: chosen.contains(option.value),
                onTap: () => _toggleFocus(option.value),
              ),
          ],
        ),
        const SizedBox(height: 26),
        const AiFieldLabel(label: 'Cardio'),
        _SwitchTile(
          icon: Icons.monitor_heart_rounded,
          label: 'Inclure du cardio',
          hint: 'Placé en fin de séance, jamais avant les exercices lourds.',
          value: _brief.includeCardio,
          onChanged: (v) => _update(_brief.copyWith(includeCardio: v)),
        ),
      ],
    );
  }

  void _toggleFocus(String value) {
    final list = [..._brief.focusMuscles];
    if (list.contains(value)) {
      list.remove(value);
    } else {
      if (list.length >= _maxFocusMuscles) return;
      list.add(value);
    }
    _update(_brief.copyWith(focusMuscles: list));
  }

  // ── Étape 7 : charges de référence ──────────────────────────────

  Widget _stepLifts() {
    return _page(
      overline: 'Tes charges',
      title: 'Que soulèves-tu aujourd\'hui ?',
      subtitle:
          'Facultatif, mais c\'est ce qui transforme « 4 × 8 » en « 4 × 8 à '
          '60 kg ». Indique ton maximum sur une répétition, même approximatif.',
      children: [
        AiNumberField(
          controller: _bench,
          label: 'Développé couché',
          unit: 'kg',
          icon: Icons.airline_seat_flat_rounded,
        ),
        AiNumberField(
          controller: _squat,
          label: 'Squat',
          unit: 'kg',
          icon: Icons.accessibility_new_rounded,
        ),
        AiNumberField(
          controller: _deadlift,
          label: 'Soulevé de terre',
          unit: 'kg',
          icon: Icons.fitness_center_rounded,
        ),
        AiNumberField(
          controller: _pullUps,
          label: 'Tractions strictes',
          unit: 'reps',
          icon: Icons.trending_up_rounded,
        ),
        const SizedBox(height: 6),
        const _HintBanner(
          icon: Icons.lightbulb_outline_rounded,
          text:
              'Rien à indiquer ? Passe cette étape. L\'IA raisonnera alors en '
              'répétitions et en ressenti, sans inventer de poids — un poids '
              'inventé serait pris pour une consigne.',
        ),
      ],
    );
  }

  // ── Étape 8 : contraintes ───────────────────────────────────────

  Widget _stepConstraints() {
    return _page(
      overline: 'Tes contraintes',
      title: 'Y a-t-il quelque chose à éviter ?',
      subtitle:
          'Douleurs, mouvements interdits, contrainte d\'horaire. Les '
          'blessures déjà enregistrées dans ton profil sont transmises '
          'automatiquement — inutile de les réécrire.',
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _constraints,
            maxLines: 5,
            maxLength: 600,
            keyboardType: TextInputType.multiline,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'Ex : genou droit fragile, pas de saut. Je n\'ai que 30 '
                  'minutes le vendredi.',
              hintStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDisabled,
              ),
              border: InputBorder.none,
              counterStyle: AppTextStyles.caption,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Contraintes fréquentes',
          style: AppTextStyles.labelSmall,
        ),
        const SizedBox(height: 10),
        // Des suggestions qui ÉCRIVENT dans le champ plutôt que des cases à
        // cocher : une contrainte réelle est presque toujours une nuance
        // (« épaule gauche, seulement au-dessus de la tête ») qu'aucune liste
        // fermée ne capture. Elles amorcent la phrase, l'adhérent la précise.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in const [
              'Genou fragile',
              'Épaule sensible',
              'Mal de dos',
              'Pas de saut',
              'Pas de course',
              'Peu de temps',
            ])
              AiPill(
                label: suggestion,
                selected: false,
                accent: AppColors.primary,
                onTap: () => _appendConstraint(suggestion),
              ),
          ],
        ),
      ],
    );
  }

  void _appendConstraint(String text) {
    final current = _constraints.text.trim();
    if (current.toLowerCase().contains(text.toLowerCase())) return;
    _constraints.text = current.isEmpty ? text : '$current, $text';
    _constraints.selection = TextSelection.collapsed(
      offset: _constraints.text.length,
    );
    setState(() {});
  }

  // ── Étape 9 : récapitulatif ─────────────────────────────────────

  Widget _stepRecap() {
    return _page(
      overline: 'Dernière vérification',
      title: 'Voilà ce que l\'IA va utiliser',
      subtitle:
          'Touche une ligne pour revenir la corriger. Ton profil est joint '
          'automatiquement à la demande.',
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              AiRecapRow(
                icon: Icons.flag_rounded,
                label: 'Objectif',
                value: goalLabelFr(_brief.goal),
                onEdit: () => _goTo(0),
              ),
              AiRecapRow(
                icon: Icons.signal_cellular_alt_rounded,
                label: 'Niveau',
                value: levelLabelFr(_brief.experienceLevel),
                onEdit: () => _goTo(1),
              ),
              AiRecapRow(
                icon: Icons.event_repeat_rounded,
                label: 'Rythme',
                value:
                    '${_brief.daysPerWeek} séance'
                    '${_brief.daysPerWeek > 1 ? 's' : ''} par semaine, '
                    '${_brief.sessionMinutes} min'
                    '${_brief.durationWeeks != null ? ', sur ${_brief.durationWeeks} semaines' : ''}',
                onEdit: () => _goTo(2),
              ),
              AiRecapRow(
                icon: Icons.calendar_month_rounded,
                label: 'Jours',
                value: _brief.preferredDays.isEmpty
                    ? 'Au choix de l\'IA'
                    : _brief.preferredDays
                          .map(
                            (d) => kAiWeekDays
                                .firstWhere((w) => w.value == d)
                                .label,
                          )
                          .join(', '),
                onEdit: () => _goTo(3),
              ),
              AiRecapRow(
                icon: Icons.place_rounded,
                label: 'Lieu',
                value: _locationLabel(_brief.location),
                onEdit: () => _goTo(4),
              ),
              AiRecapRow(
                icon: Icons.handyman_rounded,
                label: 'Matériel',
                value: _brief.equipment.isEmpty
                    ? 'Salle complète'
                    : _brief.equipment.map(equipmentLabelFr).join(', '),
                onEdit: () => _goTo(4),
              ),
              AiRecapRow(
                icon: Icons.center_focus_strong_rounded,
                label: 'Priorités',
                value: _brief.focusMuscles.isEmpty
                    ? 'Équilibré, aucune zone privilégiée'
                    : _brief.focusMuscles.map(muscleLabelFr).join(', '),
                onEdit: () => _goTo(5),
              ),
              AiRecapRow(
                icon: Icons.monitor_heart_rounded,
                label: 'Cardio',
                value: _brief.includeCardio ? 'Inclus' : 'Non inclus',
                onEdit: () => _goTo(5),
              ),
              AiRecapRow(
                icon: Icons.scale_rounded,
                label: 'Charges',
                value: _liftsSummary(),
                onEdit: () => _goTo(6),
              ),
              AiRecapRow(
                icon: Icons.health_and_safety_rounded,
                label: 'Contraintes',
                value: _constraints.text.trim().isEmpty
                    ? 'Aucune contrainte précisée'
                    : _constraints.text.trim(),
                onEdit: () => _goTo(7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _HintBanner(
          icon: Icons.shield_moon_rounded,
          text:
              'Ton profil sportif (âge, poids, niveau, matériel, blessures '
              'déclarées) est joint à la demande. Ton nom et ton adresse email '
              'ne le sont pas.',
        ),
      ],
    );
  }

  String _liftsSummary() {
    final parts = <String>[];
    void add(String label, TextEditingController c, String unit) {
      final value = c.text.trim();
      if (value.isNotEmpty) parts.add('$label $value $unit');
    }

    add('Couché', _bench, 'kg');
    add('Squat', _squat, 'kg');
    add('Soulevé', _deadlift, 'kg');
    add('Tractions', _pullUps, 'reps');
    return parts.isEmpty ? 'Non communiquées' : parts.join(' · ');
  }

  String _locationLabel(String value) {
    for (final option in kAiLocationOptions) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  // ── Utilitaires ─────────────────────────────────────────────────

  static double? _parseDouble(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  static int? _parseInt(String raw) {
    final value = int.tryParse(raw.trim());
    return value != null && value > 0 ? value : null;
  }

  /// Message lisible : on privilégie celui renvoyé par le backend (plafond
  /// journalier atteint, génération non configurée, contraintes refusées…),
  /// qui est toujours plus utile qu'un message d'erreur générique.
  static String _messageFrom(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      // 404 : la route n'existe pas sur ce serveur. C'est presque toujours un
      // backend d'une version antérieure, pas encore redémarré. Le dire
      // évite de chercher du côté du réseau, où il n'y a rien à trouver.
      if (e.response?.statusCode == 404) {
        return 'Ce serveur FitForge ne connaît pas encore la génération par '
            "l'IA. Il doit être redémarré sur une version à jour.";
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'La composition a pris trop de temps. Réessaie, ou demande '
            'moins de séances.';
      }
      return 'La génération a échoué. Vérifie ta connexion.';
    }
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Petits composants propres à cet écran
// ═══════════════════════════════════════════════════════════════════

/// Encart d'information : un fond très léger, jamais une bordure pleine.
///
/// Il commente une réponse sans jamais devenir le sujet de l'écran.
class _HintBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _HintBanner({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tint.withValues(alpha: AppColors.isDark ? 0.10 : 0.08),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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

/// Un jour de la semaine, en initiale.
class _DayToggle extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _DayToggle({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: selected ? AppColors.accentGradient : null,
            color: selected ? null : AppColors.card,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -3,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: selected
                  ? AppColors.onGradient
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Interrupteur présenté comme une carte, pour rester dans la même grammaire
/// visuelle que les autres réponses de l'assistant.
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: value
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.card,
          border: Border.all(
            color: value ? AppColors.success : AppColors.border,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: value ? AppColors.successText : AppColors.textHint,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Phase 2 : la composition
// ═══════════════════════════════════════════════════════════════════

/// L'écran d'attente — et il compte autant que le résultat.
///
/// La génération dure des dizaines de secondes. Un `CircularProgressIndicator`
/// pendant une minute se lit comme une application bloquée : l'adhérent quitte
/// l'écran, et il perd son quota pour rien.
///
/// Deux choses évitent ça : **un mouvement continu** (l'orbe respire, jamais
/// figée) et **des étapes nommées** qui défilent. Elles ne sont pas une
/// progression réelle — le serveur ne rend pas la main avant la fin — mais
/// elles décrivent fidèlement ce qui se passe, dans l'ordre où ça se passe.
/// L'attente devient un déroulé qu'on suit au lieu d'un vide qu'on subit.
class _GeneratingView extends StatefulWidget {
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _GeneratingView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  State<_GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<_GeneratingView> {
  static const List<({IconData icon, String label})> _steps = [
    (icon: Icons.person_search_rounded, label: 'Lecture de ton profil'),
    (
      icon: Icons.checklist_rounded,
      label: 'Sélection des exercices réalisables',
    ),
    (
      icon: Icons.calendar_view_week_rounded,
      label: 'Découpage de ta semaine',
    ),
    (
      icon: Icons.equalizer_rounded,
      label: 'Répartition du volume par muscle',
    ),
    (icon: Icons.scale_rounded, label: 'Calcul des séries et des charges'),
    (icon: Icons.edit_note_rounded, label: 'Rédaction des consignes'),
    (icon: Icons.verified_rounded, label: 'Dernières vérifications'),
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(_GeneratingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nouvelle tentative après une erreur : le déroulé repart du début.
    if (oldWidget.error != null && widget.error == null) {
      setState(() => _index = 0);
      _startTicker();
    } else if (widget.error != null) {
      _timer?.cancel();
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 5200), (_) {
      if (!mounted) return;
      // On s'arrête sur la dernière étape : la faire boucler donnerait
      // l'impression que le serveur recommence en rond.
      if (_index >= _steps.length - 1) {
        _timer?.cancel();
        return;
      }
      setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) return _errorView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        const SizedBox(height: 12),
        Center(child: const _PulsingOrb()),
        const SizedBox(height: 30),
        Text(
          'L\'IA compose ton programme',
          textAlign: TextAlign.center,
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Une trentaine de secondes. Reste sur cet écran — quitter '
          'maintenant annulerait la composition.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 34),
        for (var i = 0; i < _steps.length; i++)
          _GeneratingStep(
            icon: _steps[i].icon,
            label: _steps[i].label,
            done: i < _index,
            active: i == _index,
          ),
        const SizedBox(height: 26),
        Center(
          child: TextButton.icon(
            onPressed: widget.onCancel,
            icon: Icon(
              Icons.close_rounded,
              size: 17,
              color: AppColors.textHint,
            ),
            label: Text(
              'Annuler',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      children: [
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: AppColors.errorText,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'La composition n\'a pas abouti',
          textAlign: TextAlign.center,
          style: AppTextStyles.headingSmall,
        ),
        const SizedBox(height: 10),
        Text(
          widget.error!,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 30),
        PrimaryButton(
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          onPressed: widget.onRetry,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'Revenir au questionnaire',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// L'orbe qui respire pendant la composition.
///
/// Deux anneaux tournant en sens inverse et un cœur en dégradé qui pulse. La
/// rotation inverse est ce qui fait lire l'ensemble comme un mécanisme en
/// marche plutôt que comme une image animée.
class _PulsingOrb extends StatelessWidget {
  const _PulsingOrb();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.22),
                    width: 1.4,
                  ),
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.accent.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 3400.ms),
          Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    width: 1.4,
                  ),
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.primary.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2400.ms, begin: 1, end: 0),
          Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.heroGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.55),
                      blurRadius: 34,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 30,
                  color: AppColors.onGradient,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

/// Une étape du déroulé de composition : à venir, en cours, ou faite.
class _GeneratingStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final bool active;

  const _GeneratingStep({
    required this.icon,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.successText
        : active
        ? AppColors.accentText
        : AppColors.textDisabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: done || active ? 1 : 0.42,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: done
                  ? Icon(Icons.check_circle_rounded, size: 21, color: color)
                  : active
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: color,
                        strokeCap: StrokeCap.round,
                      ),
                    )
                  : Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: done || active
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Phase 3 : le résultat
// ═══════════════════════════════════════════════════════════════════

/// Le moment où le programme apparaît.
///
/// Il aurait été plus court d'atterrir directement sur l'écran de détail. Mais
/// après une minute d'attente, arriver sans transition sur une liste de séances
/// ne se lit pas comme une réussite — juste comme un écran de plus. Ces deux
/// secondes-là donnent au travail un aboutissement visible, et annoncent en une
/// ligne ce qui a été produit avant de le montrer.
class _DoneView extends StatelessWidget {
  final ProgramModel program;
  final VoidCallback onOpen;

  const _DoneView({super.key, required this.program, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
      children: [
        Center(
          child:
              Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.successGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.45),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 46,
                      color: AppColors.onGradient,
                    ),
                  )
                  .animate()
                  .scale(
                    duration: 480.ms,
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.5, 0.5),
                  )
                  .fadeIn(duration: 300.ms),
        ),
        const SizedBox(height: 26),
        Text(
              program.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.15),
        if (program.description != null &&
            program.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
                program.description!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .slideY(begin: 0.15),
        ],
        const SizedBox(height: 26),
        Row(
              children: [
                _ResultStat(
                  value: '${program.sessionCount}',
                  label: program.sessionCount > 1 ? 'séances' : 'séance',
                ),
                _ResultStat(
                  value: '${program.totalExercises}',
                  label: 'exercices',
                ),
                if (program.durationWeeks != null)
                  _ResultStat(
                    value: '${program.durationWeeks}',
                    label: 'semaines',
                  ),
              ],
            )
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms)
            .slideY(begin: 0.2),
        const SizedBox(height: 30),
        PrimaryButton(
              label: 'Ouvrir mon programme',
              icon: Icons.arrow_forward_rounded,
              onPressed: onOpen,
            )
            .animate()
            .fadeIn(delay: 560.ms, duration: 400.ms)
            .slideY(begin: 0.25),
        const SizedBox(height: 14),
        Text(
          'Il est enregistré dans « Mes programmes ». Tu peux le modifier, y '
          'ajouter une séance ou le supprimer comme n\'importe quel autre.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
      ],
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String value;
  final String label;

  const _ResultStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.statValue.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.statLabel),
          ],
        ),
      ),
    );
  }
}
