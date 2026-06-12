import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_reels_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_users_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_deleted_accounts_screen.dart';

class AdminMainShell extends StatefulWidget {
  const AdminMainShell({super.key});
  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell>
    with TickerProviderStateMixin {
  int _idx = 0;
  late final List<AnimationController> _ctrl;

  static const _items = [
    _ANavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard',
        Color(0xFF1565C0)),
    _ANavItem(Icons.video_library_outlined, Icons.video_library_rounded,
        'Reels', Color(0xFF7B1FA2)),
    _ANavItem(Icons.payments_outlined, Icons.payments_rounded, 'Payments',
        Color(0xFF1565C0)),
    _ANavItem(Icons.people_outlined, Icons.people_rounded, 'Users',
        Color(0xFF00838F)),
    _ANavItem(Icons.category_outlined, Icons.category_rounded, 'Categories',
        Color(0xFF6A1B9A)),
    _ANavItem(Icons.flag_outlined, Icons.flag_rounded, 'Reports',
        Color(0xFFC62828)),
    _ANavItem(Icons.delete_outline_rounded, Icons.delete_rounded,
        'Deleted', Colors.brown),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = List.generate(
        _items.length,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 280)));
    _ctrl[0].forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReelProvider>().subscribePendingReels();
    });
  }

  @override
  void dispose() {
    for (final c in _ctrl) {
      c.dispose();
    }
    super.dispose();
  }

  void switchTab(int i) {
    if (i < 0 || i >= _items.length || _idx == i) return;
    HapticFeedback.selectionClick();
    _ctrl[_idx].reverse();
    _ctrl[i].forward();
    setState(() => _idx = i);
  }

  List<Widget> get _screens => [
        AdminDashboardScreen(onSwitchTab: switchTab),
        const AdminReelsScreen(),
        const AdminPaymentsScreen(),
        const AdminUsersScreen(),
        const AdminCategoriesScreen(),
        const AdminReportsScreen(),
        const AdminDeletedAccountsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reelProv = context.watch<ReelProvider>();
    final pendingReelCount = reelProv.pendingReels.length;

    if (auth.userModel != null && !auth.userModel!.isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Access Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You do not have admin privileges.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => auth.logout(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      );
    }

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
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _items.length,
              (i) => _ANavTab(
                item: _items[i],
                isActive: _idx == i,
                controller: _ctrl[i],
                badge: i == 1 ? pendingReelCount : 0,
                onTap: () => switchTab(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ANavItem {
  final IconData icon, activeIcon;
  final String label;
  final Color color;
  const _ANavItem(this.icon, this.activeIcon, this.label, this.color);
}

class _ANavTab extends StatelessWidget {
  final _ANavItem item;
  final bool isActive;
  final AnimationController controller;
  final int badge;
  final VoidCallback onTap;

  const _ANavTab({
    required this.item,
    required this.isActive,
    required this.controller,
    required this.badge,
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: isActive
                ? BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
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
                      color: isActive ? item.color : AppColors.grey400,
                      size: 22,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -5,
                        right: -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white, width: 1.2),
                          ),
                          child: Center(
                            child: Text(
                              badge > 99 ? '99+' : '$badge',
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
                    fontSize: 8,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? item.color : AppColors.grey400,
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
