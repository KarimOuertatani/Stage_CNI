import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/ai_coach_models.dart';
import '../providers/ai_coach_provider.dart';
import '../widgets/ai_coach_avatar.dart';
import '../../../../core/widgets/screen_background.dart';

/// Conversation avec le **coach IA**.
///
/// Périmètre volontairement étroit : entraînement, nutrition, blessures liées au
/// sport, motivation sportive. Toute autre demande est déclinée par le serveur —
/// et l'interface le **montre** (bulle marquée, icône dédiée) plutôt que de
/// laisser croire à un bug.
///
/// Trois soins d'interface qui comptent :
/// - **la question apparaît immédiatement**, avant l'aller-retour serveur ;
/// - **le coach « réfléchit »** avec trois points animés, à l'emplacement exact
///   où sa réponse va apparaître ;
/// - **en cas d'échec, la question revient dans le champ**, elle n'est jamais
///   perdue.
class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  /// Nombre de messages à la dernière image : sert à ne défiler que lorsqu'un
  /// message **arrive**, sans lutter contre un défilement manuel.
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _input.clear();
    ref.read(aiCoachProvider.notifier).send(text);
  }

  /// Envoie une suggestion sans passer par le clavier.
  void _sendSuggestion(String text) {
    HapticFeedback.selectionClick();
    ref.read(aiCoachProvider.notifier).send(text);
  }

  void _scrollToEnd({bool animated = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _confirmClear() async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Nouvelle conversation ?', style: AppTextStyles.titleLarge),
        content: Text(
          'Tout l\'historique sera effacé. Le coach repartira sans mémoire de '
          'vos échanges précédents.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(aiCoachProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiCoachProvider);

    // Un message vient d'arriver (ou de partir) : on suit le fil. On ne le fait
    // pas à chaque image, sinon un défilement manuel vers le haut serait
    // constamment ramené en bas.
    final count = state.messages.length + (state.isThinking ? 1 : 0);
    if (count != _lastCount) {
      _lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }

    // Une question en échec est rendue au champ de saisie : elle n'est pas
    // perdue, et l'adhérent n'a pas à la retaper.
    //
    // ⚠️ Après l'image, jamais pendant. Écrire dans le contrôleur ici
    // notifierait ses auditeurs sur-le-champ — dont le champ de saisie, qui
    // appelle `setState` : « setState() called during build ».
    final notifier = ref.read(aiCoachProvider.notifier);
    if (notifier.failedText != null && _input.text.isEmpty) {
      final text = notifier.failedText!;
      notifier.failedText = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _input.text.isEmpty) _input.text = text;
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const AiCoachAvatar(size: 34),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Coach IA',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  state.isThinking ? 'écrit…' : 'Sport · Nutrition · Blessures',
                  style: AppTextStyles.caption.copyWith(
                    color: state.isThinking
                        ? AppColors.successText
                        : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!state.isEmpty)
            IconButton(
              tooltip: 'Nouvelle conversation',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: state.isThinking ? null : _confirmClear,
            ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (state.errorMessage != null)
                _ErrorBanner(
                  message: state.errorMessage!,
                  onDismiss: () =>
                      ref.read(aiCoachProvider.notifier).dismissError(),
                ),
              Expanded(child: _body(state)),
              _Composer(
                controller: _input,
                focusNode: _inputFocus,
                enabled: !state.isThinking,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AiCoachState state) {
    if (state.isLoading) {
      return const AppListSkeleton(itemCount: 4, itemHeight: 72);
    }
    if (state.isEmpty && !state.isThinking) {
      return _EmptyState(onSuggestion: _sendSuggestion);
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      itemCount: state.messages.length + (state.isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          // Le « il écrit… » occupe la place exacte où la réponse apparaîtra :
          // le regard n'a pas à se déplacer quand elle arrive.
          return const _ThinkingBubble();
        }
        final message = state.messages[index];
        return _MessageBubble(message: message)
            .animate()
            .fadeIn(duration: 220.ms)
            .slideY(begin: 0.08, curve: Curves.easeOutCubic);
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Une bulle de message
// ═════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final AiCoachMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromCoach = message.isFromCoach;

    return Align(
      alignment: fromCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        // 82 % : une bulle qui touche les deux bords perd le repère visuel qui
        // dit qui parle.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: fromCoach
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (fromCoach && message.topic != null)
              _TopicTag(topic: message.topic!, refused: message.refused),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                // L'adhérent parle en dégradé accent, le coach sur une surface
                // neutre : la lecture est immédiate, sans avoir à lire un nom.
                gradient: fromCoach ? null : AppColors.accentGradient,
                color: fromCoach
                    ? (message.refused
                          // Une demande déclinée n'est ni une erreur ni une
                          // réponse ordinaire : une teinte à part le dit sans mot.
                          ? AppColors.warning.withValues(alpha: 0.10)
                          : AppColors.card)
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  // Le coin « rentrant » côté auteur : le repère de bulle
                  // universel.
                  bottomLeft: Radius.circular(fromCoach ? 4 : 18),
                  bottomRight: Radius.circular(fromCoach ? 18 : 4),
                ),
                border: fromCoach
                    ? Border.all(
                        color: message.refused
                            ? AppColors.warning.withValues(alpha: 0.35)
                            : AppColors.border,
                      )
                    : null,
              ),
              child: Text(
                message.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: fromCoach
                      ? AppColors.textPrimary
                      : AppColors.onGradient,
                  height: 1.42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Étiquette de sujet au-dessus d'une réponse du coach.
///
/// Elle répond à une question que l'adhérent se poserait sinon : « pourquoi
/// est-ce qu'il refuse ? », « pourquoi ce rappel médical ? ». Voir la catégorie
/// rend le comportement du coach lisible au lieu d'arbitraire.
class _TopicTag extends StatelessWidget {
  final AiCoachTopic topic;
  final bool refused;

  const _TopicTag({required this.topic, required this.refused});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (topic) {
      AiCoachTopic.horsSujet => (
        'Hors de mon domaine',
        Icons.block_rounded,
        AppColors.warningText,
      ),
      AiCoachTopic.blessure => (
        'Blessure · avis non médical',
        Icons.health_and_safety_rounded,
        AppColors.errorText,
      ),
      AiCoachTopic.nutrition => (
        'Nutrition',
        Icons.restaurant_rounded,
        AppColors.accentText,
      ),
      AiCoachTopic.motivation => (
        'Motivation',
        Icons.local_fire_department_rounded,
        AppColors.accentText,
      ),
      AiCoachTopic.entrainement => (
        'Entraînement',
        Icons.fitness_center_rounded,
        AppColors.accentText,
      ),
    };

    // Sur les sujets ordinaires, l'étiquette n'apporte rien : la réponse parle
    // d'elle-même. On ne la montre que quand elle explique quelque chose.
    final worthShowing = refused || topic == AiCoachTopic.blessure;
    if (!worthShowing) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  « Le coach écrit… »
// ═════════════════════════════════════════════════════════════════════

/// Trois points animés, à l'emplacement exact de la future réponse.
///
/// Un indicateur en haut de l'écran ou dans l'AppBar oblige à chercher où la
/// réponse va apparaître. Ici, elle prend simplement la place des points.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Décalage de phase : les points ondulent au lieu de clignoter
              // ensemble.
              final phase = (_ctrl.value + i * 0.22) % 1.0;
              final scale = 0.6 + 0.4 * (1 - (phase - 0.5).abs() * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.accentText,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Champ de saisie
// ═════════════════════════════════════════════════════════════════════

class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    // Le bouton d'envoi s'active à la première lettre : un bouton toujours
    // actif qui ne fait rien est une promesse non tenue.
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && widget.controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: widget.enabled
                    ? 'Une question sur ton entraînement ?'
                    : 'Le coach réfléchit…',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                // Le compteur de 1000 caractères n'a aucun intérêt ici : il
                // n'ajouterait qu'un chiffre sous chaque frappe.
                counterText: '',
                filled: true,
                fillColor: AppColors.glassWhite,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: AppColors.accent, width: 1.6),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: canSend ? 1 : 0.4,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                  ),
                  child: InkWell(
                    onTap: canSend ? widget.onSend : null,
                    customBorder: const CircleBorder(),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.onGradient,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Fil vide : dire ce qu'on peut demander
// ═════════════════════════════════════════════════════════════════════

/// Écran d'accueil du fil.
///
/// Un champ de saisie vide face à une IA est intimidant : on ne sait pas ce
/// qu'elle sait faire, ni jusqu'où elle va. Les suggestions **délimitent le
/// périmètre en le montrant** — bien plus efficacement qu'une phrase
/// d'avertissement, et elles font gagner le premier message.
class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestion;

  const _EmptyState({required this.onSuggestion});

  static const _suggestions = [
    (
      Icons.fitness_center_rounded,
      'Un programme pour moi',
      'Propose-moi un programme adapté à mon objectif et à mon matériel.',
    ),
    (
      Icons.restaurant_rounded,
      'Mes macros',
      'Combien de protéines, glucides et lipides par jour pour mon objectif ?',
    ),
    (
      Icons.self_improvement_rounded,
      'Technique d\'un exercice',
      'Explique-moi la bonne technique du soulevé de terre.',
    ),
    (
      Icons.healing_rounded,
      'Une douleur',
      'J\'ai une douleur au genou après mes squats, que faire ?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        children: [
          const AiCoachAvatar(size: 76, glow: true)
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.9, 0.9)),
          const SizedBox(height: 18),
          Text(
            'Ton coach, à toute heure',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Entraînement, nutrition, douleurs liées au sport. Il connaît ton '
            'profil : objectif, niveau, matériel.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _suggestions.length; i++)
            _SuggestionTile(
                  icon: _suggestions[i].$1,
                  label: _suggestions[i].$2,
                  prompt: _suggestions[i].$3,
                  onTap: () => onSuggestion(_suggestions[i].$3),
                )
                .animate()
                .fadeIn(delay: (120 + i * 70).ms, duration: 300.ms)
                .slideY(begin: 0.1),
          const SizedBox(height: 14),
          // Dit en une phrase ce que le coach n'est pas. Placé ici plutôt qu'en
          // haut : l'adhérent lit d'abord ce qu'il gagne.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Il ne remplace ni ton coach, ni un médecin.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String prompt;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.icon,
    required this.label,
    required this.prompt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.accentText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prompt,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Bandeau d'erreur
// ═════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorText,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.errorText,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.errorText,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3);
  }
}
