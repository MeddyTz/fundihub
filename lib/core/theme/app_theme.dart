import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusFull = 100.0;
  static const double spaceXXS = 2.0;
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 12.0;
  static const double spaceLG = 16.0;
  static const double spaceXL = 20.0;
  static const double spaceXXL = 24.0;
  static const double space3XL = 32.0;
  static const double space4XL = 40.0;
  static const double space5XL = 48.0;
  static const double elevationXS = 1.0;
  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;
  static const double iconSM = 16.0;
  static const double iconMD = 20.0;
  static const double iconLG = 24.0;


static List<BoxShadow> cardShadow = [
  BoxShadow(
    color: Colors.black.withOpacity(0.08),
    blurRadius: 12,
    offset: const Offset(0, 4),
  ),
];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.primarySurface,
        secondary: AppColors.secondary,
        onSecondary: AppColors.white,
        error: AppColors.error,
        onError: AppColors.white,
        background: AppColors.background,
        onBackground: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        titleTextStyle: AppTextStyles.appBarTitle,
        iconTheme: IconThemeData(color: AppColors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.primaryDark,
          statusBarIconBrightness: Brightness.light,
        ),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: elevationSM,
        shadowColor: Color(0x14000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusLG))),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: elevationSM,
          padding: EdgeInsets.symmetric(horizontal: spaceXXL, vertical: spaceMD + 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD))),
          textStyle: AppTextStyles.buttonMedium,
          minimumSize: Size(double.infinity, 52),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: spaceXXL, vertical: spaceMD + 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD))),
          textStyle: AppTextStyles.buttonMedium,
          minimumSize: Size(double.infinity, 52),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: spaceLG, vertical: spaceMD + 2),
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD)), borderSide: BorderSide(color: AppColors.border, width: 1.0)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD)), borderSide: BorderSide(color: AppColors.border, width: 1.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD)), borderSide: BorderSide(color: AppColors.primary, width: 2.0)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD)), borderSide: BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMD)), borderSide: BorderSide(color: AppColors.error, width: 2.0)),
        hintStyle: TextStyle(fontFamily:'Poppins',fontSize:14,color:AppColors.textHint),
        prefixIconColor: AppColors.grey500,
        suffixIconColor: AppColors.grey500,
        errorStyle: TextStyle(fontFamily:'Poppins',fontSize:11,color:AppColors.error),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey500,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontFamily:'Poppins',fontSize:11,fontWeight:FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily:'Poppins',fontSize:11,fontWeight:FontWeight.w400),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.grey900,
        contentTextStyle: TextStyle(fontFamily:'Poppins',fontSize:14,color:AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusSM))),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}