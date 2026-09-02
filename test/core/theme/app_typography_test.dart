import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests assert what each role *is*, never which face renders it.
/// The resolved family depends on the platform the app runs on and on
/// which optional font packs are installed there, so a family assertion
/// would pass in CI and still say nothing about a user's screen.
void main() {
  group('figure roles', () {
    test('updating figures carry lining and tabular features', () {
      expect(
        AppTypography.figureFeatures,
        containsAll(<FontFeature>[
          const FontFeature.liningFigures(),
          const FontFeature.tabularFigures(),
        ]),
      );
    });

    test('mono roles that render figures declare both features', () {
      for (final style in <TextStyle>[
        AppTypography.monoValue,
        AppTypography.monoCaption,
      ]) {
        expect(style.fontFeatures, AppTypography.figureFeatures);
      }
    });

    test('display figure roles pin no line height', () {
      // A height near 1.0 clips the taller platform faces. These roles
      // take the resolved face's own metrics instead.
      expect(AppTypography.displayHero.height, isNull);
      expect(AppTypography.displayLarge.height, isNull);
      expect(AppTypography.monoValue.height, isNull);
    });
  });

  group('role sizes', () {
    test('hero is the 64 px price role', () {
      expect(AppTypography.displayHero.fontSize, 64);
      expect(AppTypography.displayHero.fontWeight, FontWeight.w500);
    });

    test('card metrics are the 32/500 display role', () {
      expect(AppTypography.displayLarge.fontSize, 32);
      expect(AppTypography.displayLarge.fontWeight, FontWeight.w500);
    });

    test('mono value is the 14 px unit and delta role', () {
      expect(AppTypography.monoValue.fontSize, 14);
    });
  });

  group('font declaration', () {
    test('display and mono roles resolve through a fallback chain', () {
      for (final style in <TextStyle>[
        AppTypography.displayHero,
        AppTypography.displayLarge,
        AppTypography.displayMedium,
        AppTypography.monoValue,
        AppTypography.monoCaption,
        AppTypography.monoLabel,
      ]) {
        // No single bundled family: the chain is the declaration.
        expect(style.fontFamily, isNull);
        expect(style.fontFamilyFallback, isNotEmpty);
      }
    });

    test('body roles declare no family and keep the platform sans', () {
      for (final style in <TextStyle>[
        AppTypography.bodyLarge,
        AppTypography.bodyMedium,
        AppTypography.bodySmall,
      ]) {
        expect(style.fontFamily, isNull);
        expect(style.fontFamilyFallback, isNull);
      }
    });
  });
}
