import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // Since your botanical theme is dark
      scaffoldBackgroundColor: AppColors.forestDeep,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.fernGreen,
        onPrimary: AppColors.parchment,
        secondary: AppColors.agedGold,
        onSecondary: AppColors.forestDeep,
        surface: AppColors.forestMid,
        onSurface: AppColors.parchment,
        background: AppColors.forestDeep,
        onBackground: AppColors.mistGreen,
        tertiary: AppColors.mossGreen,
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.parchment,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.parchment,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: AppColors.mistGreen,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.forestDeep,
        foregroundColor: AppColors.parchment,
        elevation: 0,
        centerTitle: true,
      ),

      cardTheme: CardThemeData(
        color: AppColors.forestMid,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.mossGreen.withOpacity(0.3)),
        ),
      ),
    );
  }

  // Reusable Decoration for Screens
  static BoxDecoration get vineBackground => const BoxDecoration(
    color: AppColors.forestDeep,
    image: DecorationImage(
      image: AssetImage('assets/images/vinebg.png'), // Ensure path is correct in pubspec.yaml
      repeat: ImageRepeat.repeat,
      scale: 1.8,
      opacity: 0.18,
    ),
  );
}