import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/reel_provider.dart';
import '../../providers/review_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_notif_bell.dart';
import '../../widgets/common/app_rating_bar.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_loader.dart';

class FundiProfileScreen extends StatefulWidget {
  const FundiProfileScreen({super.key});

  @override
  State<FundiProfileScreen> createState() => _FundiProfileScreenState();
}

class _FundiProfileScreenState extends State<FundiProfileScreen>
    with SingleTickerProviderStateMixin {
  List<String> _portfolioUrls = [];
  bool _portfolioLoaded = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null && uid.isNotEmpty) {
        context.read<ReviewProvider>().subscribeReviews(uid);
        context.read<ReelProvider>().subscribeFundiReels(uid);
        _loadPortfolio(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deletePortfolioImage(String uid, String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete Portfolio Image?'),
        content: const Text(
            'Are you sure you want to delete this portfolio image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child:     const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Remove instantly from local state
    setState(() => _portfolioUrls.remove(url));
    // Update Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'portfolioImages': FieldValue.arrayRemove([url])});
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() => _portfolioUrls.insert(0, url));
        AppUtils.showSnackBar(context, 'Failed to delete image.', isError: true);
      }
    }
  }

  Future<void> _loadPortfolio(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (mounted && data != null && data['portfolioImages'] is List) {
        setState(() {
          _portfolioUrls = List<String>.from(data['portfolioImages'] as List);
          _portfolioLoaded = true;
        });
      } else {
        setState(() => _portfolioLoaded = true);
      }
    } catch (_) {
      setState(() => _portfolioLoaded = true);
    }
  }

  // FIX: Read jobsDone directly from user doc.
  // clientConfirmCompletion() atomically increments it — updates instantly.
  Stream<int> _completedJobsStream(String fundiId) {
    if (fundiId.trim().isEmpty) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(fundiId)
        .snapshots()
        .map((snap) {
          final data = snap.data() ?? {};
          return (data['jobsDone'] as num?)?.toInt() ??
              (data['completedJobsCount'] as num?)?.toInt() ?? 0;
        });
  }

  double _averageRating(List<dynamic> reviews) {
    if (reviews.isEmpty) return 0;
    double total = 0;
    int valid = 0;
    for (final r in reviews) {
      try {
        total += (r.rating as num).toDouble();
        valid++;
      } catch (_) {}
    }
    return valid == 0 ? 0 : total / valid;
  }

  String _ratingLabel(double rating) =>
      rating <= 0 ? '—' : rating.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final auth = context.watch<AuthProvider>();
    final revProv = context.watch<ReviewProvider>();
    final reelProv = context.watch<ReelProvider>();
    final user = auth.userModel;
    final uid = user?.uid ?? '';
    final rating = _averageRating(revProv.reviews);
    final fundiReels = reelProv.fundiReels;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Hero SliverAppBar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.primary,
            automaticallyImplyLeading: false,
            actions: [
              if (uid.isNotEmpty) const AppNotifBell(),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => auth.logout(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(top: -30, right: -20,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06)))),
                  Positioned(bottom: 40, left: -20,
                    child: Container(width: 90, height: 90,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05)))),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar + edit
                          GestureDetector(
                            onTap: () => context.push('/edit-profile'),
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                                  ),
                                  child: AppAvatar(
                                    imageUrl: user?.profileImageUrl,
                                    name: user?.fullName ?? '',
                                    size: 80,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                        color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.edit_rounded,
                                        size: 12, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user?.fullName ?? '',
                            style: AppTextStyles.headlineSmall.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          // Trust badges row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppBadge(type: BadgeType.verified),
                              const SizedBox(width: 6),
                              if (rating >= 4.5)
                                _SmallBadge(Icons.workspace_premium_rounded,
                                    'Top Rated', const Color(0xFFFFD700)),
                              if (revProv.reviews.length >= 10)
                                const SizedBox(width: 6),
                              if (revProv.reviews.length >= 10)
                                _SmallBadge(Icons.thumb_up_rounded,
                                    'Trusted', AppColors.success),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                    const Tab(text: 'Profile'),
                    Tab(text: 'Portfolio (${_portfolioUrls.length})'),
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
            // ── Tab 1: Profile ───────────────────────────────────────────
            _ProfileTab(
              uid: uid,
              user: user,
              rating: rating,
              reviews: revProv.reviews,
              completedJobsStream: uid.isNotEmpty
                  ? _completedJobsStream(uid)
                  : Stream.value(0),
              ratingLabel: _ratingLabel(rating),
            ),

            // ── Tab 2: Portfolio ─────────────────────────────────────────
            _PortfolioTab(
              portfolioUrls: _portfolioUrls,
              isLoaded: _portfolioLoaded,
              ownerUid: uid,
              onDelete: (url) => _deletePortfolioImage(uid, url),
            ),

            // ── Tab 3: Reels ─────────────────────────────────────────────
            _ReelsTab(
              reels: fundiReels,
              uid: uid,
              myId: context.read<AuthProvider>().userModel?.uid ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final String uid;
  final dynamic user;
  final double rating;
  final List<dynamic> reviews;
  final Stream<int> completedJobsStream;
  final String ratingLabel;

  const _ProfileTab({
    required this.uid,
    required this.user,
    required this.rating,
    required this.reviews,
    required this.completedJobsStream,
    required this.ratingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
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
                  _StatItem(
                    value: '${reviews.length}',
                    label: 'Reviews',
                    icon: Icons.reviews_outlined,
                    color: AppColors.primary,
                  ),
                  Container(width: 1, height: 44, color: AppColors.border),
                  _StatItem(
                    value: '${snap.data ?? 0}',
                    label: 'Jobs Done',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                  ),
                  Container(width: 1, height: 44, color: AppColors.border),
                  _StatItem(
                    value: ratingLabel,
                    label: 'Rating',
                    icon: Icons.star_rounded,
                    color: const Color(0xFFFFD700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bio/About
          if ((user?.bio ?? '').trim().isNotEmpty) ...[
            _SectionHeader(Icons.person_rounded, 'About Me'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(user!.bio.trim(), style: AppTextStyles.bodyMedium),
            ),
            const SizedBox(height: 20),
          ],

          // Details
          _SectionHeader(Icons.info_outline_rounded, 'Details'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _DetailRow(Icons.work_outline_rounded, 'Category',
                    user?.category ?? '—'),
                const Divider(height: 20),
                _DetailRow(Icons.timer_outlined, 'Experience',
                    (user?.experience ?? '').isEmpty ? 'Not set' : user!.experience),
                const Divider(height: 20),
                _DetailRow(Icons.location_on_outlined, 'Location',
                    [user?.area, user?.district, user?.region]
                        .where((s) => s != null && s.trim().isNotEmpty)
                        .join(', ')
                        .ifEmpty('Not set')),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Trust section
          _SectionHeader(Icons.shield_rounded, 'Trust & Safety'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verified Account',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('Your profile is verified and visible to clients.',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.green.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.upload_rounded,
                  label: 'Upload Reel',
                  color: AppColors.primary,
                  onTap: () => context.push('/fundi/upload-reel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.edit_rounded,
                  label: 'Edit Profile',
                  color: AppColors.secondary,
                  onTap: () => context.push('/edit-profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.share_rounded,
                  label: 'Share Profile',
                  color: const Color(0xFF7B1FA2),
                  onTap: () => Share.share(
                      'Check out my FundiHub profile! I\'m ${user?.fullName ?? 'a skilled fundi'}. Book me for quality work.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Reviews header
          _SectionHeader(Icons.reviews_outlined, 'Recent Reviews'),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_outline_rounded,
                      color: AppColors.grey400, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No reviews yet. Complete jobs to receive ratings!',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            ...reviews.take(5).map((r) => _ReviewCard(r)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Portfolio Tab ─────────────────────────────────────────────────────────────

class _PortfolioTab extends StatelessWidget {
  final List<String> portfolioUrls;
  final bool isLoaded;
  final String ownerUid;
  final ValueChanged<String>? onDelete;

  const _PortfolioTab({
    required this.portfolioUrls,
    required this.isLoaded,
    required this.ownerUid,
    this.onDelete,
  });

  void _openViewer(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PortfolioViewer(urls: portfolioUrls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: 9,
        itemBuilder: (_, __) => AppShimmer(
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
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
            const Text('No Portfolio Photos Yet',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Add photos of your work in Edit Profile',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => context.push('/edit-profile'),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: const Text('Add Portfolio Photos'),
            ),
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
        onTap: () => _openViewer(context, i),
        child: Hero(
          tag: 'portfolio_$i',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  portfolioUrls[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, prog) {
                    if (prog == null) return child;
                    return AppShimmer(
                        child: Container(color: Colors.white));
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.grey200,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.grey400),
                  ),
                ),
                // Delete button — only when onDelete callback provided
                if (onDelete != null)
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => onDelete!(portfolioUrls[i]),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_rounded,
                            size: 14, color: Colors.white),
                      ),
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

// ── Reels Tab ─────────────────────────────────────────────────────────────────

class _ReelsTab extends StatelessWidget {
  final List<dynamic> reels;
  final String uid;
  final String myId;  // current user uid — enables owner delete button

  const _ReelsTab({
    required this.reels,
    required this.uid,
    this.myId = '',
  });

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
            const Text('No Work Reels Yet',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Upload videos of your work to attract more clients',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/fundi/upload-reel'),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload First Reel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8,
          childAspectRatio: 0.75),
      itemCount: reels.length,
      itemBuilder: (context, i) {
        final reel = reels[i];
        return GestureDetector(
          onTap: () {
            // Pass the already-loaded reels list directly so the viewer
            // shows only this fundi's reels starting at the tapped card.
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
                // Thumbnail
                reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty
                    ? Image.network(reel.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _ReelPlaceholder(reel.category))
                    : _ReelPlaceholder(reel.category),
                // Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                ),
                // Delete button — owner only, top-left corner
                if (myId.isNotEmpty && reel.fundiId == myId)
                  Positioned(
                    top: 6, left: 6,
                    child: GestureDetector(
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Reel?'),
                            content: const Text(
                                'This reel will be removed permanently.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          context
                              .read<ReelProvider>()
                              .softDeleteReel(reel.reelId, myId);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                // Status badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: reel.status == 'approved'
                          ? Colors.green
                          : reel.status == 'rejected'
                              ? Colors.red
                              : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reel.status == 'approved'
                          ? '✓ Live'
                          : reel.status == 'rejected'
                              ? '✗ Rejected'
                              : '⏳ Pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                // Caption
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.play_circle_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text('${reel.viewsCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.favorite_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 3),
                          Text('${reel.likesCount}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                      if (reel.caption.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          reel.caption,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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

class _ReelPlaceholder extends StatelessWidget {
  final String category;
  const _ReelPlaceholder(this.category);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withOpacity(0.15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_rounded,
              size: 40, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(category,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
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
            tag: 'portfolio_$i',
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

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SmallBadge(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: AppTextStyles.titleMedium
                .copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.headlineSmall
                    .copyWith(fontWeight: FontWeight.w800),
                maxLines: 1),
            Text(label,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary, fontSize: 11)),
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final dynamic r;
  const _ReviewCard(this.r);

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  name: r.clientName ?? '',
                  imageUrl: r.clientImageUrl,
                  size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.clientName ?? '',
                        style: AppTextStyles.titleSmall),
                    AppRatingBar(rating: r.rating, showCount: false),
                  ],
                ),
              ),
              Text(AppUtils.formatRelativeTime(r.createdAt),
                  style: AppTextStyles.caption),
            ],
          ),
          if ((r.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.comment, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

extension _StringX on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
