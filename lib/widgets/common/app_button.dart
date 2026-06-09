import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'app_loader.dart';

enum AppButtonType { primary, secondary, outline, text, danger, success, premium }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? height;
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? 52.0;
    switch (type) {
      case AppButtonType.primary:
        return _gradient(
          colors: const [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          fg: Colors.white,
          h: h,
          shadowColor: AppColors.primary,
        );
      case AppButtonType.success:
        return _gradient(
          colors: const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          fg: Colors.white,
          h: h,
          shadowColor: AppColors.success,
        );
      case AppButtonType.premium:
        return _gradient(
          colors: const [Color(0xFFFF6F00), Color(0xFFFFB300), Color(0xFFFFCA28)],
          fg: Colors.white,
          h: h,
          shadowColor: AppColors.premium,
        );
      case AppButtonType.secondary:
        return _gradient(
          colors: const [Color(0xFFE65100), Color(0xFFFF6F00), Color(0xFFFF8F00)],
          fg: Colors.white,
          h: h,
          shadowColor: AppColors.secondary,
        );
      case AppButtonType.danger:
        return _gradient(
          colors: const [Color(0xFFB71C1C), Color(0xFFC62828), Color(0xFFD32F2F)],
          fg: Colors.white,
          h: h,
          shadowColor: AppColors.error,
        );
      case AppButtonType.outline:
        return _outlined(h);
      case AppButtonType.text:
        return _text(h);
    }
  }

  Widget _gradient({
    required List<Color> colors,
    required Color fg,
    required double h,
    required Color shadowColor,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading || onPressed == null
              ? null
              : LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isLoading || onPressed == null
              ? AppColors.grey300
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD + 2),
          boxShadow: isLoading || onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: shadowColor.withOpacity(0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isLoading || onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: fg,
            shadowColor: Colors.transparent,
            elevation: 0,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD + 2)),
          ),
          child: _child(fg),
        ),
      ),
    );
  }

  Widget _outlined(double h) => SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: h,
        child: OutlinedButton(
          onPressed: isLoading || onPressed == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD + 2)),
          ),
          child: _child(AppColors.primary),
        ),
      );

  Widget _text(double h) => SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: h,
        child: TextButton(
          onPressed: isLoading || onPressed == null ? null : onPressed,
          child: _child(AppColors.primary),
        ),
      );

  Widget _child(Color c) {
    if (isLoading) return AppLoader(size: 22, color: c);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18),
          const SizedBox(width: AppTheme.spaceSM),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.buttonMedium.copyWith(fontSize: fontSize),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppTheme.spaceSM),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}
