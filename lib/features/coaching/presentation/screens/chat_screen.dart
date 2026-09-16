import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/network/media_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/document_picker.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/data/auth_token_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_socket.dart';
import '../../data/coaching_models.dart';
import '../../data/presence_models.dart';
import '../providers/coaching_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/coach_avatar.dart';

/// Conversation temps réel entre coach et adhérent.
///
/// **Trois flux temps réel** arrivent par une seule connexion WebSocket
/// ([ChatSocket]) : les messages, la **présence** de l'interlocuteur et son
/// **signal de frappe**. Le REST reste la source de vérité (historique, envoi,
/// accusés de lecture) et un rafraîchissement périodique sert de filet si le
/// socket tombe.
///
/// > **Attention à une confusion classique** : `_connected` décrit *notre*
/// > liaison au serveur, pas la présence de l'interlocuteur. Celle-ci vient de
/// > `_presence`, alimentée par le backend. Les deux étaient mélangés avant.
class ChatScreen extends ConsumerStatefulWidget {
  final String relationshipId;
  const ChatScreen({super.key, required this.relationshipId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  /// Messages indexés par id : permet de **remplacer** un message déjà connu
  /// (c'est ainsi que le passage de ✓ à ✓✓ remonte jusqu'à l'écran).
  final Map<String, ChatMessage> _byId = {};
  List<ChatMessage> _messages = const [];
  List<_ChatItem> _items = const [];

  /// Messages arrivés après le chargement initial : eux seuls s'animent, pour
  /// que l'ouverture de l'écran ne déclenche pas une cascade d'animations.
  final Set<String> _toAnimate = {};

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  CoachingRelationship? _rel;
  String? _myId;
  bool _loading = true;
  String? _error;
  bool _sending = false;

  /// Notre propre liaison WebSocket (≠ présence de l'interlocuteur).
  bool _connected = false;

  /// Présence de l'interlocuteur, `null` tant que le serveur n'a pas répondu.
  Presence? _presence;

  /// L'interlocuteur est en train d'écrire.
  bool _partnerTyping = false;
  Timer? _partnerTypingTimer;

  /// Émission de notre propre signal de frappe (limitée dans le temps).
  Timer? _typingStopTimer;
  DateTime? _typingSentAt;

  /// Bouton « descendre » : visible dès qu'on remonte dans l'historique.
  bool _showJumpButton = false;
  int _unseenCount = 0;

  // Enregistrement vocal.
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;

  ChatSocket? _socket;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _myId = ref.read(authProvider).user?.id;
    _inputCtrl.addListener(_onInputChanged);
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    try {
      final api = ref.read(coachingApiProvider);
      final rel = await api.getRelationship(widget.relationshipId);
      final msgs = await api.getMessages(widget.relationshipId);
      if (!mounted) return;
      setState(() {
        _rel = rel;
        _mergeAll(msgs);
        _loading = false;
      });
      _loadPresence();
      _connectSocket();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  // ── Présence ───────────────────────────────────────────────────

  /// État initial de la présence : le WebSocket ne pousse que les
  /// *changements*, il faut donc demander l'état courant à l'ouverture.
  Future<void> _loadPresence() async {
    final otherId = _other?.userId;
    if (otherId == null) return;
    try {
      final presence = await ref.read(coachingApiProvider).getPresence(otherId);
      if (mounted) setState(() => _presence = presence);
    } catch (_) {
      // Présence indisponible : l'en-tête n'affichera simplement rien.
    }
  }

  void _onPresence(Presence presence) {
    if (presence.userId != _other?.userId || !mounted) return;
    setState(() {
      _presence = presence;
      // Quelqu'un qui se déconnecte n'est plus en train d'écrire.
      if (!presence.online) _partnerTyping = false;
    });
  }

  // ── Frappe ─────────────────────────────────────────────────────

  /// Signal reçu : l'interlocuteur écrit (ou s'est arrêté).
  void _onTypingSignal(TypingSignal signal) {
    if (signal.relationshipId != widget.relationshipId) return;
    if (signal.userId == _myId || !mounted) return;

    _partnerTypingTimer?.cancel();
    setState(() => _partnerTyping = signal.typing);

    if (signal.typing) {
      // Filet de sécurité : si le signal d'arrêt se perd (réseau coupé,
      // app fermée), les points ne doivent pas rester affichés indéfiniment.
      _partnerTypingTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) setState(() => _partnerTyping = false);
      });
    }
  }

