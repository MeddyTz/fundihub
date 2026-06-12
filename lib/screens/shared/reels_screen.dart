import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/comment_model.dart';
import '../../models/reel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lang_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/common/app_avatar.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../widgets/common/app_shimmer.dart';

class ReelsScreen extends StatefulWidget {
  /// When set, shows only these reels (e.g. a specific fundi's reels
  /// opened from their profile). The global approved feed is NOT used.
  final List<ReelModel>? fundiReelsList;

  /// Index within [fundiReelsList] to open initially.
  final int initialIndex;

  const ReelsScreen({
    super.key,
    this.fundiReelsList,
    this.initialIndex = 0,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final PageController _pageController = PageController();
  int    _currentPage   = 0;
  bool   _subscribedMore = false;
  String? _selectedCategory;   // null = All

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ReelProvider>();
      prov.subscribeApprovedReels();
      // Prime the seen-reel set for personalised ordering.
      // Guests (uid empty) get random order via _prioritisedShuffle fallback.
      final uid = context.read<AuthProvider>().userModel?.uid ?? '';
      if (uid.isNotEmpty) prov.loadViewedReels(uid);
      // Jump to the tapped reel when opening from fundi profile
      if (widget.fundiReelsList != null && widget.initialIndex > 0) {
        _pageController.jumpToPage(widget.initialIndex);
      }
    });
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    final prov = context.read<ReelProvider>();
    final reels = prov.approvedReels;
    if (reels.isEmpty) return;
    // Load more when 3 from end
    if (_currentPage >= reels.length - 3 && !_subscribedMore) {
      _subscribedMore = true;
      prov.loadMoreReels().then((_) => _subscribedMore = false);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov      = context.watch<ReelProvider>();
    // If opened from fundi profile, use only that fundi's reels list.
    // Otherwise use the global approved feed with optional category filter.
    final allReels  = widget.fundiReelsList ?? prov.approvedReels;
    final reels     = (widget.fundiReelsList != null || _selectedCategory == null)
        ? allReels
        : allReels.where((r) => r.category == _selectedCategory).toList();
    // Pause reels when user switches to another tab
    final tabActive = prov.reelsTabActive;
    final auth      = context.watch<AuthProvider>();
    final myId      = auth.userModel?.uid ?? '';
    final isFundi   = auth.userModel?.role == 'fundi';

    // ── Empty state ──────────────────────────────────────────────────
    if (reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _EmptyReels(
          isFundi: isFundi,
          onUpload: () => context.push('/fundi/upload-reel'),
        ),
      );
    }

    // Retry screen
    if (prov.feedError && reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text('Could not load reels',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => prov.refreshApprovedReels(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        )),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Category filter chips (hidden when viewing one fundi's reels)
          if (widget.fundiReelsList == null)
            Positioned(
              top:   MediaQuery.of(context).padding.top + 4,
              left:  0,
              right: 0,
              child: _CategoryChips(
              allReels:   allReels,
              selected:   _selectedCategory,
              onSelected: (cat) => setState(() {
                _selectedCategory = cat;
                _currentPage = 0;
                _pageController.jumpToPage(0);
              }),
            ),
          ),

          // ── Full-screen pager ─────────────────────────────────
          PageView.builder(
            controller:    _pageController,
            scrollDirection: Axis.vertical,
            itemCount:     reels.length + (prov.loadingMore ? 1 : 0),
            onPageChanged: (i) {
              HapticFeedback.lightImpact();
              setState(() => _currentPage = i);
            },
            itemBuilder: (context, i) {
              if (i >= reels.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppLoader(size: 28, color: Colors.white54),
                  ),
                );
              }
              return _ReelPage(
                reel:      reels[i],
                isActive:  tabActive && (i == _currentPage || i == _currentPage + 1),
                myId:      myId,
                isFundi:   isFundi,
              );
            },
          ),

