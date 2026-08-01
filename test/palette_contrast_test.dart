import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/core/theme.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two OPAQUE colours.
double contrast(Color fg, Color bg) {
  final a = _luminance(fg), b = _luminance(bg);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// Flattens a translucent foreground onto an opaque background, which is what
/// the eye actually sees — comparing a translucent colour directly would
/// silently overstate its contrast.
Color flatten(Color fg, Color bg) => Color.alphaBlend(fg, bg);

void main() {
  final light = AppPalette.of(Brightness.light);
  final dark = AppPalette.of(Brightness.dark);

  group('dark theme is comfortable, not maximal', () {
    test('primary text is well below the 19.7:1 of pure white on near-black',
        () {
      final ratio = contrast(dark.label, dark.bgBase);
      // The original complaint was #FFFFFF on #0B0B0C = 19.67:1.
      expect(ratio, lessThan(16.0),
          reason: 'primary text should not be maximal-contrast glare');
      expect(ratio, greaterThan(7.0), reason: 'still AAA legible');
    });

    test('primary text stays legible on every surface in the ramp', () {
      for (final bg in [dark.bgBase, dark.bgCard, dark.bgRaised]) {
        expect(contrast(dark.label, bg), greaterThan(7.0));
      }
    });

    test('the elevation ramp is strictly increasing in lightness', () {
      final steps = [dark.bgBase, dark.bgCard, dark.bgRaised, dark.bgOverlay];
      for (var i = 1; i < steps.length; i++) {
        expect(_luminance(steps[i]), greaterThan(_luminance(steps[i - 1])),
            reason: 'surface level $i must read as raised above level ${i - 1}');
      }
    });
  });

  group('text hierarchy meets WCAG AA where it carries meaning', () {
    test('secondary label is AA on page and card', () {
      expect(contrast(flatten(dark.labelSecondary, dark.bgBase), dark.bgBase),
          greaterThan(4.5));
      expect(contrast(flatten(dark.labelSecondary, dark.bgCard), dark.bgCard),
          greaterThan(4.5));
      expect(contrast(flatten(light.labelSecondary, light.bgBase), light.bgBase),
          greaterThan(4.5));
    });

    test('placeholder does not regress against the old inkSubtle (3.80:1)', () {
      // Guards the deliberate choice of 0.45 over Apple's tertiary 0.30 —
      // these sites include real hint text, so 0.30 (2.48:1) would be a
      // regression shipped under an accessibility banner.
      final ratio =
          contrast(flatten(dark.placeholder, dark.bgBase), dark.bgBase);
      expect(ratio, greaterThan(3.80));
    });
  });

  group('accent is usable and not glaring', () {
    test('dark accent is dimmer than the raw brand colour', () {
      final raw = contrast(AppBrand.green, dark.bgBase);
      final derived = contrast(dark.accent, dark.bgBase);
      expect(derived, lessThan(raw),
          reason: 'dark mode must desaturate/dim the brand lime');
      expect(derived, greaterThan(3.0),
          reason: 'still meets the 3:1 graphics threshold');
    });

    test('onAccent is readable on accent in both themes', () {
      expect(contrast(dark.onAccent, dark.accent), greaterThan(4.5));
      expect(contrast(light.onAccent, light.accent), greaterThan(4.5));
    });

    test('onAccentSoft is readable on accentSoft in both themes', () {
      // This is the bug being fixed: black on dark greenSoft is ~2.1:1 today.
      expect(contrast(dark.onAccentSoft, dark.accentSoft), greaterThan(4.5));
      expect(contrast(light.onAccentSoft, light.accentSoft), greaterThan(4.5));
    });

    test('onDanger is readable on danger in both themes', () {
      expect(contrast(dark.onDanger, dark.danger), greaterThan(4.5));
      expect(contrast(light.onDanger, light.danger), greaterThan(4.5));
    });
  });

  group('light mode must not move', () {
    test('card and page are the same surface, as today', () {
      expect(light.bgCard, equals(light.bgBase));
      expect(light.bgBase, equals(const Color(0xFFFFFFFF)));
    });

    test('the brand accent is untouched in light mode', () {
      expect(light.accent, equals(AppBrand.green));
    });

    test('primary ink is still pure black', () {
      expect(light.label, equals(const Color(0xFF000000)));
    });

    test('secondary/placeholder keep their existing alphas', () {
      expect(light.labelSecondary.a, closeTo(0.60, 0.001));
      expect(light.placeholder.a, closeTo(0.38, 0.001));
    });
  });
}
