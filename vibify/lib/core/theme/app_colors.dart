import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primaryBeige = Color(0xFFD6B48A);

  // Light Theme
  static const Color lightBackground = Color(0xFFF6F1EB);
  static const Color lightSurface = Color(0xFFEFE6DB);
  static const Color lightText = Color(0xFF1D1D1D);
  static const Color lightSecondaryText = Color(0xFF6B6B6B);

  // Dark Theme
  static const Color darkBackground = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFB3B3B3);

  // Semantic
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color info = Color(0xFF1E88E5);

  // Overlays
  static Color overlayDark = const Color(0xFF000000).withOpacity(0.6);
  static Color overlayLight = const Color(0xFFFFFFFF).withOpacity(0.1);

  // Player gradient stops
  static const Color playerGradientStart = Color(0xFF1A1A1A);
  static const Color playerGradientEnd = Color(0xFF111111);
}
