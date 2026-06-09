import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/reel_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/fundi_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/notification_provider.dart';
import '../shared/chat_list_screen.dart';
import '../shared/reels_screen.dart';
import 'fundi_dashboard_screen.dart';
import 'fundi_jobs_screen.dart';
import 'fundi_profile_screen.dart';

/// FundiMainShell — 5 tabs (Boost/Promotion fully removed)
/// Dashboard | Jobs | Discover | Chats | Profile
class FundiMainShell extends StatefulWidget {
  const FundiMainShell({super.key});

  @override
  State<FundiMainShell> createState() => _FundiMainShellState();
}

class _FundiMainShellState extends State<FundiMainShell>
    with TickerProviderStateMixin {
  int _idx = 0;
  late final List<AnimationController> _iconCtrl;

  static const int _tabCount = 5;

  @override
  void initState() {
    super.initState();
    _iconCtrl = List.generate(
      _tabCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      ),
    );
    _iconCtrl[0].forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  @override
  void dispose() {
    for (final c in _iconCtrl) c.dispose();
    super.dispose();
  }

  void _subscribe() {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null || uid.isEmpty) return;
    context.read<FundiProvider>().subscribeWallet(uid);
    context.read<ChatProvider>().subscribeAllChats(uid, false);
    context.read<BookingProvider>().subscribeFundiBookings(uid);
    context.read<NotificationProvider>().subscribe(uid);
  }

  void _onTab(int i) {
    if (_idx == i) return;
    const reelsIdx = 2;  // Dashboard|Jobs|Discover|Chats|Profile
    if (_idx == reelsIdx && i != reelsIdx) {
      context.read<ReelProvider>().setReelsTabActive(false);
    } else if (i == reelsIdx && _idx != reelsIdx) {
      context.read<ReelProvider>().setReelsTabActive(true);
    }
    HapticFeedback.selectionClick();
    _iconCtrl[_idx].reverse();
    _iconCtrl[i].forward();
    setState(() => _idx = i);
  }

  // Index 0=Dashboard  1=Jobs  2=Discover  3=Chats  4=Profile
  static const List<Widget> _screens = [
    FundiDashboardScreen(),
    FundiJobsScreen(),
    ReelsScreen(),          // Discover/Showcase — no monetisation
    ChatListScreen(),
    FundiProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final myId      = auth.userModel?.uid ?? '';
    final l10n      = AppL10n.of(context);
    final bp        = context.watch<BookingProvider>();
    final chatProv  = context.watch<ChatProvider>();
    final notifProv = context.watch<NotificationProvider>();

    final chatUnread = myId.isNotEmpty
        ? (chatProv.totalUnreadCount > notifProv.chatUnread
            ? chatProv.totalUnreadCount
            : notifProv.chatUnread)
        : 0;

    final jobsBadge = notifProv.bookingUnread > 0
        ? notifProv.bookingUnread
        : bp.pendingCount > 0
            ? bp.pendingCount
            : 0;

    final items = [
      _FNavItem(
        icon:       Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label:      l10n.dashboard,
      ),
      _FNavItem(
        icon:       Icons.work_outline,
        activeIcon: Icons.work_rounded,
        label:      l10n.jobs,
        badge:      jobsBadge,
        badgeColor: notifProv.bookingUnread > 0
            ? AppColors.secondary
            : AppColors.error,
      ),
      _FNavItem(
        icon:       Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label:      l10n.sw ? 'Gundua' : 'Discover',
      ),
      _FNavItem(
        icon:       Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label:      l10n.chats,
        badge:      chatUnread,
      ),
      _FNavItem(
        icon:       Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label:      l10n.profile,
      ),
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
              color:  AppColors.primary.withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color:  AppColors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              items.length,
              (i) => _FNavTab(
                item:       items[i],
                isActive:   _idx == i,
                controller: _iconCtrl[i],
                onTap:      () => _onTab(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item data ─────────────────────────────────────────────────────────────

class _FNavItem {
  final IconData icon, activeIcon;
  final String label;
  final int badge;
  final bool dotOnly;
  final Color badgeColor;

  const _FNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge      = 0,
    this.dotOnly    = false,
    this.badgeColor = AppColors.error,
  });
}

// ── Nav tab widget ────────────────────────────────────────────────────────────

class _FNavTab extends StatelessWidget {
  final _FNavItem item;
  final bool isActive;
  final AnimationController controller;
  final VoidCallback onTap;

  const _FNavTab({
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
      onTap:     onTap,
      behavior:  HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: controller,
        builder:   (_, __) => ScaleTransition(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: isActive
                ? BoxDecoration(
                    color:        AppColors.primary.withOpacity(0.1),
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
                      color: isActive ? AppColors.primary : AppColors.grey400,
                      size: 22,
                    ),
                    if (item.badge > 0)
                      Positioned(
                        top:   item.dotOnly ? -3 : -5,
                        right: item.dotOnly ? -3 : -7,
                        child: item.dotOnly
                            ? Container(
                                width: 9, height: 9,
                                decoration: BoxDecoration(
                                  color:  item.badgeColor,
                                  shape:  BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.2),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                decoration: BoxDecoration(
                                  color:        item.badgeColor,
                                  borderRadius: BorderRadius.circular(999),
                                  border:       Border.all(
                                      color: Colors.white, width: 1.2),
                                ),
                                child: Center(
                                  child: Text(
                                    item.badge > 99 ? '99+' : '${item.badge}',
                                    style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   8,
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
                    fontSize:   9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color:      isActive ? AppColors.primary : AppColors.grey400,
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
