import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryBeige,
          onPrimary: AppColors.darkBackground,
          secondary: AppColors.primaryBeige,
          onSecondary: AppColors.darkBackground,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightText,
          error: AppColors.error,
          onError: Colors.white,
          surfaceVariant: AppColors.lightSurface,
          onSurfaceVariant: AppColors.lightSecondaryText,
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        fontFamily: 'Inter',
        textTheme: AppTextStyles.lightTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.lightBackground,
          foregroundColor: AppColors.lightText,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          titleTextStyle: AppTextStyles.lightTextTheme.titleLarge,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightBackground,
          selectedItemColor: AppColors.primaryBeige,
          unselectedItemColor: AppColors.lightSecondaryText,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          indicatorColor: AppColors.primaryBeige.withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: AppColors.primaryBeige);
            }
            return IconThemeData(color: AppColors.lightSecondaryText);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTextStyles.lightTextTheme.labelSmall?.copyWith(
                color: AppColors.primaryBeige,
                fontWeight: FontWeight.w600,
              );
            }
            return AppTextStyles.lightTextTheme.labelSmall?.copyWith(
              color: AppColors.lightSecondaryText,
            );
          }),
        ),
        cardTheme: CardTheme(
          color: AppColors.lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(0),
        ),
        listTileTheme: ListTileThemeData(
          tileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryBeige,
              width: 1.5,
            ),
          ),
          hintStyle: TextStyle(
            color: AppColors.lightSecondaryText,
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBeige,
            foregroundColor: AppColors.darkBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.lightText, size: 24),
        dividerTheme: DividerThemeData(
          color: AppColors.lightText.withValues(alpha: 0.08),
          thickness: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBeige;
            }
            return AppColors.lightSecondaryText;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBeige.withValues(alpha: 0.4);
            }
            return AppColors.lightSecondaryText.withValues(alpha: 0.2);
          }),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primaryBeige,
          inactiveTrackColor: AppColors.lightSecondaryText.withValues(alpha: 0.2),
          thumbColor: AppColors.primaryBeige,
          overlayColor: AppColors.primaryBeige.withValues(alpha: 0.2),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryBeige,
          onPrimary: AppColors.darkBackground,
          secondary: AppColors.primaryBeige,
          onSecondary: AppColors.darkBackground,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkText,
          error: AppColors.error,
          onError: Colors.white,
          surfaceVariant: AppColors.darkSurface,
          onSurfaceVariant: AppColors.darkSecondaryText,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        fontFamily: 'Inter',
        textTheme: AppTextStyles.darkTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          titleTextStyle: AppTextStyles.darkTextTheme.titleLarge,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkBackground,
          selectedItemColor: AppColors.primaryBeige,
          unselectedItemColor: AppColors.darkSecondaryText,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          indicatorColor: AppColors.primaryBeige.withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: AppColors.primaryBeige);
            }
            return IconThemeData(color: AppColors.darkSecondaryText);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTextStyles.darkTextTheme.labelSmall?.copyWith(
                color: AppColors.primaryBeige,
                fontWeight: FontWeight.w600,
              );
            }
            return AppTextStyles.darkTextTheme.labelSmall?.copyWith(
              color: AppColors.darkSecondaryText,
            );
          }),
        ),
        cardTheme: CardTheme(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(0),
        ),
        listTileTheme: ListTileThemeData(
          tileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primaryBeige,
              width: 1.5,
            ),
          ),
          hintStyle: TextStyle(
            color: AppColors.darkSecondaryText,
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBeige,
            foregroundColor: AppColors.darkBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.darkText, size: 24),
        dividerTheme: DividerThemeData(
          color: AppColors.darkText.withValues(alpha: 0.08),
          thickness: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBeige;
            }
            return AppColors.darkSecondaryText;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBeige.withValues(alpha: 0.4);
            }
            return AppColors.darkSecondaryText.withValues(alpha: 0.2);
          }),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primaryBeige,
          inactiveTrackColor: AppColors.darkSecondaryText.withValues(alpha: 0.2),
          thumbColor: AppColors.primaryBeige,
          overlayColor: AppColors.primaryBeige.withValues(alpha: 0.2),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
      );
}
