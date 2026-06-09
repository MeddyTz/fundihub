import 'package:flutter/material.dart';
import 'app_colors.dart';
class AppTextStyles {
  AppTextStyles._();
  static const TextStyle displayLarge = TextStyle(fontFamily:'Poppins',fontSize:32,fontWeight:FontWeight.w700,color:AppColors.textPrimary,letterSpacing:-0.5,height:1.2);
  static const TextStyle displayMedium = TextStyle(fontFamily:'Poppins',fontSize:28,fontWeight:FontWeight.w700,color:AppColors.textPrimary,height:1.25);
  static const TextStyle displaySmall = TextStyle(fontFamily:'Poppins',fontSize:24,fontWeight:FontWeight.w600,color:AppColors.textPrimary,height:1.3);
  static const TextStyle headlineLarge = TextStyle(fontFamily:'Poppins',fontSize:22,fontWeight:FontWeight.w700,color:AppColors.textPrimary,height:1.3);
  static const TextStyle headlineMedium = TextStyle(fontFamily:'Poppins',fontSize:20,fontWeight:FontWeight.w600,color:AppColors.textPrimary,height:1.35);
  static const TextStyle headlineSmall = TextStyle(fontFamily:'Poppins',fontSize:18,fontWeight:FontWeight.w600,color:AppColors.textPrimary,height:1.4);
  static const TextStyle titleLarge = TextStyle(fontFamily:'Poppins',fontSize:16,fontWeight:FontWeight.w600,color:AppColors.textPrimary,height:1.4);
  static const TextStyle titleMedium = TextStyle(fontFamily:'Poppins',fontSize:15,fontWeight:FontWeight.w500,color:AppColors.textPrimary,height:1.45);
  static const TextStyle titleSmall = TextStyle(fontFamily:'Poppins',fontSize:14,fontWeight:FontWeight.w500,color:AppColors.textPrimary,height:1.5);
  static const TextStyle bodyLarge = TextStyle(fontFamily:'Poppins',fontSize:16,fontWeight:FontWeight.w400,color:AppColors.textPrimary,height:1.5);
  static const TextStyle bodyMedium = TextStyle(fontFamily:'Poppins',fontSize:14,fontWeight:FontWeight.w400,color:AppColors.textPrimary,height:1.5);
  static const TextStyle bodySmall = TextStyle(fontFamily:'Poppins',fontSize:12,fontWeight:FontWeight.w400,color:AppColors.textSecondary,height:1.5);
  static const TextStyle labelLarge = TextStyle(fontFamily:'Poppins',fontSize:14,fontWeight:FontWeight.w600,color:AppColors.textPrimary,letterSpacing:0.1);
  static const TextStyle labelMedium = TextStyle(fontFamily:'Poppins',fontSize:12,fontWeight:FontWeight.w500,color:AppColors.textSecondary,letterSpacing:0.5);
  static const TextStyle labelSmall = TextStyle(fontFamily:'Poppins',fontSize:11,fontWeight:FontWeight.w500,color:AppColors.textHint,letterSpacing:0.5);
  static const TextStyle buttonLarge = TextStyle(fontFamily:'Poppins',fontSize:16,fontWeight:FontWeight.w600,letterSpacing:0.5);
  static const TextStyle buttonMedium = TextStyle(fontFamily:'Poppins',fontSize:14,fontWeight:FontWeight.w600,letterSpacing:0.25);
  static const TextStyle caption = TextStyle(fontFamily:'Poppins',fontSize:11,fontWeight:FontWeight.w400,color:AppColors.textHint,height:1.4);
  static const TextStyle appBarTitle = TextStyle(fontFamily:'Poppins',fontSize:18,fontWeight:FontWeight.w600,color:AppColors.white);
  static const TextStyle chatMessage = TextStyle(fontFamily:'Poppins',fontSize:14,fontWeight:FontWeight.w400,height:1.4);
  static const TextStyle chatTime = TextStyle(fontFamily:'Poppins',fontSize:10,fontWeight:FontWeight.w400,color:AppColors.textHint);
}