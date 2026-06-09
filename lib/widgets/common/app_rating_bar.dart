import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AppRatingBar extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double iconSize;
  final bool showCount;
  /// If true, shows smaller stars with less spacing (for compact cards).
  final bool compact;

  const AppRatingBar({
    super.key,
    required this.rating,
    this.reviewCount = 0,
    this.iconSize = 14,
    this.showCount = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? (iconSize - 2).clamp(10.0, 12.0) : iconSize;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = i < rating.floor();
          final half = !filled && i < rating;
          return Icon(
            filled
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: filled || half ? AppColors.premium : AppColors.grey300,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating == 0
              ? 'New'
              : '${rating.toStringAsFixed(1)}'
                  '${showCount && !compact && reviewCount > 0 ? " ($reviewCount)" : ""}',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            fontSize: compact ? 10 : null,
          ),
        ),
        if (showCount && reviewCount > 0 && !compact) ...[
          // already included in the text above
        ],
      ],
    );
  }
}
