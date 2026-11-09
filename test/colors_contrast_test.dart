import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_colors.dart';
import 'package:king_domain/presentation/widgets/kit/kd_card.dart';

/// WCAG contrast ratio between two opaque colours.
double _ratio(Color a, Color b) {
  double lum(Color c) {
    double f(double v) => v <= 0.03928 ? v / 12.92 : _pow((v + 0.055) / 1.055, 2.4);
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }

  final la = lum(a), lb = lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _pow(double x, double y) => _exp(y * _ln(x));
double _ln(double x) {
  // Series for ln via atanh; accurate enough for the 0.03 to 1 range used here.
  final z = (x - 1) / (x + 1);
  var sum = 0.0, term = z;
  for (var n = 1; n < 400; n += 2) {
    sum += term / n;
    term *= z * z;
  }
  return 2 * sum;
}

double _exp(double x) {
  var sum = 1.0, term = 1.0;
  for (var n = 1; n < 60; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}

void main() {
  const surfaces = {
    'ground': AppColors.ground,
    'surface 1': AppColors.surface1,
    'surface 2': AppColors.surface2,
    'surface 3': AppColors.surface3,
  };
  final tinted = {for (final t in [KdTone.ok, KdTone.warn, KdTone.bad, KdTone.brand]) 'a ${t.name} card': toneSurface(t)};
  final everywhere = {...surfaces, ...tinted};

  group('text is readable (WCAG AA, 4.5:1) wherever it can sit', () {
    final inks = {
      'text': AppColors.text,
      'text 2': AppColors.text2,
      'text 3 (hints, timestamps)': AppColors.text3,
      'violet text': AppColors.primaryText,
      'verified green': AppColors.ok,
      'waiting amber': AppColors.warn,
      'error red': AppColors.bad,
      'money gold': AppColors.money,
    };
    for (final ink in inks.entries) {
      test(ink.key, () {
        for (final where in everywhere.entries) {
          expect(_ratio(ink.value, where.value), greaterThanOrEqualTo(4.5), reason: '${ink.key} on ${where.key}');
        }
      });
    }

    test('white on the violet button fill', () => expect(_ratio(AppColors.onPrimary, AppColors.primary), greaterThanOrEqualTo(4.5)));
  });

  group('sections read as sections', () {
    test('each surface is visibly lighter than the one it sits on', () {
      expect(_ratio(AppColors.ground, AppColors.surface1), greaterThanOrEqualTo(1.08), reason: 'a card on the page');
      expect(_ratio(AppColors.surface1, AppColors.surface2), greaterThanOrEqualTo(1.1), reason: 'a tile inside a card');
      expect(_ratio(AppColors.surface2, AppColors.surface3), greaterThanOrEqualTo(1.15), reason: 'a selected or pressed row');
    });

    test('a tinted card is never darker than a plain card (it used to be, drawn over the page)', () {
      double lum(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      for (final t in tinted.entries) {
        expect(lum(t.value), greaterThan(lum(AppColors.surface1) - 1e-9), reason: t.key);
      }
    });

    test('a tinted card is opaque, so what is behind it never changes how it reads', () {
      for (final t in tinted.entries) {
        expect(t.value.a, 1.0, reason: t.key);
      }
    });
  });
}
