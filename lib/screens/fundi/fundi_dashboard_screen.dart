import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/fundi_provider.dart';
import '../../providers/lang_provider.dart';
import '../../widgets/cards/booking_card.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_notif_bell.dart';

class FundiDashboardScreen extends StatefulWidget {
  const FundiDashboardScreen({super.key});

  @override
  State<FundiDashboardScreen> createState() => _FundiDashboardScreenState();
}

class _FundiDashboardScreenState extends State<FundiDashboardScreen> {
  double _avgRating   = 0;
  int    _reviewCount = 0;
  bool   _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null || uid.isEmpty) return;
    // Subscribe fundiReels stream so _VideoStatsCard updates in realtime
    context.read<ReelProvider>().subscribeFundiReels(uid);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reviews')
          .where('fundiId', isEqualTo: uid)
          .get();
      if (!mounted) return;
      double total = 0;
      for (final doc in snap.docs) {
        total += ((doc.data()['rating'] as num?) ?? 0).toDouble();
      }
      setState(() {
        _reviewCount = snap.docs.length;
        _avgRating   = snap.docs.isEmpty ? 0 : total / snap.docs.length;
        _statsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  String _greeting(AppL10n l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.goodMorning;
    if (h < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fp   = context.watch<FundiProvider>();
    final bp   = context.watch<BookingProvider>();
    final user = auth.userModel;
    final l10n = AppL10n.of(context);
    final uid  = user?.uid ?? '';

    final bookings  = bp.bookings;
    final pending   = bookings.where((b) => b.isPending).toList();
    final active    = bookings.where((b) =>
        b.isActive ||
        b.status.toLowerCase() == AppConstants.bookingAgreementConfirmed ||
        b.status.toLowerCase() == AppConstants.bookingInProgress).toList();
    final completed = bookings.where((b) => b.isFinished).toList();
    final recentJobs = bookings.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          if (uid.isNotEmpty) bp.subscribeFundiBookings(uid);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [

            // ── Hero AppBar ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.primary,
              actions: [
                const AppNotifBell(),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.white),
                  onPressed: () => auth.logout(),
                  tooltip: 'Sign Out',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceXXL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppTheme.spaceLG),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.push('/fundi/profile'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.white.withOpacity(0.6),
                                      width: 2.5,
                                    ),
                                  ),
                                  child: AppAvatar(
                                    name:     user?.fullName ?? '',
                                    imageUrl: user?.profileImageUrl,
                                    size:     56,
                                    backgroundColor:
                                        AppColors.white.withOpacity(0.2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceMD),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _greeting(l10n),
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.white.withOpacity(0.75)),
                                    ),
                                    Text(
                                      user?.fullName ?? '',
                                      style: AppTextStyles.titleLarge.copyWith(
                                        color:      AppColors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    _StatusPill(
                                      icon:  Icons.circle,
                                      label: l10n.active,
                                      color: AppColors.success,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Stats grid ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceXXL, AppTheme.spaceXXL,
                    AppTheme.spaceXXL, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.overview,
                        style: AppTextStyles.titleLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.spaceMD),
                    Row(
                      children: [
                        _StatCard(
                          icon:  Icons.hourglass_top_rounded,
                          label: l10n.pending,
                          value: '${pending.length}',
                          color: AppColors.warning,
                          badge: pending.isNotEmpty ? pending.length : null,
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        _StatCard(
                          icon:  Icons.build_rounded,
                          label: l10n.active,
                          value: '${active.length}',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        _StatCard(
                          icon:  Icons.task_alt_rounded,
                          label: l10n.completed,
                          value: '${completed.length}',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    Row(
                      children: [
                        _StatCard(
                          icon:  Icons.star_rounded,
                          label: l10n.avgRating,
                          value: _avgRating <= 0
                              ? '—'
                              : _avgRating.toStringAsFixed(1),
                          color: AppColors.premium,
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        _StatCard(
                          icon:  Icons.reviews_rounded,
                          label: l10n.reviews,
                          value: '$_reviewCount',
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        _StatCard(
                          icon:  Icons.handshake_rounded,
                          label: l10n.sw ? 'Kazi Zote' : 'All Jobs',
                          value: '${bookings.length}',
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick actions (NO Boost) ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceXXL, AppTheme.spaceXXL,
                    AppTheme.spaceXXL, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.quickActions,
                        style: AppTextStyles.titleLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.spaceMD),
                    Row(
                      children: [
                        _ActionButton(
                          icon:  Icons.video_library_rounded,
                          label: l10n.sw ? 'Pakia Video' : 'Upload Reel',
                          color: const Color(0xFF7B1FA2),
                          onTap: () => context.push('/fundi/upload-reel'),
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        _ActionButton(
                          icon:  Icons.explore_rounded,
                          label: l10n.sw ? 'Gundua' : 'Discover',
                          color: AppColors.primary,
                          onTap: () {
                            // Switch to Discover tab (index 2) via parent
                            // Navigator pop-and-push is not needed — just navigate
                            context.push('/reels');
                          },
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        _ActionButton(
                          icon:  Icons.photo_library_rounded,
                          label: l10n.sw ? 'Picha za Kazi' : 'Work Photos',
                          color: const Color(0xFF00897B),
                          onTap: () async {
                            final result = await context
                                .push<String?>('/fundi/work-photos');
                            if (result == 'workPhotos' &&
                                context.mounted) {
                              // Navigate to profile Work Photos tab
                              context.push('/fundi/profile');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Video stats ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _VideoStatsCard(
                  fundiId: user?.uid ?? '',
                ),
              ),
            ),

            // ── Growth tip banner ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceXXL, AppTheme.spaceXXL,
                    AppTheme.spaceXXL, 0),
                child: _GrowthTipBanner(),
              ),
            ),

            // ── Recent jobs ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceXXL),
                child: Row(
                  children: [
                    Text(l10n.recentJobs,
                        style: AppTextStyles.titleLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (bookings.isNotEmpty)
                      TextButton(
                        onPressed: () {},
                        child: Text(l10n.viewAll),
                      ),
                  ],
                ),
              ),
            ),

            if (recentJobs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXXL),
                  child: AppEmptyState(
                    icon:     Icons.work_history_outlined,
                    title:    l10n.noJobsYet,
                    subtitle: l10n.sw
                        ? 'Maombi mapya ya kazi yataonekana hapa.\nHakikisha wasifu wako umekamilika.'
                        : 'New booking requests will appear here.\nMake sure your profile is complete.',
                    iconColor: AppColors.grey400,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceXXL),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => BookingCard(
                      booking:  recentJobs[i],
                      isClient: false,
                      onTap:    () => ctx.push(
                          '/booking/detail', extra: recentJobs[i].bookingId),
                    ),
                    childCount: recentJobs.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

// ── Growth Tip Banner ─────────────────────────────────────────────────────────

class _GrowthTipBanner extends StatelessWidget {
  final _tips = const [
    ('Upload work reels to attract 3× more clients',   Icons.video_library_rounded),
    ('Complete your profile for better visibility',    Icons.person_rounded),
    ('Respond quickly to bookings to rank higher',     Icons.bolt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().second % _tips.length];
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color:        AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(tip.$2, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Growth Tip',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
                Text(tip.$1,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _StatusPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        AppColors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.caption.copyWith(
                  color:      AppColors.white,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  final int?     badge;
  final bool     smallValue;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.badge      = null,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border:       Border.all(color: color.withOpacity(0.18), width: 1.5),
            boxShadow: [
              BoxShadow(
                color:     color.withOpacity(0.08),
                blurRadius: 10,
                offset:    const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  if (badge != null && badge! > 0) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color:        AppColors.error,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        '$badge',
                        style: AppTextStyles.caption.copyWith(
                          color:      AppColors.white,
                          fontSize:   9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                value,
                style: smallValue
                    ? AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color:      AppColors.textPrimary)
                    : AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color:      AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label,
                  style:   AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.12),
                  color.withOpacity(0.06),
                ],
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color:      color,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
}


// ── Video Stats Card ─────────────────────────────────────────────────────────

class _VideoStatsCard extends StatelessWidget {
  final String fundiId;
  const _VideoStatsCard({required this.fundiId});

  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<ReelProvider>();
    // Filter strictly by fundiId so stale cached reels from another
    // fundi's profile never pollute this fundi's own stats.
    final reels = prov.fundiReels
        .where((r) => r.fundiId == fundiId)
        .toList();

    final totalReels    = reels.length;
    if (totalReels == 0) return const SizedBox.shrink();

    final totalViews    = reels.fold<int>(0, (s, r) => s + r.viewsCount);
    final totalLikes    = reels.fold<int>(0, (s, r) => s + r.likesCount);
    final totalComments = reels.fold<int>(0, (s, r) => s + r.commentsCount);
    final totalSaves    = reels.fold<int>(0, (s, r) => s + r.savesCount);
    final approved      = reels.where((r) => r.isApproved).length;
    final pending       = reels.where((r) => r.isPending).length;
    // Top reel by views
    final topReel = reels.isNotEmpty
        ? reels.reduce((a, b) => a.viewsCount > b.viewsCount ? a : b)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border:       Border.all(color: AppColors.border),
        boxShadow:    AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color:        AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.video_library_rounded,
                  color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Video Stats',
                style: AppTextStyles.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$totalReels reel${totalReels == 1 ? '' : 's'}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _VStat(Icons.play_circle_outline_rounded,
                _fmt(totalViews),    'Views',    AppColors.primary),
            _VStat(Icons.favorite_border_rounded,
                _fmt(totalLikes),    'Likes',    Colors.pinkAccent),
            _VStat(Icons.chat_bubble_outline_rounded,
                _fmt(totalComments), 'Comments', AppColors.secondary),
            _VStat(Icons.bookmark_border_rounded,
                _fmt(totalSaves),    'Saves',    AppColors.secondary),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _VStat(Icons.check_circle_outline_rounded,
                '$approved/$totalReels', 'Approved', AppColors.success),
          ]),
          if (topReel != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('Top Reel',
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_fmt(topReel!.viewsCount)} views',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 4),
            Text(topReel!.caption.isNotEmpty
                ? topReel!.caption
                : 'Untitled Reel',
                style: AppTextStyles.bodySmall,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (pending > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        AppColors.warningSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.hourglass_top_rounded,
                    size: 12, color: AppColors.warning),
                const SizedBox(width: 5),
                Text('$pending video${pending == 1 ? '' : 's'} pending review',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _VStat extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;
  const _VStat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 3),
      Text(value,
          style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w800, color: color)),
      Text(label,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary)),
    ]),
  );
}
