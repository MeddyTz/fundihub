import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/reel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_empty_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Reels Review Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminReelsScreen extends StatefulWidget {
  const AdminReelsScreen({super.key});

  @override
  State<AdminReelsScreen> createState() => _AdminReelsScreenState();
}

class _AdminReelsScreenState extends State<AdminReelsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabLabels = ['Pending', 'Approved', 'Rejected', 'All', 'Deleted'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ReelProvider>();
      p.subscribePendingReels();
      p.subscribeRejectedReels();
      p.subscribeAllAdminReels();
      // Admin approved tab: no isActive filter
      p.subscribeApprovedAdminReels();
      p.subscribeDeletedReels();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReelProvider>();

    final lists = [
      p.pendingReels,
      p.approvedAdminReels,  // no isActive filter for admin view
      p.rejectedReels,
      p.allAdminReels,
      p.deletedReels,
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reels Review'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller:   _tabs,
          isScrollable: true,       // prevents RIGHT OVERFLOWED errors
          tabAlignment: TabAlignment.center,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.65),
          labelStyle: AppTextStyles.labelMedium
              .copyWith(fontWeight: FontWeight.w700),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: List.generate(4, (i) {
            final count = lists[i].length;
            return Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_tabLabels[i]),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    _TabBadge(
                      count: count,
                      color: i == 0
                          ? AppColors.warning
                          : i == 1
                              ? AppColors.success
                              : i == 2
                                  ? AppColors.error
                                  : i == 4
                                      ? AppColors.grey500
                                      : AppColors.primary,
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ReelList(
            reels:    p.pendingReels,
            status:   'pending',
            emptyTitle:    'No Pending Reels',
            emptySubtitle: 'All submissions have been reviewed.',
          ),
          _ReelList(
            reels:    p.approvedAdminReels,
            status:   'approved',
            emptyTitle:    'No Approved Reels',
            emptySubtitle: 'No reels have been approved yet.',
          ),
          _ReelList(
            reels:    p.rejectedReels,
            status:   'rejected',
            emptyTitle:    'No Rejected Reels',
            emptySubtitle: 'No reels have been rejected.',
          ),
          _ReelList(
            reels:    p.allAdminReels,
            status:   'all',
            emptyTitle:    'No Reels',
            emptySubtitle: 'No reels have been uploaded yet.',
          ),
          _ReelList(
            reels:    p.deletedReels,
            status:   'deleted',
            emptyTitle:    'No Deleted Reels',
            emptySubtitle: 'Fundis have not deleted any reels.',
            showHardDelete: true,
          ),
        ],
      ),
    );
  }
}

// ── Tab badge ─────────────────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _TabBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color:        color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

// ── Reel list tab content ─────────────────────────────────────────────────────

class _ReelList extends StatelessWidget {
  final List<ReelModel> reels;
  final String          status;
  final String          emptyTitle;
  final String          emptySubtitle;
  final bool            showHardDelete;

