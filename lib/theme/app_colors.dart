import 'package:flutter/material.dart';

/// App Color Scheme
/// Centralized color palette for consistent theming across the app
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary Color Palette
  static const Color softMint = Color(0xFFCBDED3);
  static const Color mutedGreen = Color(0xFF8BA49A);
  static const Color lightTan = Color(0xFFD2C49E);
  static const Color sageGreen = Color(0xFF3B6255);
  static const Color offWhite = Color(0xFFE2DFDA);

  // Optional: Semantic color names for specific use cases
  static const Color primaryBackground = offWhite;
  static const Color cardBackground = softMint;
  static const Color primaryAccent = sageGreen;
  static const Color secondaryAccent = mutedGreen;
  static const Color highlightAccent = lightTan;

  // Text colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textOnPrimary = Colors.white;
}
