import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/fundi_model.dart';
import '../../models/reel_model.dart';
import '../../models/review_model.dart';
import '../../providers/lang_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_rating_bar.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_loader.dart';

class FundiDetailsScreen extends StatefulWidget {
  final FundiModel fundi;

  const FundiDetailsScreen({super.key, required this.fundi});

  @override
  State<FundiDetailsScreen> createState() => _FundiDetailsScreenState();
}

class _FundiDetailsScreenState extends State<FundiDetailsScreen>
    with SingleTickerProviderStateMixin {
  FundiModel get fundi => widget.fundi;

  List<String> _portfolioUrls = [];
  bool _portfolioLoaded = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPortfolio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReelProvider>().subscribeFundiReels(fundi.uid);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fundi.uid)
          .get();
      final data = doc.data();
      if (data != null && data['portfolioImages'] is List) {
        setState(() {
          _portfolioUrls = List<String>.from(data['portfolioImages'] as List)
              .where((String url) => url.trim().isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _portfolioLoaded = true);
  }

  // FIX: Same single-doc user read - keeps both views in sync.
  Stream<int> _completedJobsStream() {
    final fundiId = fundi.uid.trim();
    if (fundiId.isEmpty) return Stream<int>.value(0);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(fundiId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return 0;
          final d = snap.data() ?? {};
          final a = (d['jobsDone'] as num?)?.toInt() ?? 0;
          final b = (d['completedJobsCount'] as num?)?.toInt() ?? 0;
          return a > b ? a : b;
        }).handleError((_) => 0);
  }

  Stream<List<ReviewModel>> _reviewsStream() {
    final fundiId = fundi.uid.trim();
    if (fundiId.isEmpty) return Stream<List<ReviewModel>>.value(const []);
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('fundiId', isEqualTo: fundiId)
        .snapshots()
        .map((snap) {
          final reviews = snap.docs
              .map((doc) => ReviewModel.fromMap(doc.data()))
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  double _averageRating(List<ReviewModel> reviews) {
    if (reviews.isEmpty) return fundi.rating;
    final total =
        reviews.fold<double>(0, (double sum, ReviewModel r) => sum + r.rating);
    return total / reviews.length;
  }

  String _safeLocation() {
    final parts = <String>[
      if (fundi.area.trim().isNotEmpty) fundi.area.trim(),
      if (fundi.district.trim().isNotEmpty) fundi.district.trim(),
      if (fundi.region.trim().isNotEmpty) fundi.region.trim(),
    ];
    return parts.isEmpty ? 'Location not provided' : parts.join(', ');
  }

  void _openPortfolio(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PortfolioViewer(
          urls: _portfolioUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final reelProv = context.watch<ReelProvider>();
    final fundiReels = reelProv.fundiReels
        .where((r) => r.status == 'approved')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Hero AppBar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_outlined,
                      color: Colors.white, size: 20),
                ),
                onPressed: () => context.push(
                  '/report',
                  extra: {
                    'userId': fundi.uid,
                    'userName': fundi.fullName,
                    'bookingId': null,
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: fundi.isPromoted
                      ? LinearGradient(
                          colors: [
                            AppColors.promoted.withOpacity(0.8),
                            AppColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF0D47A1),
                            Color(0xFF1565C0),
                            Color(0xFF1E88E5)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppTheme.spaceXL),
                      // Avatar with verified ring
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.7), width: 2),
                        ),
                        child: AppAvatar(
                          imageUrl: fundi.profileImageUrl,
                          name: fundi.fullName,
                          size: 80,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),
                      Text(
                        fundi.fullName,
                        style: AppTextStyles.headlineMedium
                            .copyWith(color: AppColors.white),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      // Badges row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppBadge(type: BadgeType.verified),
                          if (fundi.isPremium) ...[
                            const SizedBox(width: 6),
                            const AppBadge(type: BadgeType.premium),
                          ],
                          if (fundi.isPromoted) ...[
                            const SizedBox(width: 6),
                            const AppBadge(type: BadgeType.promoted),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tab bar pinned below collapsed header
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: [
                    const Tab(text: 'About'),
                    Tab(text: 'Workdone (${_portfolioUrls.length})'),
                    Tab(text: 'Reels (${fundiReels.length})'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── About Tab ───────────────────────────────────────────────
            _AboutTab(
              fundi: fundi,
              l10n: l10n,
              completedJobsStream: _completedJobsStream(),
              reviewsStream: _reviewsStream(),
              averageRating: _averageRating,
              safeLocation: _safeLocation(),
            ),

            // ── Portfolio Tab ────────────────────────────────────────────
            _PortfolioTab(
              portfolioUrls: _portfolioUrls,
              isLoaded: _portfolioLoaded,
              onTap: _openPortfolio,
            ),

            // ── Reels Tab ─────────────────────────────────────────────────
            _ReelsTab(
              reels: fundiReels,
              fundiName: fundi.fullName,
            ),
          ],
        ),
      ),

      // ── Sticky Book CTA ──────────────────────────────────────────────
      // Only clients can book a fundi. Fundis and admins see nothing.
      bottomNavigationBar: Builder(builder: (context) {
        final auth = context.watch<AuthProvider>();
        // Fundi users may browse profiles but cannot book.
        // Admins have no booking intent either.
        if (auth.isFundi || auth.isAdmin) return const SizedBox.shrink();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppButton(
              label: 'Book ${fundi.fullName.split(' ').first}',
              leadingIcon: Icons.calendar_today_rounded,
              onPressed: () {
                // Guest browsing — require login to book
                if (auth.isGuest || !auth.isAuthenticated) {
                  _showGuestBookPrompt(context);
                  return;
                }
                context.push('/booking/create', extra: fundi);
              },
            ),
          ),
        );
      }),
    );
  }
}

