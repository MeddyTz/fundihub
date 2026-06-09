import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/reel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../widgets/common/app_empty_state.dart';

class SavedReelsScreen extends StatefulWidget {
  const SavedReelsScreen({super.key});

  @override
  State<SavedReelsScreen> createState() => _SavedReelsScreenState();
}

class _SavedReelsScreenState extends State<SavedReelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().userModel?.uid ?? '';
      if (uid.isNotEmpty) {
        context.read<ReelProvider>().subscribeSavedReels(uid);
      }
    });
  }

  @override
  void dispose() {
    context.read<ReelProvider>().cancelSavedReelsSub();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reels = context.watch<ReelProvider>().savedReels;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Reels'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: reels.isEmpty
          ? const AppEmptyState(
              icon:     Icons.bookmark_border_rounded,
              title:    'No Saved Reels',
              subtitle: 'Tap the bookmark icon on any reel to save it here.',
              iconColor: AppColors.primary,
            )
          : GridView.builder(
              padding:     const EdgeInsets.all(AppTheme.spaceMD),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                crossAxisSpacing: AppTheme.spaceMD,
                mainAxisSpacing:  AppTheme.spaceMD,
                childAspectRatio: 9 / 16,
              ),
              itemCount: reels.length,
              itemBuilder: (_, i) => _SavedReelCard(
                reel:    reels[i],
                onTap:   () => context.push('/reels'),
                onUnsave: () {
                  final uid =
                      context.read<AuthProvider>().userModel?.uid ?? '';
                  if (uid.isNotEmpty) {
                    context
                        .read<ReelProvider>()
                        .toggleSaveWithStorage(reels[i].reelId, uid, false);
                  }
                },
              ),
            ),
    );
  }
}

class _SavedReelCard extends StatelessWidget {
  final ReelModel    reel;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const _SavedReelCard({
    required this.reel,
    required this.onTap,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            reel.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: reel.thumbnailUrl,
                    fit:      BoxFit.cover,
                    placeholder: (_, __) => Container(
                        color: AppColors.primary.withOpacity(0.1)),
                    errorWidget: (_, __, ___) => Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.videocam_off_rounded,
                            color: AppColors.grey400)),
                  )
                : Container(
                    color: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.videocam_rounded,
                        color: AppColors.grey400, size: 40),
                  ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // Category chip top-left
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  reel.category,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // Unsave button top-right
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: onUnsave,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bookmark_rounded,
                      color: Colors.amber, size: 16),
                ),
              ),
            ),

            // Bottom info
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      reel.fundiName,
                      style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reel.caption.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reel.caption,
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.play_circle_outline_rounded,
                          size: 10, color: Colors.white60),
                      const SizedBox(width: 3),
                      Text('${reel.viewsCount}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 9)),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite_border_rounded,
                          size: 10, color: Colors.white60),
                      const SizedBox(width: 3),
                      Text('${reel.likesCount}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 9)),
                    ]),
                  ],
                ),
              ),
            ),

            // Play icon center
            const Center(
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white54, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}