          // ── Top bar ────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: _TopBar(
                isFundi: isFundi,
                onUpload: () => context.push('/fundi/upload-reel'),
              ),
            ),
          ),

          // ── Page dots indicator ────────────────────────────────────
          Positioned(
            right: 6,
            top: MediaQuery.of(context).padding.top + 56,
            child: _PageDots(
                total: reels.length.clamp(0, 6),
                current: _currentPage.clamp(0, reels.length - 1)),
          ),
        ],
      ),
    );
  }
}

// ── Individual Reel Page ──────────────────────────────────────────────────────

class _ReelPage extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final String myId;
  final bool isFundi;

  const _ReelPage({
    required this.reel,
    required this.isActive,
    required this.myId,
    required this.isFundi,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _paused      = false;
  bool _viewCounted = false;

  late final AnimationController _likeAnim;

  @override
  void initState() {
    super.initState();
    _likeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.0,  // start at 0 = hidden
      upperBound: 1.0,
      value: 0.0,       // hidden until first tap
    );
    if (widget.isActive) _initPlayer();
  }

  @override
  void didUpdateWidget(_ReelPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _initPlayer();
    } else if (!widget.isActive && old.isActive) {
      _disposePlayer();
    } else if (widget.isActive && old.isActive) {
      // Tab visibility change — pause when leaving Reels tab
      final wasTab = context.read<ReelProvider>().reelsTabActive;
      if (!wasTab && _ctrl != null && _ctrl!.value.isPlaying) {
        _ctrl!.pause();
      } else if (wasTab && _ctrl != null && !_paused) {
        _ctrl!.play();
      }
    }
  }

  Future<void> _initPlayer() async {
    if (widget.reel.videoUrl.isEmpty) return;

    // Safety: never initialize or play a reel while the Reels tab/screen is not active.
    // This prevents video audio from continuing in the background after navigation.
    final provider = context.read<ReelProvider>();
    if (!widget.isActive || !provider.reelsTabActive) return;

    try {
      final ctrl = VideoPlayerController.networkUrl(
          Uri.parse(widget.reel.videoUrl));
      _ctrl = ctrl;
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }

      // Re-check after async initialization in case the user switched tabs/screens.
      final stillTabActive = context.read<ReelProvider>().reelsTabActive;
      if (!widget.isActive || !stillTabActive) {
        ctrl.pause();
        ctrl.dispose();
        if (identical(_ctrl, ctrl)) _ctrl = null;
        return;
      }

      ctrl.setLooping(true);
      ctrl.play();
      setState(() { _initialized = true; _paused = false; });

      // Count view + mark as seen for personalised ordering.
      if (!_viewCounted) {
        _viewCounted = true;
        final rp  = context.read<ReelProvider>();
        final uid = context.read<AuthProvider>().userModel?.uid ?? '';
        rp.incrementView(widget.reel.reelId);
        if (uid.isNotEmpty) {
          rp.markReelViewedRemote(uid, widget.reel.reelId);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  void _disposePlayer() {
    _ctrl?.pause();
    _ctrl?.dispose();
    _ctrl = null;
    if (mounted) setState(() { _initialized = false; _paused = false; });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _likeAnim.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl == null || !_initialized) return;
    if (_paused) {
      _ctrl!.play();
    } else {
      _ctrl!.pause();
    }
    setState(() => _paused = !_paused);
  }

  void _onDoubleTap() {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest) { _showGuestPrompt(context); return; }
    final prov = context.read<ReelProvider>();
    if (!prov.isLiked(widget.reel.reelId)) {
      prov.toggleLike(widget.reel.reelId);
    }
    // Animate heart: appear from 0 → 1, then disappear back to 0
    _likeAnim
        .animateTo(1.0, duration: const Duration(milliseconds: 200))
        .then((_) => _likeAnim.animateTo(
              0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            ));
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<ReelProvider>();
    final liked = prov.isLiked(widget.reel.reelId);
    final saved = prov.isSaved(widget.reel.reelId);

    return VisibilityDetector(
      key: Key('reel_\${widget.reel.reelId}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction >= 0.6;
        final tabOn   = context.read<ReelProvider>().reelsTabActive;
        if (visible && tabOn) {
          if (_ctrl != null && !_ctrl!.value.isPlaying && !_paused)
            _ctrl?.play();
          if (!_viewCounted) {
            _viewCounted = true;
            final rp2  = context.read<ReelProvider>();
            final uid2 = context.read<AuthProvider>().userModel?.uid ?? '';
            rp2.incrementView(widget.reel.reelId);
            if (uid2.isNotEmpty) {
              rp2.markReelViewedRemote(uid2, widget.reel.reelId);
            }
          }
        } else {
          if (_ctrl != null && _ctrl!.value.isPlaying) _ctrl?.pause();
        }
      },
      child: GestureDetector(
        onTap:        _togglePlay,
        onDoubleTap:  _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video / Thumbnail ────────────────────────────────────
          _initialized && _ctrl != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:  _ctrl!.value.size.width,
                    height: _ctrl!.value.size.height,
                    child:  VideoPlayer(_ctrl!),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl:   widget.reel.thumbnailUrl,
                  fit:        BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF111111)),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF111111),
                    child: const Center(
                      child: Icon(Icons.videocam_off_rounded,
                          color: Colors.white24, size: 48),
                    ),
                  ),
                ),

          // ── Gradient overlays ────────────────────────────────────
          // Top gradient
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                ),
              ),
            ),
          ),
          // Bottom gradient
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end:   Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Pause icon flash ─────────────────────────────────────
          if (_paused)
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pause_rounded,
                    color: Colors.white, size: 38),
              ),
            ),

          // ── Double-tap heart animation (only shows after a tap) ──
          AnimatedBuilder(
            animation: _likeAnim,
            builder: (_, __) {
              if (_likeAnim.value <= 0.01) return const SizedBox.shrink();
              return Center(
                child: Opacity(
                  opacity: _likeAnim.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + _likeAnim.value * 0.5,
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.pinkAccent, size: 100),
                  ),
                ),
              );
            },
          ),

          // ── Bottom: fundi info + caption ─────────────────────────
          Positioned(
            bottom: 90,
            left: 14,
            right: 72,
            child: _BottomInfo(reel: widget.reel),
          ),

          // ── Right: action buttons ────────────────────────────────
          Positioned(
            right: 10,
            bottom: 100,
            child: _ActionColumn(
              reel:    widget.reel,
              myId:    widget.myId,
              isFundi: widget.isFundi,
              liked:   liked,
              saved:   saved,
              likeAnim: _likeAnim,
            ),
          ),

          // ── Video progress bar ───────────────────────────────────
          if (_initialized && _ctrl != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: VideoProgressIndicator(
                _ctrl!,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor:  AppColors.primary,
                  bufferedColor: Colors.white.withOpacity(0.3),
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    ),
    );
  }
}

