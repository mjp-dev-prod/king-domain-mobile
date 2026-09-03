import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Fraunces for display/headlines, Public Sans for body/UI, JetBrains Mono
/// for eyebrow labels and stat captions — see king-domain-mobile/CLAUDE.md.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _display({
    required double fontSize,
    FontWeight weight = FontWeight.w600,
    double height = 1.15,
    Color color = AppColors.paper,
  }) => GoogleFonts.fraunces(
    fontSize: fontSize,
    fontWeight: weight,
    height: height,
    color: color,
    letterSpacing: -0.4,
  );

  static TextStyle _body({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    Color color = AppColors.paper,
  }) => GoogleFonts.publicSans(
    fontSize: fontSize,
    fontWeight: weight,
    height: height,
    color: color,
  );

  // Display
  static TextStyle h1 = _display(fontSize: 32);
  static TextStyle h2 = _display(fontSize: 26);
  static TextStyle h3 = _display(fontSize: 20);

  // Body
  static TextStyle bodyLarge = _body(fontSize: 16);
  static TextStyle bodyMedium = _body(fontSize: 14);
  static TextStyle bodySmall = _body(fontSize: 12, color: AppColors.slateDim);

  static TextStyle button = GoogleFonts.publicSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Uppercase, letter-spaced mono — eyebrow labels, stat labels, step numbers.
  static TextStyle label = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    color: AppColors.slateDim,
  );
}