  const _ReelList({
    required this.reels,
    required this.status,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.showHardDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return AppEmptyState(
        icon:     Icons.video_library_outlined,
        title:    emptyTitle,
        subtitle: emptySubtitle,
        iconColor: status == 'pending'
            ? AppColors.warning
            : status == 'approved'
                ? AppColors.success
                : status == 'rejected'
                    ? AppColors.error
                    : AppColors.primary,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spaceLG,
        AppTheme.spaceLG,
        AppTheme.spaceLG,
        // Extra bottom padding so Approve/Reject clears bottom nav bar
        AppTheme.spaceLG + 80,
      ),
      itemCount:   reels.length,
      itemBuilder: (_, i) => _ReelReviewCard(
          reel: reels[i], showHardDelete: showHardDelete),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reel Review Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReelReviewCard extends StatefulWidget {
  final ReelModel reel;
  final bool      showHardDelete;
  const _ReelReviewCard({
      required this.reel, this.showHardDelete = false});

  @override
  State<_ReelReviewCard> createState() => _ReelReviewCardState();
}

class _ReelReviewCardState extends State<_ReelReviewCard> {
  bool _acting   = false;
  bool _deleting = false;

  // ── Hard-delete (Deleted tab) ───────────────────────────────────────────────
  Future<void> _hardDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('Permanently Delete?'),
        content: const Text(
            'This will delete the video from Cloudinary and remove the '
            'Firestore document permanently.\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final err = await context
        .read<ReelProvider>()
        .hardDeleteReel(widget.reel.reelId);
    if (!mounted) return;
    setState(() => _deleting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null
            ? '🗑 Reel permanently deleted'
            : 'Delete failed: $err'),
        backgroundColor:
            err == null ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Hard-delete ────────────────────────────────────────────────────────────
  // ── Approve ────────────────────────────────────────────────────────────────
  Future<void> _approve() async {
    setState(() => _acting = true);
    final adminId =
        context.read<AuthProvider>().userModel?.uid ?? '';
    await context
        .read<ReelProvider>()
        .approveReel(widget.reel.reelId, approvedBy: adminId);
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Reel approved and published'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Reject ─────────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null || !mounted) return;
    setState(() => _acting = true);
    final adminId =
        context.read<AuthProvider>().userModel?.uid ?? '';
    await context.read<ReelProvider>().rejectReel(
          widget.reel.reelId,
          reason:     reason,
          rejectedBy: adminId,
        );
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reel rejected'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _showRejectDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL)),
        title: const Text('Reject Reel'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide a reason (optional):'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus:  true,
            maxLines:   3,
            decoration: const InputDecoration(
              hintText: 'e.g. Low quality, inappropriate content...',
              border:   OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ── Video preview ──────────────────────────────────────────────────────────
  void _openPreview() {
    if (widget.reel.videoUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenPlayer(
          videoUrl:  widget.reel.videoUrl,
          reelTitle: widget.reel.fundiName,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final reel   = widget.reel;
    final status = reel.status;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLG),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border:       Border.all(color: AppColors.border),
        boxShadow:    AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header: avatar + name + category + status ──────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  name:     reel.fundiName,
                  imageUrl: reel.fundiProfileImage.isNotEmpty
                      ? reel.fundiProfileImage
                      : null,
                  size: 42,
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reel.fundiName,
                        style: AppTextStyles.titleSmall
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        Flexible(
                          child: _Chip(
                            label: reel.category,
                            color: AppColors.primary,
                            bg:    AppColors.primarySurface,
                          ),
                        ),
                        if (reel.location.isNotEmpty) ...[  
                          const SizedBox(width: 6),
                          Flexible(
                            child: _Chip(
                              label: reel.location,
                              color: AppColors.textSecondary,
                              bg:    AppColors.surfaceVariant,
                              icon:  Icons.location_on_rounded,
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _StatusBadge(status: status),
              ],
            ),
          ),

          // ── Caption ────────────────────────────────────────────────────
          if (reel.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLG, 0, AppTheme.spaceLG, AppTheme.spaceMD),
              child: Text(
                reel.caption,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ── Video thumbnail / preview ───────────────────────────────────
          if (reel.videoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLG, 0, AppTheme.spaceLG, AppTheme.spaceMD),
              child: GestureDetector(
                onTap: _openPreview,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMD),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail (Cloudinary on-the-fly)
                        reel.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: reel.thumbnailUrl,
                                fit:      BoxFit.cover,
                                placeholder: (_, __) =>
                                    _VideoPlaceholder(category: reel.category),
                                errorWidget: (_, __, ___) =>
                                    _VideoPlaceholder(category: reel.category),
                              )
                            : _VideoPlaceholder(category: reel.category),

                        // Dark overlay + play icon
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end:   Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width:  56,
                            height: 56,
                            decoration: BoxDecoration(
                              color:  Colors.white.withOpacity(0.2),
                              shape:  BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 2),
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 32),
                          ),
                        ),
                        // Duration badge
                        if (reel.durationSeconds > 0)
                          Positioned(
                            bottom: 8,
                            right:  8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:        Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatDuration(reel.durationSeconds),
                                style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        // Tap hint
                        Positioned(
                          top:  8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tap to Preview',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Rejection reason (if rejected) ─────────────────────────────
          if (reel.isRejected && reel.rejectionReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLG, 0, AppTheme.spaceLG, AppTheme.spaceMD),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color:        AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                      color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${reel.rejectionReason}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Stats row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLG, 0, AppTheme.spaceLG, AppTheme.spaceMD),
            child: Row(children: [
              _StatChip(Icons.play_circle_outline_rounded,
                  '${reel.viewsCount}'),
              const SizedBox(width: 12),
              _StatChip(Icons.favorite_border_rounded, '${reel.likesCount}'),
              const SizedBox(width: 12),
              _StatChip(Icons.bookmark_border_rounded, '${reel.savesCount}'),
            ]),
          ),

          // ── Action buttons (only show for pending) ─────────────────────
          if (reel.isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLG, 0, AppTheme.spaceLG, AppTheme.spaceLG),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _acting ? null : _reject,
                    icon:  const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withOpacity(0.5)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD)),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acting ? null : _approve,
                    icon: _acting
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_acting ? 'Approving…' : 'Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 11),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD)),
                    ),
                  ),
                ),
              ]),
            )
          else
            const SizedBox(height: AppTheme.spaceLG),

          // ── Delete Forever (Deleted tab only) ─────────────────────
          if (widget.showHardDelete)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLG, 0,
                  AppTheme.spaceLG, AppTheme.spaceLG),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _deleting ? null : _hardDelete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(
                          Icons.delete_forever_rounded, size: 16),
                  label: Text(
                      _deleting ? 'Deleting…' : 'Delete Forever'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMD)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen video player dialog
