import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _openingChatId;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final auth = context.read<AuthProvider>();
    final uid = auth.userModel?.uid;
    final isClient = auth.userModel?.isClient ?? true;
    if (uid != null && uid.isNotEmpty) {
      context.read<ChatProvider>().subscribeAllChats(uid, isClient);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userModel?.uid;
    final isClient = auth.userModel?.isClient ?? true;
    if (uid == null || uid.isEmpty) return;

    setState(() => _markingAllRead = true);
    await context
        .read<ChatProvider>()
        .markAllVisibleChatsRead(userId: uid, isClient: isClient);
    if (!mounted) return;
    setState(() => _markingAllRead = false);
    AppUtils.showSnackBar(context, 'All chats marked as read.');
  }

  Future<void> _openChat(ChatSummary chat, String myId) async {
    if (myId.isEmpty || _openingChatId != null) return;
    setState(() => _openingChatId = chat.chatId);

    // Optimistically clear unread before navigating.
    await context
        .read<ChatProvider>()
        .markChatRead(chatId: chat.chatId, userId: myId);

    if (!mounted) return;
    await context.push('/chat/detail', extra: chat.chatId);
    if (!mounted) return;
    setState(() => _openingChatId = null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProv = context.watch<ChatProvider>();
    final myId = auth.userModel?.uid ?? '';
    final chats = chatProv.allChats;

    final totalUnread =
        chats.fold<int>(0, (sum, c) => sum + c.unreadCountFor(myId));
    final hasUnread = totalUnread > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(totalUnread, hasUnread),
      body: chats.isEmpty
          ? const AppEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No Messages Yet',
              subtitle:
                  'Your conversations will appear here after a fundi accepts your booking.',
              iconColor: AppColors.grey400,
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: chats.length,
              itemBuilder: (_, i) {
                final chat = chats[i];
                final unread = chat.unreadCountFor(myId);
                return _ChatTile(
                  chat: chat,
                  myId: myId,
                  unreadCount: unread,
                  isOpening: _openingChatId == chat.chatId,
                  onTap: () => _openChat(chat, myId),
                );
              },
            ),
    );
  }

  AppBar _buildAppBar(int totalUnread, bool hasUnread) {
    return AppBar(
      title: Row(
        children: [
          const Text('Messages'),
          if (totalUnread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                totalUnread > 99 ? '99+' : '$totalUnread',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: true,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            )
          : null,
      actions: [
        TextButton.icon(
          onPressed: hasUnread && !_markingAllRead ? _markAllRead : null,
          icon: _markingAllRead
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: AppLoader(size: 16, color: Colors.white),
                )
              : Icon(
                  Icons.done_all_rounded,
                  color: hasUnread ? Colors.white : Colors.white38,
                  size: 18,
                ),
          label: Text(
            'Read all',
            style: TextStyle(
              color: hasUnread ? Colors.white : Colors.white38,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat tile
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final ChatSummary chat;
  final String myId;
  final int unreadCount;
  final bool isOpening;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.myId,
    required this.unreadCount,
    required this.isOpening,
    required this.onTap,
  });

  String get _preview {
    switch (chat.lastMessageType) {
      case 'image':
        return '📷 Photo';
      case 'voice':
        return '🎙️ Voice message';
      case 'location':
        return '📍 Location';
      default:
        final msg = chat.lastMessage.trim();
        return msg.isEmpty ? 'Tap to open chat' : msg;
    }
  }

  // Whether the last message was sent by the other person (not me).
  bool _isIncoming() => chat.lastSenderId.isNotEmpty && chat.lastSenderId != myId;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0 && _isIncoming();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpening ? null : onTap,
        child: AnimatedOpacity(
          opacity: isOpening ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceXXL,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              // Unread: light blue tint + left accent bar.
              color: hasUnread
                  ? const Color(0xFFEAF2FF)
                  : AppColors.surface,
              border: Border(
                left: BorderSide(
                  color: hasUnread
                      ? AppColors.primary
                      : Colors.transparent,
                  width: hasUnread ? 4 : 0,
                ),
                bottom:
                    BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar + online dot ──────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                      imageUrl: chat.otherPersonImage(myId),
                      name: chat.otherPersonName(myId),
                      size: 54,
                    ),
                    // Unread red dot on avatar edge.
                    if (hasUnread)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppTheme.spaceMD),

                // ── Name + preview ───────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              chat.otherPersonName(myId),
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppUtils.formatRelativeTime(
                                chat.lastMessageAt),
                            style: AppTextStyles.caption.copyWith(
                              color: hasUnread
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _preview,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: hasUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isOpening)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppLoader(size: 18, color: AppColors.primary),
                            )
                          else if (hasUnread)
                            _UnreadBadge(count: unreadCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unread badge
// ─────────────────────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      constraints:
          const BoxConstraints(minWidth: 22, minHeight: 22),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}
