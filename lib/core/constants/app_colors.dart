import 'package:flutter/material.dart';

/// Brand v1, Royal Violet (CLAUDE.md "Brand — v1", prototypes/palette-explorer.html).
/// Depth is tonal: each surface is one step lighter than what it sits on.
/// Every colour has one job; see the role on each token. Change values here
/// only, so the app and the prototypes stay in step.
class AppColors {
  AppColors._();

  // Surfaces, darkest to lightest.
  static const Color ground = Color(0xFF0D0A16);
  static const Color surface1 = Color(0xFF151121); // cards, list groups, inputs
  static const Color surface2 = Color(0xFF1D182E); // raised: tiles in cards, sheets, tab bar
  static const Color surface3 = Color(0xFF27203D); // toasts, pressed/selected, shimmer
  /// Dividers inside a surface only, never card outlines.
  static const Color line = Color(0x0FFFFFFF);

  static const Color text = Color(0xFFF2EFFA);
  static const Color text2 = Color(0xFFABA4C3);
  static const Color text3 = Color(0xFF716A8B);

  /// "You can act": primary button fill, active tab, progress.
  static const Color primary = Color(0xFF7451F2);
  static const Color onPrimary = Color(0xFFFFFFFF);
  /// Violet as text or icons on dark (the fill violet is too dark for text).
  static const Color primaryText = Color(0xFFA991FF);
  static const Color primarySoft = Color(0x298C6CFF);
  /// Soft shadow under the single primary button on a screen. Nothing else glows.
  static const Color primaryGlow = Color(0x617451F2);

  /// Money only (budgets, earnings, payouts) and the logomark.
  static const Color money = Color(0xFFF2C14E);
  /// Verified, done, paid.
  static const Color ok = Color(0xFF34D399);
  static const Color okSoft = Color(0x2134D399);
  /// Waiting on someone: pending, extension requested, deadline near.
  static const Color warn = Color(0xFFF5A55B);
  static const Color warnSoft = Color(0x21F5A55B);
  /// Errors, destructive actions, missed deadlines.
  static const Color bad = Color(0xFFF87171);
  static const Color badSoft = Color(0x21F87171);

  // ── Legacy brand v0 names, aliased so every screen picks up v1 at once.
  // A screen moves to the names above when it is rebuilt; delete these once
  // nothing in lib/ uses them any more.
  static const Color ink = ground;
  static const Color ink2 = surface1;
  static const Color ink3 = surface3; // v0 card outlines; v1 has none
  static const Color paper = text;
  static const Color paper2 = text2;
  static const Color gold = primary; // actions; amounts should use money
  static const Color goldSoft = primaryText;
  static const Color signalGreen = ok;
  static const Color greenSoft = ok;
  static const Color slate = text2;
  static const Color slateDim = text3;
  static const Color openPending = warn; // errors should use bad
  static const Color settled = ok;
}
