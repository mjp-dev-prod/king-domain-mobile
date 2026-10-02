import 'package:flutter/animation.dart';

/// Motion tokens (CLAUDE.md "Brand — v1 → Shape, depth and motion"), the same
/// values the prototypes use. Respect reduced motion: read
/// `MediaQuery.disableAnimationsOf(context)` and pass [Duration.zero].
class AppMotion {
  AppMotion._();

  /// Colour, opacity, small state changes.
  static const Duration state = Duration(milliseconds: 250);
  /// Size and position changes, selection.
  static const Duration layout = Duration(milliseconds: 400);
  /// Content arriving (cards rising in, sheets, page transitions).
  static const Duration arrive = Duration(milliseconds: 520);
  /// Press feedback.
  static const Duration press = Duration(milliseconds: 140);

  /// A loading state is held at least this long so it never flashes.
  static const Duration minLoading = Duration(milliseconds: 450);
  static const Duration toast = Duration(milliseconds: 3200);
  static const Duration toastWithAction = Duration(seconds: 5);

  static const Curve ease = Cubic(0.22, 1, 0.36, 1);
  /// Selection pops (easeOutBack).
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);

  static const double pressScale = 0.97;
}
