import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/fundi_model.dart';
import '../common/app_avatar.dart';
import '../common/app_rating_bar.dart';
import '../common/app_shimmer.dart';

class PromotedFundisSection extends StatelessWidget {
  final List<FundiModel> fundis;
  final bool isLoading;
  final void Function(FundiModel) onFundiTap;

  const PromotedFundisSection({
    super.key,
    required this.fundis,
    required this.isLoading,
    required this.onFundiTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && fundis.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.promotedSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  size: 16, color: AppColors.promoted),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Text('Featured Fundis',
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.promotedSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                '${fundis.length} boosted',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.promoted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMD),
        SizedBox(
          height: 190,
          child: isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  itemBuilder: (_, __) => AppShimmer(
                    child: Container(
                      width: 165,
                      margin:
                          const EdgeInsets.only(right: AppTheme.spaceMD),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXL),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: fundis.length,
                  itemBuilder: (_, i) => _BoostCard(
                    fundi: fundis[i],
                    onTap: () => onFundiTap(fundis[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _BoostCard extends StatelessWidget {
  final FundiModel fundi;
  final VoidCallback onTap;

  const _BoostCard({required this.fundi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
              color: AppColors.promoted.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.promoted.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boost banner
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.promoted.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusXL)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rocket_launch_rounded,
                      size: 11, color: AppColors.promoted),
                  const SizedBox(width: 3),
                  Text(
                    'BOOSTED',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.promoted,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: AppAvatar(
                      imageUrl: fundi.profileImageUrl,
                      name: fundi.fullName,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  Text(
                    fundi.fullName,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull),
                      ),
                      child: Text(
                        fundi.displayCategory,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: AppRatingBar(
                      rating: fundi.rating,
                      reviewCount: fundi.reviewCount,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