// ─────────────────────────────────────────────────────────────────────────────

class _FullScreenPlayer extends StatefulWidget {
  final String videoUrl;
  final String reelTitle;

  const _FullScreenPlayer({
    required this.videoUrl,
    required this.reelTitle,
  });

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized  = false;
  bool _loading      = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl));
      _ctrl = ctrl;
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      ctrl.setLooping(true);
      ctrl.play();
      setState(() { _initialized = true; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load video.'; });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.reelTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_initialized)
            IconButton(
              icon: Icon(
                _ctrl!.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _ctrl!.value.isPlaying
                      ? _ctrl!.pause()
                      : _ctrl!.play();
                });
              },
            ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() { _loading = true; _error = null; });
                          _initPlayer();
                        },
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _ctrl!.value.isPlaying
                            ? _ctrl!.pause()
                            : _ctrl!.play();
                      });
                    },
                    child: AspectRatio(
                      aspectRatio: _ctrl!.value.aspectRatio,
                      child: VideoPlayer(_ctrl!),
                    ),
                  ),
      ),
      bottomNavigationBar: _initialized
          ? VideoProgressIndicator(
              _ctrl!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor:    AppColors.primary,
                bufferedColor:  Colors.white24,
                backgroundColor: Colors.white12,
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'approved' => (
          label: 'Approved',
          color: AppColors.success,
          bg:    AppColors.successSurface
        ),
      'rejected' => (
          label: 'Rejected',
          color: AppColors.error,
          bg:    AppColors.errorSurface
        ),
      _ => (
          label: 'Pending',
          color: AppColors.warning,
          bg:    AppColors.warningSurface
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color:        config.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: config.color.withOpacity(0.35)),
      ),
      child: Text(
        config.label,
        style: AppTextStyles.caption.copyWith(
          color:      config.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String  label;
  final Color   color;
  final Color   bg;
  final IconData? icon;
  const _Chip(
      {required this.label, required this.color, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   value;
  const _StatChip(this.icon, this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(value,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );
}

class _VideoPlaceholder extends StatelessWidget {
  final String category;
  const _VideoPlaceholder({required this.category});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primary.withOpacity(0.12),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.video_library_rounded,
                size: 36, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 6),
            Text(
              category,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primary.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}