// ── About Tab ─────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final FundiModel fundi;
  final AppL10n l10n;
  final Stream<int> completedJobsStream;
  final Stream<List<ReviewModel>> reviewsStream;
  final double Function(List<ReviewModel>) averageRating;
  final String safeLocation;

  const _AboutTab({
    required this.fundi,
    required this.l10n,
    required this.completedJobsStream,
    required this.reviewsStream,
    required this.averageRating,
    required this.safeLocation,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<List<ReviewModel>>(
        stream: reviewsStream,
        initialData: const [],
        builder: (context, reviewSnap) {
          final reviews = reviewSnap.data ?? const [];
          final liveRating = averageRating(reviews);
          final liveReviewCount =
              reviews.isNotEmpty ? reviews.length : fundi.reviewCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: StreamBuilder<int>(
                  stream: completedJobsStream,
                  initialData: 0,
                  builder: (context, snap) => Row(
                    children: [
                      _Stat(
                        value: liveRating == 0
                            ? '—'
                            : liveRating.toStringAsFixed(1),
                        label: l10n.ratingLabel,
                        icon: Icons.star_rounded,
                        color: AppColors.premium,
                      ),
                      Container(
                          width: 1, height: 44, color: AppColors.border),
                      _Stat(
                        value: '${snap.data ?? 0}',
                        label: l10n.jobsDoneLabel,
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                      ),
                      Container(
                          width: 1, height: 44, color: AppColors.border),
                      _Stat(
                        value: '$liveReviewCount',
                        label: l10n.reviewsLabel,
                        icon: Icons.reviews_outlined,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Trust banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.14)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.jobsDoneInfo,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Details section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(Icons.work_outline_rounded, 'Category',
                        fundi.displayCategory),
                    const Divider(height: 18),
                    _InfoRow(Icons.timer_outlined, 'Experience',
                        fundi.experience.trim().isEmpty
                            ? 'Not provided'
                            : fundi.experience),
                    const Divider(height: 18),
                    _InfoRow(Icons.location_on_outlined, 'Location',
                        safeLocation),
                    if (fundi.bio.isNotEmpty) ...[
                      const Divider(height: 18),
                      _InfoRow(Icons.info_outline_rounded, 'About',
                          fundi.bio),
                    ],
                  ],
                ),
              ),

              // Skills
              if (fundi.skills.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.star_outline_rounded,
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text('Skills',
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fundi.skills
                      .map((String s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Text(s,
                                style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.primary)),
                          ))
                      .toList(),
                ),
              ],

              // Reviews
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.reviews_outlined,
                        size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text('Reviews ($liveReviewCount)',
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),

              if (reviewSnap.connectionState == ConnectionState.waiting)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: AppLoaderCenter())
              else if (reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_outline_rounded,
                          color: AppColors.grey400, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No reviews yet. Be the first to review!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...reviews.take(10).map((ReviewModel r) => _ReviewCard(r)),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

// ── Portfolio Tab ─────────────────────────────────────────────────────────────

class _PortfolioTab extends StatelessWidget {
  final List<String> portfolioUrls;
  final bool isLoaded;
  final void Function(int) onTap;

  const _PortfolioTab({
    required this.portfolioUrls,
    required this.isLoaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: 9,
        itemBuilder: (_, __) => AppShimmer(
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    if (portfolioUrls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No Workdone Photos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
                'This fundi hasn\'t added workdone photos yet.\nAsk them to share examples in chat after booking.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: portfolioUrls.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => onTap(i),
        child: Hero(
          tag: 'fundi_portfolio_$i',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              portfolioUrls[i],
              fit: BoxFit.cover,
              loadingBuilder: (_, child, prog) {
                if (prog == null) return child;
                return AppShimmer(child: Container(color: Colors.white));
              },
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.grey200,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.grey400),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reels Tab ─────────────────────────────────────────────────────────────────

class _ReelsTab extends StatelessWidget {
  final List<ReelModel> reels;
  final String fundiName;

  const _ReelsTab({required this.reels, required this.fundiName});

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No Work Reels',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text('$fundiName hasn\'t uploaded any work videos yet.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75),
      itemCount: reels.length,
      itemBuilder: (context, i) {
        final reel = reels[i];
        return GestureDetector(
          onTap: () {
            context.push('/reels', extra: {
              'fundiReelsList': reels,
              'initialIndex':   i,
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty
                    ? Image.network(reel.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withOpacity(0.15),
                              child: const Icon(Icons.videocam_rounded,
                                  size: 40, color: AppColors.primary),
                            ))
                    : Container(
                        color: AppColors.primary.withOpacity(0.15),
                        child: const Icon(Icons.videocam_rounded,
                            size: 40, color: AppColors.primary),
                      ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.6), width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded,
                              color: Colors.white70, size: 12),
                          const SizedBox(width: 3),
                          Text('${reel.viewsCount}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                          const Spacer(),
                          const Icon(Icons.favorite_rounded,
                              color: Colors.pink, size: 12),
                          const SizedBox(width: 3),
                          Text('${reel.likesCount}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                      if (reel.caption.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(reel.caption,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Portfolio Viewer ──────────────────────────────────────────────────────────

class _PortfolioViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PortfolioViewer({required this.urls, required this.initialIndex});

  @override
  State<_PortfolioViewer> createState() => _PortfolioViewerState();
}

class _PortfolioViewerState extends State<_PortfolioViewer> {
  late int _index;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_index + 1} / ${widget.urls.length}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Hero(
            tag: 'fundi_portfolio_$i',
            child: Image.network(
              widget.urls[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white, size: 52),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.headlineSmall
                    .copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel r;
  const _ReviewCard(this.r);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                    name: r.clientName,
                    imageUrl: r.clientImageUrl,
                    size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.clientName, style: AppTextStyles.titleSmall),
                      AppRatingBar(rating: r.rating, showCount: false),
                    ],
                  ),
                ),
                Text(AppUtils.formatRelativeTime(r.createdAt),
                    style: AppTextStyles.caption),
              ],
            ),
            if (r.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.comment, style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      );
}

// ── Guest booking prompt ──────────────────────────────────────────────────────

void _showGuestBookPrompt(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today_rounded,
                size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create an account to continue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign up to book this fundi and access all FundiHub features.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                GoRouter.of(context).go('/register');
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Create Account',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              GoRouter.of(context).go('/login');
            },
            child: const Text('Sign In'),
          ),
        ]),
      ),
    ),
  );
}
