import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';

typedef TabSwitcher = void Function(int tabIndex);

class AdminDashboardScreen extends StatefulWidget {
  final TabSwitcher? onSwitchTab;
  const AdminDashboardScreen({super.key, this.onSwitchTab});
  @override
  State<AdminDashboardScreen> createState() => _State();
}

class _State extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _goTab(int i) => widget.onSwitchTab?.call(i);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reelProv = context.watch<ReelProvider>();
    final name = auth.userModel?.fullName.split(' ').first ?? 'Admin';
    final pendingReels = reelProv.pendingReels.length;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, topPad + 12, 12, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1565C0),
                      Color(0xFF1E88E5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back 👋',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12)),
                        Text(name,
                            style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Pending reels badge
                  if (pendingReels > 0)
                    GestureDetector(
                      onTap: () => _goTab(1), // Reels tab
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('$pendingReels pending',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  // Logout button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => auth.logout(),
                    tooltip: 'Sign Out',
                  ),
                ]),
              ),
            ),

            // ── Pending Reels Alert ──────────────────────────────────────
            if (pendingReels > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _AlertBanner(
                    icon: Icons.videocam_rounded,
                    color: Colors.orange,
                    title: '$pendingReels Reel${pendingReels > 1 ? 's' : ''} Awaiting Review',
                    subtitle: 'Tap to review and approve or reject.',
                    onTap: () => _goTab(1),
                  ),
                ),
              ),

            SliverToBoxAdapter(child: _LiveStats(anim: _anim)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions',
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        _QA(
                          pendingReels > 0
                              ? 'Reels ($pendingReels)'
                              : 'Reels',
                          Icons.videocam_rounded,
                          const Color(0xFFE91E63),
                          () => _goTab(1),
                          badge: pendingReels > 0 ? pendingReels : null,
                        ),
                        _QA('Payments', Icons.payments_rounded,
                            const Color(0xFF1565C0), () => _goTab(2)),
                        _QA('Users', Icons.people_rounded,
                            const Color(0xFF00838F), () => _goTab(3)),
                        _QA('Categories', Icons.category_rounded,
                            const Color(0xFF6A1B9A), () => _goTab(4)),
                        _QA('Reports', Icons.flag_rounded,
                            const Color(0xFFC62828), () => _goTab(5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alert Banner ─────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AlertBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          color: color.withOpacity(0.75), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Live Stats ────────────────────────────────────────────────────────────────

class _LiveStats extends StatelessWidget {
  final AnimationController anim;
  const _LiveStats({required this.anim});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Stats>(
      future: _loadStats(),
      builder: (_, snap) {
        final s = snap.data ?? const _Stats();
        final cards = [
          _SC(
              'Total Users',
              '${s.totalUsers}',
              Icons.people_rounded,
              const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
              '${s.clients} clients'),
          _SC(
              'Fundis',
              '${s.fundis}',
              Icons.handyman_rounded,
              const LinearGradient(
                  colors: [Color(0xFF00838F), Color(0xFF26C6DA)]),
              'registered'),
          _SC(
              'Bookings',
              '${s.totalBookings}',
              Icons.calendar_month_rounded,
              const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
              '${s.pending} pending'),
          _SC(
              'Active Jobs',
              '${s.active}',
              Icons.work_rounded,
              const LinearGradient(
                  colors: [Color(0xFFF57F17), Color(0xFFFFCA28)]),
              '${s.completed} done'),
          _SC(
              'Total Reels',
              '${s.totalReels}',
              Icons.videocam_rounded,
              const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFAD1457)]),
              '${s.pendingReels} pending'),
          _SC(
              'Completed',
              '${s.completed}',
              Icons.check_circle_rounded,
              const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)]),
              s.totalBookings > 0
                  ? '${s.completed * 100 ~/ s.totalBookings}% rate'
                  : '0% rate'),
          _SC(
              'Approved Reels',
              '${s.approvedReels}',
              Icons.check_circle_outline_rounded,
              const LinearGradient(
                  colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
              '${s.totalReels} total'),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Overview',
                  style: AppTextStyles.titleMedium
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (ctx, cx) {
                const gap = 12.0;
                final w = (cx.maxWidth - gap) / 2;
                final h = (w * 0.72).clamp(95.0, 135.0);
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: cards
                      .map((c) => SizedBox(width: w, height: h, child: c))
                      .toList(),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<_Stats> _loadStats() async {
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db
            .collection('users')
            .where('role', isEqualTo: 'client')
            .count()
            .get(),
        db
            .collection('users')
            .where('role', isEqualTo: 'fundi')
            .count()
            .get(),
        db.collection('bookings').count().get(),
        db
            .collection('bookings')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        db
            .collection('bookings')
            .where('status', isEqualTo: 'in_progress')
            .count()
            .get(),
        db
            .collection('bookings')
            .where('status', isEqualTo: 'completed')
            .count()
            .get(),
        db.collection('reels').count().get(),
        db
            .collection('reels')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        db
            .collection('reels')
            .where('status', isEqualTo: 'approved')
            .count()
            .get(),
      ]);
      return _Stats(
        clients: results[0].count ?? 0,
        fundis: results[1].count ?? 0,
        totalBookings: results[2].count ?? 0,
        pending: results[3].count ?? 0,
        active: results[4].count ?? 0,
        completed: results[5].count ?? 0,
        totalReels: results[6].count ?? 0,
        pendingReels: results[7].count ?? 0,
        approvedReels: results[8].count ?? 0,
      );
    } catch (_) {
      return const _Stats();
    }
  }
}

class _Stats {
  final int clients, fundis, totalBookings, pending, active, completed,
      totalReels, pendingReels, approvedReels;
  const _Stats({
    this.clients = 0,
    this.fundis = 0,
    this.totalBookings = 0,
    this.pending = 0,
    this.active = 0,
    this.completed = 0,
    this.totalReels = 0,
    this.pendingReels = 0,
    this.approvedReels = 0,
  });
  int get totalUsers => clients + fundis;
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _SC extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Gradient gradient;

  const _SC(this.label, this.value, this.icon, this.gradient, this.sub);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.0)),
                Text(sub,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10)),
              ],
            ),
          ],
        ),
      );
}

// ── Quick Action ──────────────────────────────────────────────────────────────

class _QA extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const _QA(this.label, this.icon, this.color, this.onTap, {this.badge});

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.titleSmall.copyWith(
                        color: color, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      );
}