  /// Notre frappe : annoncée au plus une fois toutes les 2 s, et suivie d'un
  /// arrêt automatique après 3 s d'inactivité.
  void _onInputChanged() {
    if (!(_rel?.isAccepted ?? false)) return;
    if (_inputCtrl.text.isEmpty) {
      _stopTyping();
      return;
    }

    final now = DateTime.now();
    if (_typingSentAt == null ||
        now.difference(_typingSentAt!).inSeconds >= 2) {
      _socket?.sendTyping(widget.relationshipId, typing: true);
      _typingSentAt = now;
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    if (_typingSentAt != null) {
      _socket?.sendTyping(widget.relationshipId, typing: false);
      _typingSentAt = null;
    }
  }

  // ── Socket ─────────────────────────────────────────────────────

  Future<void> _connectSocket() async {
    final token = await AuthTokenStore.instance.read();
    if (token == null || !mounted) return;
    _socket = ChatSocket(
      token: token,
      onStatus: (connected) {
        if (mounted) setState(() => _connected = connected);
      },
      onMessage: (m) {
        if (m.relationshipId != widget.relationshipId || !mounted) return;
        setState(() {
          _partnerTyping = false; // le message remplace la frappe
          _addMessage(m, incoming: true);
        });
        _markReadSilently();
      },
      onPresence: _onPresence,
      onTyping: _onTypingSignal,
    );
    _socket!.connect();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final msgs = await ref
          .read(coachingApiProvider)
          .getMessages(widget.relationshipId);
      if (!mounted) return;
      setState(() => _mergeAll(msgs));
    } catch (_) {
      // silencieux : simple filet de sécurité
    }
  }

  // ── Liste de messages ──────────────────────────────────────────

  /// Fusionne l'historique reçu. Les messages déjà connus sont **remplacés**,
  /// pas ignorés : sans cela, un `readAt` mis à jour côté serveur ne
  /// remonterait jamais et l'accusé de lecture resterait bloqué sur ✓.
  void _mergeAll(List<ChatMessage> msgs) {
    for (final m in msgs) {
      _byId[m.id] = m;
    }
    _rebuild();
  }

