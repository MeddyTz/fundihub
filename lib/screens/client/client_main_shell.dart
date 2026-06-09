import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/lang_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/reel_provider.dart';
import '../shared/chat_list_screen.dart';
import '../shared/reels_screen.dart';
import 'client_bookings_screen.dart';
import 'client_dashboard_screen.dart';
import 'client_profile_screen.dart';

class ClientMainShell extends StatefulWidget {
  const ClientMainShell({super.key});

  @override
  State<ClientMainShell> createState() => _ClientMainShellState();
}

class _ClientMainShellState extends State<ClientMainShell>
    with TickerProviderStateMixin {
  int _idx = 0;
  late final List<AnimationController> _iconControllers;

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _iconControllers[0].forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _subscribe() {
    // If starting on Reels tab, mark active
    if (_idx == 2) {
      context.read<ReelProvider>().setReelsTabActive(true);
    }
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null || uid.isEmpty) return;
    context.read<ChatProvider>().subscribeAllChats(uid, true);
    context.read<BookingProvider>().subscribeClientBookings(uid);
    context.read<NotificationProvider>().subscribe(uid);
  }

  void _onTabTap(int i) {
    if (_idx == i) return;
    HapticFeedback.selectionClick();
    _iconControllers[_idx].reverse();
    _iconControllers[i].forward();
    // Pause reels when leaving the Reels tab; resume when entering
    const reelsTab = 2;
    if (_idx == reelsTab && i != reelsTab) {
      context.read<ReelProvider>().setReelsTabActive(false);
    } else if (i == reelsTab && _idx != reelsTab) {
      context.read<ReelProvider>().setReelsTabActive(true);
    }
    setState(() => _idx = i);
  }

  List<Widget> get _screens => const [
        ClientDashboardScreen(),
        ClientBookingsScreen(),
        ReelsScreen(),
        ChatListScreen(),
        ClientProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myId = auth.userModel?.uid ?? '';
    final chatProv = context.watch<ChatProvider>();
    final notifProv = context.watch<NotificationProvider>();
    final bp = context.watch<BookingProvider>();
    final l10n = AppL10n.of(context);

    final chatBadgeFromChats =
        myId.isNotEmpty ? chatProv.totalUnreadCount : 0;
    final chatBadgeFromNotifs = notifProv.chatUnread;
    final chatUnread = chatBadgeFromChats > chatBadgeFromNotifs
        ? chatBadgeFromChats
        : chatBadgeFromNotifs;

    final bookingNotifCount = notifProv.bookingUnread;
    final pendingBookingCount = bp.pendingCount;
    final bookingBadge = bookingNotifCount > 0
        ? bookingNotifCount
        : pendingBookingCount > 0
            ? pendingBookingCount
            : 0;

    final items = [
      _CNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: l10n.home),
      _CNavItem(
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today_rounded,
          label: l10n.bookings,
          badge: bookingBadge,
          badgeColor: bookingNotifCount > 0
              ? AppColors.secondary
              : AppColors.error),
      _CNavItem(
          icon: Icons.video_library_outlined,
          activeIcon: Icons.video_library_rounded,
          label: 'Reels'),
      _CNavItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: l10n.chats,
          badge: chatUnread),
      _CNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profile),
    ];

    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(10, 0, 10, bottom + 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              items.length,
              (i) => _CNavTab(
                item: items[i],
                isActive: _idx == i,
                controller: _iconControllers[i],
                onTap: () => _onTabTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CNavItem {
  final IconData icon, activeIcon;
  final String label;
  final int badge;
  final Color badgeColor;

  const _CNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
    this.badgeColor = AppColors.error,
  });
}

class _CNavTab extends StatelessWidget {
  final _CNavItem item;
  final bool isActive;
  final AnimationController controller;
  final VoidCallback onTap;

  const _CNavTab({
    required this.item,
    required this.isActive,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => ScaleTransition(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: isActive
                ? BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.grey400,
                      size: 22,
                    ),
                    if (item.badge > 0)
                      Positioned(
                        top: -5,
                        right: -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: item.badgeColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white, width: 1.2),
                          ),
                          child: Center(
                            child: Text(
                              item.badge > 99 ? '99+' : '${item.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.grey400,
                  ),
                  child: Text(item.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
