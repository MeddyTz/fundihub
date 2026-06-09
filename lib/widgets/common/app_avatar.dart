import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.backgroundColor,
  });

  // Safely extract initials — never crashes on empty/null.
  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Color get _bg =>
      backgroundColor ?? AppColors.primary.withOpacity(0.15);

  bool get _hasValidUrl {
    final url = imageUrl;
    if (url == null || url.trim().isEmpty) return false;
    // Guard against template strings that were never interpolated.
    if (url.contains('\${') || url.contains('{P[0]')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: _hasValidUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initials_widget(),
                errorWidget: (_, __, ___) => _initials_widget(),
              )
            : _initials_widget(),
      ),
    );
  }

  Widget _initials_widget() => Container(
        color: _bg,
        child: Center(
          child: Text(
            _initials,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}
