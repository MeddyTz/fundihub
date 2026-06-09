import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class FundiHubLogo extends StatelessWidget {
  final double size;
  final bool showText, darkBackground;

  const FundiHubLogo({
    super.key,
    this.size = 100, // 👈 increased default size
    this.showText = true,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔥 CLEAN LOGO (NO BLUE BACKGROUND)
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),

        if (showText) ...[
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'FundiHub',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: size * 0.28,
              fontWeight: FontWeight.w700,
              color:
                  darkBackground ? AppColors.white : AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}