import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Brand v1: Public Sans for headlines and UI (800, tight tracking for
/// headlines), JetBrains Mono for eyebrow labels and step numbers only.
/// Fraunces survives only in the KD logomark (see [logomark]).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _sans({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    double letterSpacing = 0,
    Color color = AppColors.text,
  }) => GoogleFonts.publicSans(
    fontSize: fontSize,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  // Headlines
  static TextStyle h1 = _sans(fontSize: 28, weight: FontWeight.w800, height: 1.15, letterSpacing: -0.7);
  static TextStyle h2 = _sans(fontSize: 24, weight: FontWeight.w800, height: 1.2, letterSpacing: -0.6);
  static TextStyle h3 = _sans(fontSize: 19, weight: FontWeight.w700, height: 1.25, letterSpacing: -0.3);
  /// Card and row titles.
  static TextStyle title = _sans(fontSize: 15, weight: FontWeight.w700, height: 1.35);

  // Body
  static TextStyle bodyLarge = _sans(fontSize: 16);
  static TextStyle bodyMedium = _sans(fontSize: 14);
  static TextStyle bodySmall = _sans(fontSize: 12.5, color: AppColors.text2);
  static TextStyle hint = _sans(fontSize: 12, color: AppColors.text3);

  static TextStyle button = _sans(fontSize: 16, weight: FontWeight.w700, height: 1.2);

  /// Big countdowns and amounts: tabular figures so digits don't jump.
  static TextStyle figure = _sans(fontSize: 34, weight: FontWeight.w800, height: 1.1, letterSpacing: -1)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Uppercase, letter-spaced mono: eyebrow labels and step numbers only.
  static TextStyle label = GoogleFonts.jetBrainsMono(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.text3,
  );

  /// The typographic KD mark, in gold. The only place Fraunces is used.
  static TextStyle logomark = GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.money);
}