// ── Bottom Info ───────────────────────────────────────────────────────────────

class _BottomInfo extends StatelessWidget {
  final ReelModel reel;
  const _BottomInfo({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fundi row — tap to open that fundi's profile
        GestureDetector(
          onTap: () => context.push(
              '/client/fundi-by-id', extra: reel.fundiId),
          child: Row(
          children: [
            AppAvatar(
              imageUrl: reel.fundiProfileImage,
              name:     reel.fundiName,
              size:     36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reel.fundiName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          reel.category,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (reel.location.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white60, size: 10),
                        Expanded(
                          child: Text(
                            reel.location,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        if (reel.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ExpandableCaption(caption: reel.caption),
        ],
      ],
    );
  }
}

class _ExpandableCaption extends StatefulWidget {
  final String caption;
  const _ExpandableCaption({required this.caption});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Text(
        widget.caption,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.4,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
        maxLines: _expanded ? null : 2,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Action Column ─────────────────────────────────────────────────────────────

class _ActionColumn extends StatelessWidget {
  final ReelModel reel;
  final String myId;
  final bool isFundi;
  final bool liked;
  final bool saved;
  final AnimationController likeAnim;

  const _ActionColumn({
    required this.reel,
    required this.myId,
    required this.isFundi,
    required this.liked,
    required this.saved,
    required this.likeAnim,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.read<ReelProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like
        _ActionBtn(
          icon:       liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label:      '${reel.likesCount + (liked ? 1 : 0)}',
          color:      liked ? Colors.pinkAccent : Colors.white,
          onTap: () {
            HapticFeedback.lightImpact();
            if (context.read<AuthProvider>().isGuest) {
              _showGuestPrompt(context); return;
            }
            prov.toggleLike(reel.reelId);
            // Trigger heart animation
            likeAnim
                .animateTo(1.0, duration: const Duration(milliseconds: 200))
                .then((_) => likeAnim.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    ));
          },
        ),
        const SizedBox(height: 18),
        // Comments
        _ActionBtn(
          icon:  Icons.chat_bubble_outline_rounded,
          label: '${reel.commentsCount}',
          color: Colors.white,
          onTap: () => _showComments(context, reel),
        ),
        const SizedBox(height: 18),

        // Save
        _ActionBtn(
          icon:  saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: saved ? 'Saved' : 'Save',
          color: saved ? AppColors.secondary : Colors.white,
          onTap: () {
            HapticFeedback.lightImpact();
            if (myId.isEmpty) return;  // guests cannot save
            prov.toggleSaveWithStorage(reel.reelId, myId, !saved);
          },
        ),
        const SizedBox(height: 18),

        // Share
        _ActionBtn(
          icon:  Icons.share_rounded,
          label: 'Share',
          onTap: () {
            Share.share(
              'Check out ${reel.fundiName}\'s work on FundiHub! '
              '${reel.caption.length > 80 ? '${reel.caption.substring(0, 80)}...' : reel.caption}',
            );
          },
        ),
        const SizedBox(height: 18),

        // Book
        if (!isFundi)
          _ActionBtn(
            icon:  Icons.calendar_today_rounded,
            label: 'Book',
            color: const Color(0xFF4CAF50),
            onTap: () => context.push(
                '/client/fundi-by-id',
                extra: reel.fundiId),
          ),
        if (!isFundi) const SizedBox(height: 18),

        // View profile — pause video before leaving Reels
        _ActionBtn(
          icon:  Icons.person_rounded,
          label: 'Profile',
          onTap: () {
            context.read<ReelProvider>().setReelsTabActive(false);
            context
                .push('/client/fundi-by-id', extra: reel.fundiId)
                .then((_) {
              if (context.mounted) {
                context.read<ReelProvider>().setReelsTabActive(true);
              }
            });
          },
        ),
        const SizedBox(height: 18),

        // Delete own reel (fundi only)
        if (reel.fundiId == myId) ...[
          _ActionBtn(
            icon:  Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.white54,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Reel?'),
                  content: const Text(
                      'This reel will be removed from the public feed.\n'
                      'Admin may still review it.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                prov.softDeleteReel(reel.reelId, myId);
              }
            },
          ),
          const SizedBox(height: 18),
        ],

        // Report
        _ActionBtn(
          icon:  Icons.flag_outlined,
          label: 'Report',
          color: Colors.white54,
          onTap: () => _showReport(context, prov),
        ),
      ],
    );
  }

  void _showReport(BuildContext context, ReelProvider prov) {
    if (myId.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportSheet(
        onReport: (reason) async {
          await prov.reportReel(
              reelId: reel.reelId, reporterId: myId, reason: reason);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Report submitted. Thank you.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28,
                shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.w600,
                shadows:    const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
        ),
      );
}

// ── Report Sheet ──────────────────────────────────────────────────────────────

class _ReportSheet extends StatelessWidget {
  final void Function(String reason) onReport;
  const _ReportSheet({required this.onReport});

  static const _reasons = [
    'Inappropriate content',
    'Spam or misleading',
    'Fake work / Not their work',
    'Offensive or harmful',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Report this Reel',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ..._reasons.map((r) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.flag_outlined,
                      color: Colors.white60, size: 18),
                  title: Text(r,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                  onTap: () => onReport(r),
                  contentPadding: EdgeInsets.zero,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isFundi;
  final VoidCallback onUpload;
  const _TopBar({required this.isFundi, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Work Showcase',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
          const Spacer(),
          if (isFundi)
            GestureDetector(
              onTap: onUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      l10n.sw ? 'Pakia' : 'Upload',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Page Dots ─────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int total;
  final int current;
  const _PageDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        total,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width:  4,
          height: i == current ? 16 : 4,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: i == current
                ? Colors.white
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyReels extends StatelessWidget {
  final bool isFundi;
  final VoidCallback onUpload;
  const _EmptyReels({required this.isFundi, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text('Work Showcase',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                if (isFundi)
                  GestureDetector(
                    onTap: onUpload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            l10n.sw ? 'Pakia' : 'Upload',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.video_library_outlined,
                        size: 48,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.sw ? 'Hakuna Reels Bado' : 'No Work Reels Yet',
                      style: TextStyle(
                        color:      Colors.white.withOpacity(0.85),
                        fontSize:   20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isFundi
                          ? (l10n.sw
                              ? 'Pakia video ya kazi yako kuwavutia wateja'
                              : 'Upload a work video to attract more clients')
                          : (l10n.sw
                              ? 'Mafundi watapakia kazi zao hapa hivi karibuni'
                              : 'Fundis will showcase their work here soon'),
                      style: TextStyle(
                        color:      Colors.white.withOpacity(0.45),
                        fontSize:   14,
                        height:     1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isFundi) ...[
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        onPressed: onUpload,
                        icon: const Icon(Icons.video_call_rounded),
                        label: Text(l10n.sw ? 'Pakia Video' : 'Upload Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showComments(BuildContext context, ReelModel reel) {
  final auth = context.read<AuthProvider>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentsSheet(
      reelId:  reel.reelId,
      myId:    auth.userModel?.uid    ?? '',
      myName:  auth.userModel?.fullName ?? 'User',
      myPhoto: auth.userModel?.profileImageUrl ?? '',
      isAdmin: auth.isAdmin,
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String reelId;
  final String myId;
  final String myName;
  final String myPhoto;
  final bool   isAdmin;

  const _CommentsSheet({
    required this.reelId,
    required this.myId,
    required this.myName,
    required this.myPhoto,
    required this.isAdmin,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl    = TextEditingController();
  final _scrollC = ScrollController();
  bool _posting  = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting || widget.myId.isEmpty) return;
    setState(() => _posting = true);
    if (context.read<AuthProvider>().isGuest) {
      _showGuestPrompt(context); return;
    }
    await context.read<ReelProvider>().addComment(
      reelId:    widget.reelId,
      userId:    widget.myId,
      userName:  widget.myName,
      userPhoto: widget.myPhoto,
      text:      text,
    );
    _ctrl.clear();
    if (!mounted) return;
    setState(() => _posting = false);
    // scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollC.hasClients) {
        _scrollC.animateTo(
          _scrollC.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (_, sheetCtrl) => Container(
        decoration: const BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width:  40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.comment_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Comments', style: AppTextStyles.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            const Divider(height: 16),

            // Comments list
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: context.read<ReelProvider>().commentsStream(widget.reelId),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: AppLoader(size: 24));
                  }
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.grey400),
                          SizedBox(height: 8),
                          Text('No comments yet.\nBe the first!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollC,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final cm = comments[i];
                      final isOwn = cm.userId == widget.myId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: cm.userPhoto.isNotEmpty
                                  ? NetworkImage(cm.userPhoto)
                                  : null,
                              backgroundColor: AppColors.primarySurface,
                              child: cm.userPhoto.isEmpty
                                  ? Text(cm.userName.isNotEmpty
                                          ? cm.userName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(cm.userName,
                                        style: AppTextStyles.labelMedium
                                            .copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _ago(cm.createdAt),
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.textSecondary),
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(cm.text,
                                      style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                            if (isOwn || widget.isAdmin)
                              _CommentMenu(
                                key:      ValueKey(cm.commentId),
                                reelId:   widget.reelId,
                                comment:  cm,
                                isOwn:    isOwn,
                                isAdmin:  widget.isAdmin,
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText:       widget.myId.isEmpty
                            ? 'Log in to comment'
                            : 'Add a comment…',
                        hintStyle: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                      ),
                      enabled: widget.myId.isNotEmpty,
                      onSubmitted: (_) => _post(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _posting
                      ? SizedBox(
                          width: 36, height: 36,
                          child: AppLoader(size: 20))
                      : IconButton(
                          onPressed: widget.myId.isEmpty ? null : _post,
                          icon: const Icon(Icons.send_rounded,
                              color: AppColors.primary),
                          tooltip: 'Post',
                        ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Category Filter Chips ─────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<ReelModel>        allReels;
  final String?                selected;
  final ValueChanged<String?>  onSelected;

  const _CategoryChips({
    required this.allReels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cats = <String>{};
    for (final r in allReels) {
      if (r.category.isNotEmpty) cats.add(r.category);
    }
    if (cats.isEmpty) return const SizedBox.shrink();
    final sorted = cats.toList()..sort();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CatChip(
              label: 'All', sel: selected == null,
              onTap: () => onSelected(null),
            ),
          ),
          ...sorted.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CatChip(
              label: cat, sel: selected == cat,
              onTap: () => onSelected(cat == selected ? null : cat),
            ),
          )),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool   sel;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.sel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        sel
            ? AppColors.primary
            : Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: sel
              ? AppColors.primary
              : Colors.white.withOpacity(0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      sel ? Colors.white : Colors.white.withOpacity(0.85),
          fontSize:   12,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}


// ── Comment Action Menu (Edit + Delete) ──────────────────────────────────────
// StatefulWidget so _editing state persists correctly inside the scroll list.

class _CommentMenu extends StatefulWidget {
  final String       reelId;
  final CommentModel comment;
  final bool         isOwn;
  final bool         isAdmin;

  const _CommentMenu({
    super.key,
    required this.reelId,
    required this.comment,
    required this.isOwn,
    required this.isAdmin,
  });

  @override
  State<_CommentMenu> createState() => _CommentMenuState();
}

class _CommentMenuState extends State<_CommentMenu> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.comment.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text == widget.comment.text) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _editing = false);
    if (mounted) {
      await context.read<ReelProvider>().editComment(
            reelId:    widget.reelId,
            commentId: widget.comment.commentId,
            newText:   text,
          );
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete Comment?'),
        content: const Text('This comment will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancel'),
          ),
          TextButton(
            style:     TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child:     const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<ReelProvider>().deleteComment(
            reelId:    widget.reelId,
            commentId: widget.comment.commentId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 180,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller:  _ctrl,
                autofocus:   true,
                style:       AppTextStyles.bodySmall,
                maxLines:    null,
                decoration:  InputDecoration(
                  isDense:        true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onSubmitted: (_) => _saveEdit(),
              ),
            ),
            const SizedBox(width: 4),
            // Save button
            InkWell(
              onTap:       _saveEdit,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.check_circle_rounded,
                    size: 20, color: AppColors.success),
              ),
            ),
            // Cancel button
            InkWell(
              onTap:        () => setState(() {
                _editing = false;
                _ctrl.text = widget.comment.text;
              }),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.cancel_rounded,
                    size: 20, color: AppColors.grey400),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      padding:      EdgeInsets.zero,
      iconSize:     18,
      icon: const Icon(Icons.more_vert_rounded,
          size: 16, color: AppColors.grey400),
      itemBuilder: (_) => [
        if (widget.isOwn)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_rounded, size: 16),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded,
                size: 16, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ]),
        ),
      ],
      onSelected: (val) {
        if (val == 'edit')   setState(() => _editing = true);
        if (val == 'delete') _confirmDelete();
      },
    );
  }
}

// ── Guest prompt ──────────────────────────────────────────────────────────────

void _showGuestPrompt(BuildContext context) {
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
            child: const Icon(Icons.lock_outline_rounded,
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
            'Sign up to like reels, comment, save, book fundis and more.',
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
