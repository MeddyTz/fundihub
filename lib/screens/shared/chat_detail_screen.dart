import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/block_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/chat_date_divider.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/common/app_avatar.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  String _myId = '';
  String _myName = 'User';
  String _otherId = '';
  String _otherName = 'User';
  bool _presenceAttached = false;
  bool _readMarkedOnce = false;
  bool _isRecordingVoice = false;
  bool _isBlockedBetween = false;
  bool _blockedByMe = false;
  String _checkedBlockOtherId = '';
  DateTime? _recordStartedAt;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<app_auth.AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    _myId = auth.userModel?.uid ?? firebaseUser?.uid ?? '';
    _myName = auth.userModel?.fullName ??
        firebaseUser?.displayName ??
        firebaseUser?.email ??
        'User';
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-mark read when app comes back to foreground while in this chat.
    if (state == AppLifecycleState.resumed && _myId.isNotEmpty) {
      _markReadOnce(force: true);
    }
  }

  Future<void> _init() async {
    if (!mounted) return;
    if (_myId.isEmpty) {
      AppUtils.showSnackBar(
        context,
        'Session not ready. Please reopen the chat.',
        isError: true,
      );
      return;
    }
    final prov = context.read<ChatProvider>();
    prov.subscribeMessagesAndSummary(chatId: widget.chatId, myId: _myId);
    _readMarkedOnce = false; // Allow re-mark after re-init.
    await _markReadOnce();
  }

  Future<void> _markReadOnce({bool force = false}) async {
    if ((!force && _readMarkedOnce) || _myId.isEmpty) return;
    _readMarkedOnce = true;

    await context
        .read<ChatProvider>()
        .markChatRead(chatId: widget.chatId, userId: _myId);

    // Sync notification centre: opening a chat clears message notifications.
    try {
      await context.read<NotificationService>().markChatNotificationsRead(
            userId: _myId,
            chatId: widget.chatId,
          );
    } catch (_) {}
  }

  // ─── Resolve other user ──────────────────────────────────

  String _safeOtherName(ChatSummary? summary) {
    if (summary == null || _myId.isEmpty) {
      return _otherName != 'User' ? _otherName : 'Opening chat...';
    }
    if (summary.clientId == _myId) {
      final name = summary.fundiName.trim();
      return name.isNotEmpty && name.toLowerCase() != 'fundi' ? name : 'Fundi';
    }
    if (summary.fundiId == _myId) {
      final name = summary.clientName.trim();
      return name.isNotEmpty && name.toLowerCase() != 'client'
          ? name
          : 'Client';
    }
    if (_otherName != 'User') return _otherName;
    return 'Opening chat...';
  }

  String? _safeOtherImage(ChatSummary? summary) {
    if (summary == null || _myId.isEmpty) return null;
    if (summary.clientId == _myId) return summary.fundiImageUrl;
    if (summary.fundiId == _myId) return summary.clientImageUrl;
    return summary.otherPersonImage(_myId);
  }

  void _resolveOther(ChatSummary? summary) {
    if (summary == null || _myId.isEmpty) return;
    final otherId = summary.otherPersonId(_myId);
    if (otherId.isEmpty) return;
    _otherId = otherId;
    _otherName = summary.otherPersonName(_myId);

    if (_checkedBlockOtherId != otherId) {
      _checkedBlockOtherId = otherId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkBlockedBetween();
      });
    }

    if (!_presenceAttached) {
      _presenceAttached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ChatProvider>().attachPresence(
              chatId: widget.chatId,
              myId: _myId,
              otherUserId: _otherId,
            );
      });
    }
  }

  Future<void> _checkBlockedBetween() async {
    if (_myId.isEmpty || _otherId.isEmpty) return;
    try {
      final blockProvider = context.read<BlockProvider>();
      final blockedByMe = await blockProvider.isBlocked(_myId, _otherId);
      final blockedByOther = await blockProvider.isBlocked(_otherId, _myId);
      if (!mounted) return;
      setState(() {
        _blockedByMe = blockedByMe;
        _isBlockedBetween = blockedByMe || blockedByOther;
      });
    } catch (_) {}
  }

  // ─── Lifecycle ───────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_myId.isNotEmpty) {
      context
          .read<ChatProvider>()
          .leaveChat(chatId: widget.chatId, userId: _myId);
    }
    _recorder.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─── Scroll ──────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ─── Send actions ────────────────────────────────────────

  Future<void> _sendText(String text) async {
    if (_myId.isEmpty) return;
    final prov = context.read<ChatProvider>();
    final ok = await prov.sendText(
      chatId: widget.chatId,
      senderId: _myId,
      senderName: _myName,
      text: text,
      otherUserId: _otherId,
    );
    if (!mounted) return;
    if (!ok) {
      AppUtils.showSnackBar(
        context,
        prov.errorMessage ?? 'Failed to send message',
        isError: true,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    if (_myId.isEmpty) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      final prov = context.read<ChatProvider>();
      final ok = await prov.sendImage(
        chatId: widget.chatId,
        senderId: _myId,
        senderName: _myName,
        imageFile: File(picked.path),
        otherUserId: _otherId,
      );
      if (!mounted) return;
      if (!ok) {
        AppUtils.showSnackBar(
          context,
          prov.errorMessage ?? 'Failed to send photo',
          isError: true,
        );
        return;
      }
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Failed to pick photo', isError: true);
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_myId.isEmpty) return;
    if (_isRecordingVoice) {
      await _stopAndSendVoice();
    } else {
      await _startVoiceRecording();
    }
  }

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        AppUtils.showSnackBar(
          context,
          'Microphone permission denied',
          isError: true,
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _recordStartedAt = DateTime.now();
      });
      AppUtils.showSnackBar(
          context, 'Recording... tap the mic again to send.');
    } catch (_) {
      if (!mounted) return;
      AppUtils.showSnackBar(
          context, 'Failed to start recording', isError: true);
    }
  }

  Future<void> _stopAndSendVoice() async {
    try {
      final path = await _recorder.stop();
      final durationMs = _recordStartedAt == null
          ? null
          : DateTime.now()
              .difference(_recordStartedAt!)
              .inMilliseconds;
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _recordStartedAt = null;
        });
      }
      if (path == null || path.isEmpty || !mounted) return;
      final prov = context.read<ChatProvider>();
      final ok = await prov.sendVoice(
        chatId: widget.chatId,
        senderId: _myId,
        senderName: _myName,
        voiceFile: File(path),
        voiceDurationMs: durationMs,
        otherUserId: _otherId,
      );
      if (!mounted) return;
      if (!ok) {
        AppUtils.showSnackBar(
          context,
          prov.errorMessage ?? 'Failed to send voice note',
          isError: true,
        );
        return;
      }
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRecordingVoice = false);
      AppUtils.showSnackBar(
          context, 'Failed to send voice note', isError: true);
    }
  }

  Future<void> _sendLocation() async {
    if (_myId.isEmpty) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        AppUtils.showSnackBar(
          context,
          'Location permission denied',
          isError: true,
        );
        return;
      }
      if (mounted) AppUtils.showSnackBar(context, 'Getting your location...');
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      final prov = context.read<ChatProvider>();
      final ok = await prov.sendLocation(
        chatId: widget.chatId,
        senderId: _myId,
        senderName: _myName,
        lat: pos.latitude,
        lng: pos.longitude,
        label: 'My Location',
      );
      if (!mounted) return;
      if (!ok) {
        AppUtils.showSnackBar(
          context,
          prov.errorMessage ?? 'Failed to send location',
          isError: true,
        );
        return;
      }
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Failed to get location', isError: true);
    }
  }

  Future<void> _blockUser() async {
    if (_otherId.isEmpty) {
      AppUtils.showSnackBar(
          context, 'User details not ready yet.', isError: true);
      return;
    }
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Block $_otherName?',
      message:
          'Blocking this user will prevent them from messaging you. You can unblock them later in Settings.',
      confirmText: 'Block',
      isDanger: true,
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<BlockProvider>().blockUser(
            blockerId: _myId,
            blockedId: _otherId,
            blockedName: _otherName,
          );
      if (!mounted) return;
      setState(() {
        _blockedByMe = true;
        _isBlockedBetween = true;
      });
      AppUtils.showSnackBar(context, '$_otherName has been blocked.');
    } catch (_) {
      if (!mounted) return;
      AppUtils.showSnackBar(
          context, 'Failed to block user. Please try again.', isError: true);
    }
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ChatProvider>();
    final messages = prov.messages;
    final summary = prov.chatSummary;

    _resolveOther(summary);

    // Auto-scroll to bottom when new messages arrive.
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }

    final imageMessages = messages
        .where((m) =>
            m.isImage &&
            !m.isDeleted &&
            (m.imageUrl ?? '').trim().isNotEmpty)
        .toList();

    final isLocked = summary == null ? false : !summary.isChatOpen;
    final inputLocked = isLocked || _isBlockedBetween;

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: _buildAppBar(summary, prov),
      body: Column(
        children: [
          if (_isBlockedBetween)
            _ChatLockedBanner(
              message: _blockedByMe
                  ? 'You blocked $_otherName. Messaging is disabled until you unblock this user.'
                  : 'Messaging is disabled because this user has blocked you.',
            )
          else if (summary != null && !summary.isChatOpen)
            _ChatLockedBanner(message: summary.lockMessage),
          Expanded(
            child: prov.isLoading
                ? const _ChatSetupView()
                : prov.errorMessage != null
                    ? _ChatErrorView(
                        message: prov.errorMessage!,
                        onRetry: _init,
                      )
                    : messages.isEmpty
                        ? _EmptyChatView(otherName: _safeOtherName(summary))
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.only(
                                top: AppTheme.spaceMD,
                                bottom: AppTheme.spaceSM),
                            itemCount: messages.length,
                            itemBuilder: (_, i) {
                              final msg = messages[i];
                              final isMe = msg.senderId == _myId;
                              final showDate = i == 0 ||
                                  !_sameDay(
                                      messages[i - 1].createdAt,
                                      msg.createdAt);
                              final imageIndex = msg.isImage
                                  ? imageMessages.indexWhere(
                                      (m) => m.messageId == msg.messageId)
                                  : -1;
                              return Column(
                                children: [
                                  if (showDate)
                                    ChatDateDivider(date: msg.createdAt),
                                  ChatBubble(
                                    message: msg,
                                    isMe: isMe,
                                    imageMessages: imageMessages,
                                    initialImageIndex:
                                        imageIndex < 0 ? 0 : imageIndex,
                                    onDelete: isMe
                                        ? () => prov.deleteMessage(
                                            widget.chatId, msg.messageId)
                                        : null,
                                    // Pass avatar info so the bubble shows
                                    // the other person's photo / initials.
                                    otherName: _safeOtherName(summary),
                                    otherImageUrl: _safeOtherImage(summary),
                                  ),
                                ],
                              );
                            },
                          ),
          ),
          if (prov.isOtherTyping && !inputLocked)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceXXL,
                vertical: AppTheme.spaceXS,
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const _TypingDots(),
                  const SizedBox(width: AppTheme.spaceSM),
                  Text(
                    'typing...',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ChatInputBar(
            onSendText: _sendText,
            onSendImage: _sendImage,
            onSendLocation: _sendLocation,
            onToggleVoiceRecording: _toggleVoiceRecording,
            isRecordingVoice: _isRecordingVoice,
            onTyping: () {
              if (_myId.isEmpty || inputLocked) return;
              prov.onTyping(chatId: widget.chatId, userId: _myId);
            },
            isLocked: inputLocked,
            lockedMessage: _isBlockedBetween
                ? (_blockedByMe
                    ? 'You blocked $_otherName. Unblock to send messages again.'
                    : 'You cannot send messages to this user.')
                : summary?.lockMessage,
            isSending: prov.isSending,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ChatSummary? summary, ChatProvider prov) {
    final name = _safeOtherName(summary);
    final image = _safeOtherImage(summary);
    return AppBar(
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          AppAvatar(
            imageUrl: image,
            name: name,
            size: 36,
            backgroundColor: AppColors.white.withOpacity(0.2),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.white),
                ),
                Text(
                  _presenceLabel(prov),
                  style: AppTextStyles.caption.copyWith(
                    color: prov.isOtherOnline
                        ? AppColors.successLight
                        : AppColors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () =>
              context.push('/booking/detail', extra: widget.chatId),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'block') _blockUser();
            if (value == 'report') {
              if (_otherId.isEmpty) {
                AppUtils.showSnackBar(
                    context, 'User details not ready yet.', isError: true);
                return;
              }
              context.push('/report', extra: {
                'userId': _otherId,
                'userName': _otherName,
                'bookingId': widget.chatId,
              });
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'report',
              child: ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text('Report User'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: ListTile(
                leading:
                    Icon(Icons.block_rounded, color: Colors.red),
                title: Text('Block User',
                    style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _presenceLabel(ChatProvider prov) {
    if (prov.isOtherTyping) return 'Typing...';
    if (prov.isOtherOnline) return 'Online';
    final last = prov.otherLastSeenAt;
    if (last == null) return 'Offline';
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours} hr ago';
    return 'Last seen ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────

class _ChatLockedBanner extends StatelessWidget {
  final String message;
  const _ChatLockedBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceSM,
      ),
      color: AppColors.warningSurface,
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSetupView extends StatelessWidget {
  const _ChatSetupView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseLoader(
              size: 60,
              message: 'Setting up secure chat',
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'This may take a moment after accepting a booking.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  final String otherName;
  const _EmptyChatView({required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              'Start the conversation',
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'Discuss job details with $otherName. Contact details are available after the fundi accepts the booking.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChatErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 52, color: AppColors.error),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        children: List.generate(3, (i) {
          final v = (_c.value + i * .2) % 1;
          return Container(
            margin: const EdgeInsets.only(right: 3),
            width: 5 + (v > .5 ? 2 : 0),
            height: 5 + (v > .5 ? 2 : 0),
            decoration: const BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
