import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/core/glass.dart';
import 'package:xpense_traker/core/theme.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color fg, Color bg) {
  final a = _luminance(fg), b = _luminance(bg);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// The point of these tests.
///
/// A translucent surface has no fixed background, so its contrast is normally
/// unassertable — audits measured shipped Liquid Glass surfaces at ~1.5:1 for
/// exactly this reason, and this app already shipped 2.11:1 text once by
/// blending a colour over an assumed backdrop.
///
/// The glass fill here carries enough alpha that the *worst case* is bounded:
/// whatever scrolls underneath, the resolved surface lies between "fill over
/// black" and "fill over white". Asserting both ends brackets every possible
/// backdrop, so the guarantee survives translucency.
void main() {
  final dark = AppPalette.of(Brightness.dark);
  final light = AppPalette.of(Brightness.light);

  for (final prominence in GlassProminence.values) {
    group('${prominence.name} glass is legible over any backdrop', () {
      test('dark: primary label clears AA at both extremes', () {
        final e = glassExtremes(dark, prominence);
        expect(contrast(dark.label, e.overBlack), greaterThan(4.5));
        expect(contrast(dark.label, e.overWhite), greaterThan(4.5));
      });

      test('light: primary label clears AA at both extremes', () {
        final e = glassExtremes(light, prominence);
        expect(contrast(light.label, e.overBlack), greaterThan(4.5));
        expect(contrast(light.label, e.overWhite), greaterThan(4.5));
      });

      test('dark: the accent clears the 3:1 graphics threshold either way', () {
        // Nav pill labels and icons are accent-coloured.
        final e = glassExtremes(dark, prominence);
        expect(contrast(dark.accent, e.overBlack), greaterThan(3.0));
        expect(contrast(dark.accent, e.overWhite), greaterThan(3.0));
      });

      test('the backdrop can move the surface only so far', () {
        // If the two extremes diverge wildly the fill is too transparent to
        // reason about, whatever the ratios happen to be today.
        final e = glassExtremes(dark, prominence);
        final spread =
            (_luminance(e.overWhite) - _luminance(e.overBlack)).abs();
        expect(spread, lessThan(0.16),
            reason: 'fill alpha too low — contrast would depend on scroll '
                'position rather than on the palette');
      });
    });
  }

  test('sheets are more opaque than bars', () {
    // Apple: larger elements appear more opaque "to preserve legibility over
    // complex backgrounds".
    final bar = glassFill(dark, GlassProminence.bar).a;
    final sheet = glassFill(dark, GlassProminence.sheet).a;
    expect(sheet, greaterThan(bar));
  });

  test('bigger surfaces blur harder', () {
    expect(GlassProminence.sheet.sigma,
        greaterThan(GlassProminence.appBar.sigma));
  });

  test('the disabled fallback resolves to a single opaque colour', () {
    // With transparency reduced there must be no dependence on the backdrop
    // at all — that is the whole point of the fallback.
    for (final p in [dark, light]) {
      for (final prom in GlassProminence.values) {
        final flat = Color.alphaBlend(glassFill(p, prom), p.bgBase);
        expect(flat.a, 1.0);
        expect(contrast(p.label, flat), greaterThan(4.5));
      }
    }
  });
}
