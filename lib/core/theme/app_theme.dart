import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// Dark-first: ink ground, paper text, gold as the single bold accent.
/// No gradients, no glassmorphism, no heavy shadows — depth comes from
/// hairline borders (ink-3) and flat fills only. See CLAUDE.md brand v0.
class AppTheme {
  AppTheme._();

  static ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.ink,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.ink,
      secondary: AppColors.signalGreen,
      surface: AppColors.ink2,
      onSurface: AppColors.paper,
      error: AppColors.openPending,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.h3,
    ),

    textTheme: TextTheme(
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.button,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ink2,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.ink3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.ink3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.openPending),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: AppColors.ink3,
        disabledForegroundColor: AppColors.slateDim,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMd),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        textStyle: AppTextStyles.button,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.paper,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMd),
        side: const BorderSide(color: AppColors.ink3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        textStyle: AppTextStyles.button,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        textStyle: AppTextStyles.button,
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.ink2,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: const BorderSide(color: AppColors.ink3),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.ink3,
      thickness: 1,
      space: 1,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.ink2,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.slateDim,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.gold),
      unselectedLabelStyle: AppTextStyles.bodySmall,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.ink3,
    ),
  );
}
