// Flutter 3.44 moved CupertinoPageTransitionsBuilder from material.dart to
// cupertino.dart (docs.flutter.dev/release/breaking-changes/decouple-page-transition-builders).
// Importing both builds on either side of that change; on older Flutter this
// import is unused, hence the ignore.
// ignore: unused_import, unnecessary_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// Brand v1 (CLAUDE.md): tonal depth on a violet-black ground, no card
/// outlines, soft rounded shapes, violet for actions only. Screens rebuilt for
/// v1 use the kit in presentation/widgets/kit/; this theme makes the stock
/// Material widgets on not-yet-rebuilt screens match as closely as possible.
class AppTheme {
  AppTheme._();

  static final OutlineInputBorder _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
    borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
  );

  static ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.ground,
    splashFactory: NoSplash.splashFactory, // press-scale replaces ink ripples
    highlightColor: Colors.transparent,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.primaryText,
      surface: AppColors.surface1,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surface2,
      error: AppColors.bad,
      onError: AppColors.ground,
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.ground),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.h3,
    ),

    textTheme: TextTheme(
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
      titleMedium: AppTextStyles.title,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.button,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface1,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.text3),
      labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2),
      floatingLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText),
      border: _inputBorder,
      enabledBorder: _inputBorder,
      focusedBorder: _inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.primaryText, width: 1.5)),
      errorBorder: _inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.bad, width: 1.5)),
      focusedErrorBorder: _inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.bad, width: 1.5)),
      errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.bad),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.surface2,
        disabledForegroundColor: AppColors.text3,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLg),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        textStyle: AppTextStyles.button,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      // v1 has no outlined buttons: the secondary button is a filled surface.
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.text,
        minimumSize: const Size(double.infinity, AppDimensions.buttonHeightMd),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        textStyle: AppTextStyles.button.copyWith(fontSize: 15),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryText,
        textStyle: AppTextStyles.button.copyWith(fontSize: 14),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface1,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface1,
      selectedColor: AppColors.primarySoft,
      labelStyle: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: AppColors.text2),
      secondaryLabelStyle: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: AppColors.primaryText),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface1,
      modalBackgroundColor: AppColors.surface1,
      showDragHandle: true,
      dragHandleColor: AppColors.surface3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl))),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface3,
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
    ),

    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface2,
      selectedItemColor: AppColors.primaryText,
      unselectedItemColor: AppColors.text3,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTextStyles.bodySmall,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surface3,
      circularTrackColor: Colors.transparent,
    ),
  );
}
