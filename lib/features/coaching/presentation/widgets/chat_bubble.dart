import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/coaching_models.dart';
import 'coach_avatar.dart';

/// Bulle de message.
///
/// Les messages consécutifs d'un même expéditeur forment un **groupe** :
/// - [firstOfGroup] arrondit le coin haut du côté de l'expéditeur ;
/// - [lastOfGroup] dessine la « pointe » et porte l'avatar de l'interlocuteur.
///
/// Ce regroupement est ce qui distingue une messagerie d'une simple liste :
/// cinq messages d'affilée se lisent comme un bloc, pas comme cinq objets
/// indépendants.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool firstOfGroup;
  final bool lastOfGroup;

  /// Avatar de l'interlocuteur (messages reçus, dernier du groupe seulement).
  final String? senderInitials;
  final String? senderAvatarUrl;

  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    this.firstOfGroup = true,
    this.lastOfGroup = true,
    this.senderInitials,
    this.senderAvatarUrl,
  });

  static const double _avatarSize = 28;
  static const double _bigRadius = 18;
  static const double _tightRadius = 5;

  bool get _isImage => message.attachmentKind == ChatAttachmentKind.image;

  @override
  Widget build(BuildContext context) {
    final onColor = mine ? AppColors.onGradient : AppColors.textPrimary;

    return Padding(
      // Serré à l'intérieur d'un groupe, aéré entre deux groupes.
      padding: EdgeInsets.only(bottom: lastOfGroup ? 10 : 2.5),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) _leadingAvatar(),
          Flexible(child: _bubble(context, onColor)),
        ],
      ),
    );
  }

  /// Avatar sur le dernier message du groupe ; ailleurs, une simple gouttière
  /// pour que toutes les bulles du groupe restent alignées.
  Widget _leadingAvatar() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: _avatarSize,
        child: lastOfGroup
            ? CoachAvatar(
                initials: senderInitials ?? '?',
                avatarUrl: senderAvatarUrl,
                size: _avatarSize,
              )
            : null,
      ),
    );
  }

  Widget _bubble(BuildContext context, Color onColor) {
    return GestureDetector(
      onLongPress: message.hasText ? () => _copy(context) : null,
      child: Container(
        padding: EdgeInsets.all(_isImage ? 5 : 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          gradient: mine ? AppColors.primaryGradient : null,
          color: mine ? null : AppColors.card,
          borderRadius: _radius(),
          border: mine ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: (mine ? AppColors.primary : Colors.black).withValues(
                alpha: mine ? 0.22 : 0.07,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.hasAttachment) _attachment(onColor),
            if (message.hasText) ...[
              if (message.hasAttachment) const SizedBox(height: 6),
              Padding(
                padding: _innerPadding,
                child: Text(
                  message.content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: onColor,
                    height: 1.32,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 3),
            Padding(padding: _innerPadding, child: _footer(onColor)),
          ],
        ),
      ),
    );
  }

  EdgeInsets get _innerPadding =>
      _isImage ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.zero;

  /// Coins : ronds partout, sauf celui qui « pointe » vers l'expéditeur sur le
  /// dernier message du groupe, et celui qui soude les bulles entre elles.
  BorderRadius _radius() {
    final tight = Radius.circular(_tightRadius);
    const big = Radius.circular(_bigRadius);
    return BorderRadius.only(
      topLeft: (!mine && !firstOfGroup) ? tight : big,
      topRight: (mine && !firstOfGroup) ? tight : big,
      bottomLeft: (!mine && lastOfGroup) ? tight : big,
      bottomRight: (mine && lastOfGroup) ? tight : big,
    );
  }

  /// Heure +, pour mes messages, l'état d'acheminement.
  Widget _footer(Color onColor) {
    final subtle = mine
        ? AppColors.onGradient.withValues(alpha: 0.75)
        : AppColors.textHint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _time(message.sentAt),
          style: AppTextStyles.caption.copyWith(color: subtle, fontSize: 9.5),
        ),
        if (mine) ...[
          const SizedBox(width: 4),
          // ✓ envoyé · ✓✓ lu. L'information vient de `readAt`, déjà porté par
          // l'API : aucun aller-retour supplémentaire.
          Icon(
            message.readAt != null
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 13,
            color: message.readAt != null
                ? AppColors.onGradient
                : AppColors.onGradient.withValues(alpha: 0.6),
          ),
        ],
      ],
    );
  }

  Widget _attachment(Color onColor) {
    switch (message.attachmentKind) {
      case ChatAttachmentKind.image:
        return _ImageAttachment(message: message);
      case ChatAttachmentKind.audio:
        return _VoiceAttachment(message: message, mine: mine);
      case ChatAttachmentKind.file:
      case null:
        return _FileAttachment(message: message, onColor: onColor);
    }
  }

  void _copy(BuildContext context) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Message copié'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.card,
        ),
      );
  }

  static String _time(DateTime? d) {
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Séparateur de date
// ═════════════════════════════════════════════════════════════════════

/// Pastille « Aujourd'hui » / « Hier » / « mardi 21 juillet » entre deux jours.
class ChatDateSeparator extends StatelessWidget {
  final DateTime day;
  const ChatDateSeparator({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label(day),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Libellé relatif tant qu'il reste plus parlant qu'une date absolue.
  static String label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final days = today.difference(that).inDays;

    if (days == 0) return "Aujourd'hui";
    if (days == 1) return 'Hier';
    if (days > 1 && days < 7) return _capitalize(_weekdays[d.weekday - 1]);

    final sameYear = d.year == now.year;
    final base = '${d.day} ${_months[d.month - 1]}';
    return sameYear ? base : '$base ${d.year}';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
}

// ═════════════════════════════════════════════════════════════════════
//  Indicateur « en train d'écrire »
// ═════════════════════════════════════════════════════════════════════

/// Bulle à trois points animés, à la place qu'occuperait le prochain message.
///
/// L'animation est décalée point par point : c'est ce décalage qui donne
/// l'impression de quelqu'un en train de taper, plutôt qu'un simple clignotant.
class ChatTypingBubble extends StatefulWidget {
  final String initials;
  final String? avatarUrl;

  const ChatTypingBubble({super.key, required this.initials, this.avatarUrl});

  @override
  State<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends State<ChatTypingBubble>
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CoachAvatar(
              initials: widget.initials,
              avatarUrl: widget.avatarUrl,
              size: 28,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(5),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => _dot(i)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    // Chaque point est en retard d'un tiers de cycle sur le précédent.
    final phase = (_ctrl.value - index * 0.18) % 1.0;
    // Une seule bosse par cycle, puis repos : le point « rebondit ».
    final wave = phase < 0.5 ? Curves.easeInOut.transform(phase * 2) : 0.0;
    final lift = wave <= 0.5 ? wave * 2 : (1 - wave) * 2;

    return Padding(
      padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
      child: Transform.translate(
        offset: Offset(0, -3 * lift),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(
              alpha: 0.45 + 0.55 * lift,
            ),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Pièces jointes
// ═════════════════════════════════════════════════════════════════════

class _ImageAttachment extends StatelessWidget {
  final ChatMessage message;
  const _ImageAttachment({required this.message});

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.mediaUrl(message.attachmentUrl);
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ImageViewer(url: url, tag: message.id),
        ),
      ),
      child: Hero(
        tag: message.id,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, minWidth: 140),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 160,
                  width: 200,
                  alignment: Alignment.center,
                  color: AppColors.surface,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (_, _, _) => Container(
                height: 120,
                width: 180,
                alignment: Alignment.center,
                color: AppColors.surface,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  final ChatMessage message;
  final Color onColor;
  const _FileAttachment({required this.message, required this.onColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: onColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.insert_drive_file_rounded,
            color: onColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.attachmentName ?? 'Document',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (message.attachmentSize != null)
                Text(
                  _humanSize(message.attachmentSize!),
                  style: AppTextStyles.caption.copyWith(
                    color: onColor.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

/// Lecteur de message vocal (play/pause + progression).
class _VoiceAttachment extends StatefulWidget {
  final ChatMessage message;
  final bool mine;
  const _VoiceAttachment({required this.message, required this.mine});

  @override
  State<_VoiceAttachment> createState() => _VoiceAttachmentState();
}

class _VoiceAttachmentState extends State<_VoiceAttachment> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.message.attachmentDurationSec ?? 0);
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _toggle() async {
    final url = ApiConstants.mediaUrl(widget.message.attachmentUrl);
    if (url == null) return;
    HapticFeedback.selectionClick();
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(url));
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onColor = widget.mine ? AppColors.onGradient : AppColors.textPrimary;
    final total = _total.inMilliseconds == 0 ? 1 : _total.inMilliseconds;
    final progress = (_position.inMilliseconds / total)
        .clamp(0.0, 1.0)
        .toDouble();

    return SizedBox(
      width: 190,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: onColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: onColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: onColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(onColor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: 12,
                      color: onColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(
                        _playing || _position > Duration.zero
                            ? _position
                            : _total,
                      ),
                      style: AppTextStyles.caption.copyWith(color: onColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Visionneuse plein écran d'une image.
class _ImageViewer extends StatelessWidget {
  final String url;
  final String tag;
  const _ImageViewer({required this.url, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