  void _addMessage(ChatMessage m, {bool incoming = false}) {
    final isNew = !_byId.containsKey(m.id);
    _byId[m.id] = m;
    if (isNew) _toAnimate.add(m.id);
    _rebuild();

    if (isNew && incoming && _showJumpButton) {
      _unseenCount++;
    } else if (isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _rebuild() {
    // Un message tout juste envoyé peut ne pas avoir encore de sentAt : on le
    // considère comme « maintenant » pour qu'il se place en bas (le plus
    // récent), et non tout en haut (ce que donnait un repli à l'an 0).
    final now = DateTime.now();
    _messages = _byId.values.toList()
      ..sort((a, b) => (a.sentAt ?? now).compareTo(b.sentAt ?? now));
    _items = _buildItems(_messages);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    // Liste inversée : offset 0 = tout en bas (message le plus récent).
    final scrolledUp = _scrollCtrl.offset > 220;
    if (scrolledUp != _showJumpButton) {
      setState(() {
        _showJumpButton = scrolledUp;
        if (!scrolledUp) _unseenCount = 0;
      });
    } else if (!scrolledUp && _unseenCount != 0) {
      setState(() => _unseenCount = 0);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _markReadSilently() async {
    try {
      await ref.read(coachingApiProvider).markRead(widget.relationshipId);
      invalidateCoachingW(ref);
    } catch (_) {}
  }

  // ── Envoi texte ────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    _stopTyping();
    try {
      final sent = await ref
          .read(coachingApiProvider)
          .sendMessage(widget.relationshipId, content: text);
      if (!mounted) return;
      setState(() {
        _addMessage(sent);
        _sending = false;
      });
      invalidateCoachingW(ref);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _inputCtrl.text = text;
        _snack(_msg(e));
      }
    }
  }

  // ── Pièces jointes ─────────────────────────────────────────────

  void _openAttachSheet() {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Envoyer une pièce jointe',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _AttachOption(
                    icon: Icons.photo_camera_rounded,
                    label: 'Appareil',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _AttachOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickDocument();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1920,
      );
      if (file == null) return;
      await _uploadAndSend(
        path: file.path,
        filename: file.name,
        contentType: file.mimeType ?? _mimeFromName(file.name),
      );
    } catch (e) {
      if (mounted) _snack('Photo impossible : $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final doc = await DocumentPicker.pick();
      if (doc == null) return;
      await _uploadAndSend(
        path: doc.path,
        filename: doc.name,
        contentType: _mimeFromName(doc.name),
      );
    } on DocumentPickerUnsupported catch (e) {
      if (mounted) _snack(e.toString());
    } catch (e) {
      if (mounted) _snack('Document impossible : $e');
    }
  }

  /// Upload le fichier puis envoie le message avec la pièce jointe.
  Future<void> _uploadAndSend({
    required String path,
    String? filename,
    String? contentType,
    int? durationSec,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final media = await ref
          .read(mediaApiProvider)
          .uploadPath(path, filename: filename, contentType: contentType);
      final sent = await ref
          .read(coachingApiProvider)
          .sendMessage(
            widget.relationshipId,
            attachmentUrl: media.url,
            attachmentKind: _toChatKind(media.kind),
            attachmentName: media.fileName,
            attachmentSize: media.size,
            attachmentDurationSec: durationSec,
          );
      if (!mounted) return;
      setState(() {
        _addMessage(sent);
        _sending = false;
      });
      invalidateCoachingW(ref);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _snack(_msg(e));
      }
    }
  }

  // ── Enregistrement vocal ───────────────────────────────────────

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      if (!await _recorder.hasPermission()) {
        _snack('Micro non autorisé');
        return;
      }
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
      HapticFeedback.mediumImpact();
      setState(() {
        _recording = true;
        _recordPath = filePath;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) _snack(_msg(e));
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    HapticFeedback.selectionClick();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _recording = false;
        _recordSeconds = 0;
        _recordPath = null;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recordPath;
    if (mounted) {
      setState(() {
        _recording = false;
        _recordSeconds = 0;
        _recordPath = null;
      });
    }
    if (path == null || seconds < 1) return; // trop court : on ignore
    await _uploadAndSend(
      path: path,
      filename: 'message_vocal.m4a',
      contentType: 'audio/mp4',
      durationSec: seconds,
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    // Ne pas laisser l'interlocuteur avec des points de frappe figés à l'écran.
    _stopTyping();
    _poll?.cancel();
    _recordTimer?.cancel();
    _partnerTypingTimer?.cancel();
    _recorder.dispose();
    _socket?.dispose();
    _inputCtrl.removeListener(_onInputChanged);
    _inputCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  PersonRef? get _other {
    final rel = _rel;
    if (rel == null || _myId == null) return null;
    return rel.coach.userId == _myId ? rel.member : rel.coach;
  }

  // ── Construction ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final other = _other;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: _ChatHeader(
          other: other,
          presence: _presence,
          typing: _partnerTyping,
          socketConnected: _connected,
        ),
        actions: [
          IconButton(
            tooltip: 'Mes conversations',
            icon: const Icon(Icons.forum_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/conversations');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.screenGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _messagesArea()),
                    Positioned(right: 16, bottom: 12, child: _jumpButton()),
                  ],
                ),
              ),
              _InputBar(
                controller: _inputCtrl,
                sending: _sending,
                enabled: _rel?.isAccepted ?? false,
                recording: _recording,
                recordSeconds: _recordSeconds,
                onSend: _send,
                onAttach: _openAttachSheet,
                onStartRecording: _startRecording,
                onStopRecording: _stopAndSendRecording,
                onCancelRecording: _cancelRecording,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bouton de retour en bas, avec le nombre de messages arrivés entre-temps.
  Widget _jumpButton() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: _showJumpButton ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _showJumpButton ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_showJumpButton,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _unseenCount = 0);
              _scrollToBottom();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _unseenCount > 0 ? 14 : 11,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_unseenCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '$_unseenCount',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onGradient,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messagesArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorState(message: _error, onRetry: _init);
    }
    if (_messages.isEmpty && !_partnerTyping) {
      return const AppEmptyState(
        icon: Icons.forum_outlined,
        title: 'Démarrez la conversation',
        message:
            'Envoyez un message, une photo ou un vocal pour lancer les échanges.',
      );
    }

