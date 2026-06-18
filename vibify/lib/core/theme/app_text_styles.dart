import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextTheme get lightTextTheme => _buildTextTheme(AppColors.lightText);
  static TextTheme get darkTextTheme => _buildTextTheme(AppColors.darkText);

  static TextTheme _buildTextTheme(Color textColor) => TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 57,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: -0.25,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 45,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: -0.5,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: -0.25,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0,
          height: 1.27,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.15,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textColor,
          letterSpacing: 0.5,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textColor,
          letterSpacing: 0.25,
          height: 1.43,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textColor.withValues(alpha: 0.7),
          letterSpacing: 0.4,
          height: 1.33,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: 0.5,
          height: 1.33,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: 0.5,
          height: 1.45,
        ),
      );
}
