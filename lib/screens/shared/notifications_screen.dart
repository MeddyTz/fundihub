import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _State();
}

class _State extends State<NotificationsScreen> {
  List<NotificationModel> _notifs = [];
  bool _loading    = true;
  bool _markingAll = false;

  StreamSubscription<List<NotificationModel>>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _setup() {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loading = false); return; }

    _sub = context.read<NotificationService>().notificationsStream(uid).listen(
      (list) {
        if (mounted) setState(() { _notifs = list; _loading = false; });
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _markAll() async {
    if (_markingAll) return;
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isEmpty) return;
    setState(() => _markingAll = true);
    await context.read<NotificationService>().markAllRead(uid);
    if (mounted) setState(() => _markingAll = false);
  }

  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) {
      await context.read<NotificationService>().markOneRead(n.notifId);
    }
    if (!mounted) return;

    final navId = n.navigationId;
    if (navId == null || navId.isEmpty) return;

    if (n.isChatType) {
      context.push('/chat/detail', extra: navId);
    } else if (n.isBookingType) {
      context.push('/booking/detail', extra: navId);
    }
    // payment/fee types silently ignored (growth phase)
  }

  IconData _icon(String type) {
    final t = type.toLowerCase();
    if (t.contains('message') || t.contains('chat'))
      return Icons.chat_bubble_outline_rounded;
    if (t.contains('review'))          return Icons.star_outline_rounded;
    if (t.contains('disputed'))         return Icons.warning_amber_rounded;
    if (t.contains('completion_requested') || t.contains('awaiting'))
      return Icons.hourglass_top_rounded;
    if (t.contains('rejected')  || t.contains('cancelled'))
      return Icons.cancel_rounded;
    if (t.contains('accepted')  || t.contains('agreement'))
      return Icons.handshake_outlined;
    if (t.contains('completed')) return Icons.task_alt_rounded;
    if (t.contains('started')   || t.contains('progress'))
      return Icons.construction_rounded;
    if (t.contains('booking')   || t.contains('request'))
      return Icons.calendar_today_rounded;
    if (t.contains('expired'))   return Icons.timer_off_outlined;
    if (t.contains('reel')      || t.contains('approved'))
      return Icons.videocam_rounded;
    return Icons.notifications_outlined;
  }

  Color _color(String type) {
    final t = type.toLowerCase();
    if (t.contains('message') || t.contains('chat')) return AppColors.primary;
    if (t.contains('review'))     return AppColors.secondary;
    if (t.contains('disputed'))   return AppColors.warning;
    if (t.contains('completion_requested') || t.contains('awaiting'))
      return AppColors.secondary;
    if (t.contains('rejected')   || t.contains('cancelled') ||
        t.contains('expired'))    return AppColors.error;
    if (t.contains('completed')  || t.contains('accepted') ||
        t.contains('agreement'))  return AppColors.success;
    if (t.contains('reel'))       return const Color(0xFF9C27B0);
    return AppColors.primary;
  }

  String _label(String type) {
    final t = type.toLowerCase();
    if (t.contains('booking_request') || t == 'booking_request') return 'New Booking';
    if (t.contains('completion_requested') || t.contains('awaiting'))
      return 'Confirm Job';
    if (t.contains('disputed'))   return 'Disputed';
    if (t.contains('accepted'))   return 'Accepted';
    if (t.contains('rejected'))   return 'Rejected';
    if (t.contains('cancelled'))  return 'Cancelled';
    if (t.contains('agreement'))  return 'Agreement';
    if (t.contains('completed'))  return 'Completed';
    if (t.contains('started')  || t.contains('progress')) return 'In Progress';
    if (t.contains('review'))     return 'Review';
    if (t.contains('message')  || t.contains('chat'))    return 'Message';
    if (t.contains('expired'))    return 'Expired';
    if (t.contains('reel'))       return 'Reel';
    if (t.contains('request'))    return 'New Booking';
    return 'Notification';
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppL10n.of(context);
    final unread = context.watch<NotificationProvider>().totalUnread;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           Text(l10n.notifications),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAll,
              child: Text(
                _markingAll ? 'Marking…' : l10n.markAllRead,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: Column(children: [
          // ── Category filter chips ─────────────────────────────────
          _FilterChips(notifProv: context.watch<NotificationProvider>()),
          // ── Body ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoaderCenter()
                : _filtered(_notifs, context.watch<NotificationProvider>().activeFilter).isEmpty
                    ? AppEmptyState(
                        icon:      Icons.notifications_none_rounded,
                        title:     l10n.noNotifications,
                        subtitle:  'You are all caught up!',
                        iconColor: AppColors.grey400,
                      )
                    : RefreshIndicator(
                        onRefresh: () async { _sub?.cancel(); _setup(); },
                        child: ListView.separated(
                          padding:          const EdgeInsets.symmetric(vertical: 8),
                          itemCount:        _filtered(_notifs, context.watch<NotificationProvider>().activeFilter).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n     = _filtered(_notifs, context.watch<NotificationProvider>().activeFilter)[i];
                            final color = _color(n.type);
                            return Dismissible(
                              key: Key(n.notifId),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: AppColors.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete_rounded,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) {
                                context.read<NotificationProvider>()
                                    .deleteNotification(n.notifId);
                                setState(() => _notifs.removeWhere(
                                    (x) => x.notifId == n.notifId));
                              },
                              child: InkWell(
                                onTap: () => _onTap(n),
                                child: Container(
                          color: n.isRead ? null : color.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon circle
                              Container(
                                width:  44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:  color.withOpacity(0.12),
                                  shape:  BoxShape.circle,
                                ),
                                child: Icon(_icon(n.type), color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Label + time + unread dot
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:        color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(_label(n.type),
                                            style: AppTextStyles.caption.copyWith(
                                                color: color,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      const Spacer(),
                                      Text(
                                        AppUtils.formatRelativeTime(n.createdAt),
                                        style: AppTextStyles.caption
                                            .copyWith(color: AppColors.grey500),
                                      ),
                                      if (!n.isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width:  8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle),
                                        ),
                                      ],
                                    ]),
                                    const SizedBox(height: 4),
                                    // Title
                                    Text(n.title,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: n.isRead
                                                ? FontWeight.normal
                                                : FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    // Body
                                    Text(n.body,
                                        style: AppTextStyles.bodySmall
                                            .copyWith(color: AppColors.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                                        ),
                              ),
                            );
                    },
                  ),
                ),
          ),
        ]),
  );
  }

  // Filter helper
  List<NotificationModel> _filtered(
      List<NotificationModel> all, String? filter) {
    if (filter == null) return all;
    return all.where((n) {
      final t = n.type.toLowerCase();
      switch (filter) {
        case 'booking': return n.isBookingType;
        case 'chat':    return n.isChatType;
        case 'reel':    return t.contains('reel') || t.contains('approved') || t.contains('rejected');
        case 'system':  return !n.isBookingType && !n.isChatType &&
            !t.contains('reel');
        default: return true;
      }
    }).toList();
  }
}

// ── Category filter chips ─────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final NotificationProvider notifProv;
  const _FilterChips({required this.notifProv});

  @override
  Widget build(BuildContext context) {
    final cats = [
      (null,      'All'),
      ('booking', 'Bookings'),
      ('chat',    'Chats'),
      ('reel',    'Reels'),
      ('system',  'System'),
    ];
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: cats.map((e) {
          final selected = notifProv.activeFilter == e.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.$2),
              selected: selected,
              onSelected: (_) =>
                  notifProv.setFilter(selected ? null : e.$1),
              selectedColor: AppColors.primarySurface,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        }).toList()),
      ),
    );
  }
}