    final other = _other;
    // Les points de frappe occupent la place du prochain message : en tête de
    // la liste inversée, donc tout en bas à l'écran.
    final typingSlot = _partnerTyping && other != null ? 1 : 0;

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      itemCount: _items.length + typingSlot,
      itemBuilder: (context, index) {
        if (typingSlot == 1 && index == 0) {
          // typingSlot ne vaut 1 que si `other` est non nul (cf. ci-dessus).
          return ChatTypingBubble(
            initials: other!.initials,
            avatarUrl: other.avatarUrl,
          );
        }
        final item = _items[_items.length - 1 - (index - typingSlot)];
        return switch (item) {
          _DaySeparatorItem(:final day) => ChatDateSeparator(day: day),
          _MessageItem(
            :final message,
            :final firstOfGroup,
            :final lastOfGroup,
          ) =>
            _buildBubble(message, firstOfGroup, lastOfGroup, other),
        };
      },
    );
  }

  Widget _buildBubble(
    ChatMessage message,
    bool firstOfGroup,
    bool lastOfGroup,
    PersonRef? other,
  ) {
    final mine = message.senderId == _myId;
    final bubble = ChatBubble(
      message: message,
      mine: mine,
      firstOfGroup: firstOfGroup,
      lastOfGroup: lastOfGroup,
      senderInitials: other?.initials,
      senderAvatarUrl: other?.avatarUrl,
    );

    // Seuls les messages arrivés pendant la session s'animent : rouvrir une
    // conversation ne doit pas rejouer tout l'historique.
    if (!_toAnimate.contains(message.id)) return bubble;
    return bubble
        .animate()
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.96, end: 1, duration: 220.ms);
  }

  // ── Regroupement des messages ──────────────────────────────────

  /// Transforme la liste plate de messages en éléments d'affichage :
  /// séparateurs de date + messages annotés de leur position dans un groupe.
  static List<_ChatItem> _buildItems(List<ChatMessage> messages) {
    final items = <_ChatItem>[];
    DateTime? currentDay;

    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final at = m.sentAt;
      final day = at == null ? null : DateTime(at.year, at.month, at.day);

      if (day != null && day != currentDay) {
        items.add(_DaySeparatorItem(day));
        currentDay = day;
      }

      items.add(
        _MessageItem(
          m,
          firstOfGroup: !_sameGroup(i > 0 ? messages[i - 1] : null, m),
          lastOfGroup: !_sameGroup(
            m,
            i < messages.length - 1 ? messages[i + 1] : null,
          ),
        ),
      );
    }
    return items;
  }

  /// Deux messages appartiennent au même groupe s'ils viennent du même
  /// expéditeur, le même jour, à moins de 5 minutes d'intervalle.
  static bool _sameGroup(ChatMessage? a, ChatMessage? b) {
    if (a == null || b == null) return false;
    if (a.senderId != b.senderId) return false;

    final ta = a.sentAt;
    final tb = b.sentAt;
    if (ta == null || tb == null) return false;
    if (ta.year != tb.year || ta.month != tb.month || ta.day != tb.day) {
      return false;
    }
    return tb.difference(ta).abs().inMinutes < 5;
  }

  ChatAttachmentKind _toChatKind(MediaKind k) => switch (k) {
    MediaKind.image => ChatAttachmentKind.image,
    MediaKind.audio => ChatAttachmentKind.audio,
    MediaKind.file => ChatAttachmentKind.file,
  };

  static String _mimeFromName(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.split(': ').last : s;
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Éléments d'affichage de la liste
// ═════════════════════════════════════════════════════════════════════

sealed class _ChatItem {}

class _DaySeparatorItem extends _ChatItem {
  final DateTime day;
  _DaySeparatorItem(this.day);
}

class _MessageItem extends _ChatItem {
  final ChatMessage message;
  final bool firstOfGroup;
  final bool lastOfGroup;

  _MessageItem(
    this.message, {
    required this.firstOfGroup,
    required this.lastOfGroup,
  });
}

// ═════════════════════════════════════════════════════════════════════
//  En-tête : identité + présence + frappe
// ═════════════════════════════════════════════════════════════════════

/// Titre de la barre : avatar avec pastille de présence, nom, et une ligne
/// d'état qui change en direct.
///
/// L'ordre de priorité de la ligne d'état est délibéré : une frappe en cours
/// est l'information la plus vivante, elle passe donc devant « En ligne ».
class _ChatHeader extends StatelessWidget {
  final PersonRef? other;
  final Presence? presence;
  final bool typing;
  final bool socketConnected;

  const _ChatHeader({
    required this.other,
    required this.presence,
    required this.typing,
    required this.socketConnected,
  });

  @override
  Widget build(BuildContext context) {
    final person = other;
    final status = _status();

    return Row(
      children: [
        if (person != null)
          CoachAvatar(
            initials: person.initials,
            avatarUrl: person.avatarUrl,
            size: 40,
            online: presence?.online,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person?.fullName ?? 'Conversation',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
                child: status == null
                    ? const SizedBox(key: ValueKey('none'), height: 0)
                    : Text(
                        status.$1,
                        key: ValueKey(status.$1),
                        style: AppTextStyles.caption.copyWith(
                          color: status.$2,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Libellé + couleur de la ligne d'état, ou `null` s'il n'y a rien d'honnête
  /// à afficher (présence inconnue).
  (String, Color)? _status() {
    if (typing) return ('en train d\'écrire…', AppColors.accentText);
    if (!socketConnected) return ('Connexion…', AppColors.textHint);

    final label = presence?.label;
    if (label == null) return null;
    return (
      label,
      presence!.online ? AppColors.successText : AppColors.textHint,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Barre de saisie
// ═════════════════════════════════════════════════════════════════════

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final bool recording;
  final int recordSeconds;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.recording,
    required this.recordSeconds,
    required this.onSend,
    required this.onAttach,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        color: AppColors.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Le suivi n\'est plus actif : la messagerie est en lecture seule.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: widget.recording ? _recordingRow(context) : _inputRow(context),
      ),
    );
  }

  Widget _inputRow(BuildContext context) {
    return Row(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Joindre',
          icon: Icon(
            Icons.add_circle_outline_rounded,
            color: AppColors.primaryText,
            size: 28,
          ),
          onPressed: widget.sending ? null : widget.onAttach,
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Votre message…',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textDisabled,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _actionButton(
          icon: _hasText ? Icons.send_rounded : Icons.mic_rounded,
          loading: widget.sending,
          onTap: () {
            HapticFeedback.selectionClick();
            if (_hasText) {
              widget.onSend();
            } else {
              widget.onStartRecording();
            }
          },
        ),
      ],
    );
  }

  Widget _recordingRow(BuildContext context) {
    return Row(
      key: const ValueKey('recording'),
      children: [
        IconButton(
          tooltip: 'Annuler',
          icon: Icon(Icons.delete_outline_rounded, color: AppColors.errorText),
          onPressed: widget.onCancelRecording,
        ),
        Expanded(
          child: Row(
            children: [
              const _PulsingDot(),
              const SizedBox(width: 10),
              Text(
                'Enregistrement…  ${_fmt(widget.recordSeconds)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _actionButton(
          icon: Icons.send_rounded,
          loading: widget.sending,
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onStopRecording();
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onGradient,
                ),
              )
            : Icon(icon, color: AppColors.onGradient, size: 22),
      ),
    );
  }

  static String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_ctrl),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
