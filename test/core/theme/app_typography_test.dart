import 'package:bitcoin_dashboard/core/theme/app_spacing.dart';
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
      expect(AppTypography.displayMedium.height, isNull);
      expect(AppTypography.displaySmall.height, isNull);
      expect(AppTypography.monoValue.height, isNull);
    });
  });

  group('role sizes', () {
    test('card metrics are the 32/500 display role', () {
      expect(AppTypography.displayLarge.fontSize, 32);
      expect(AppTypography.displayLarge.fontWeight, FontWeight.w500);
    });

    test('section titles are the 24/500 display role', () {
      expect(AppTypography.displayMedium.fontSize, 24);
      expect(AppTypography.displayMedium.fontWeight, FontWeight.w500);
    });

    test('model names are the 18/500 display role', () {
      expect(AppTypography.displaySmall.fontSize, 18);
      expect(AppTypography.displaySmall.fontWeight, FontWeight.w500);
    });

    test('mono value is the 14 px unit and delta role', () {
      expect(AppTypography.monoValue.fontSize, 14);
    });

    test('the body ramp is 16 / 14 / 13, the platform sizes', () {
      // #82 decided this direction: the design system took the
      // repository's sizes, the repository did not take the mockups'
      // 15 px prose. A 15 reappearing here — as a fourth role or in place
      // of one of these — is that decision being undone.
      expect(
        <double?>[
          AppTypography.bodyLarge.fontSize,
          AppTypography.bodyMedium.fontSize,
          AppTypography.bodySmall.fontSize,
        ],
        <double>[16, 14, 13],
      );
    });

    test('the prose role steps on the spacing grid', () {
      // 16 x 1.5 = 24 = AppSpacing.s5. This is what the design system's
      // 15 px stood for, and the only number #82 moved: a wrapped
      // paragraph has to advance by a spacing step, not by 22.4.
      expect(
        AppTypography.bodyLarge.fontSize! * AppTypography.bodyLarge.height!,
        AppSpacing.s5,
      );
    });

    test('the display roles descend without a gap or a tie', () {
      // The mapping in AppTheme assigns these by size. Two roles that
      // meet, or that swap order, would put one of them on the wrong
      // Material slot.
      expect(
        <double?>[
          AppTypography.heroFontSize(640),
          AppTypography.displayLarge.fontSize,
          AppTypography.displayMedium.fontSize,
          AppTypography.displaySmall.fontSize,
        ],
        <double>[64, 32, 24, 18],
      );
    });
  });

  group('hero size', () {
    test('scales with the viewport at 10vw', () {
      expect(AppTypography.heroFontSize(500), 50);
      expect(AppTypography.heroFontSize(640), 64);
      expect(AppTypography.heroFontSize(700), 70);
    });

    test('clamps to 48 below the range and 80 above it', () {
      // A phone frame sits under the floor, a desktop frame over the
      // ceiling — the two ends a fixed 64 got wrong.
      expect(AppTypography.heroFontSize(390), AppTypography.heroMinFontSize);
      expect(AppTypography.heroFontSize(0), AppTypography.heroMinFontSize);
      expect(AppTypography.heroFontSize(1200), AppTypography.heroMaxFontSize);
      expect(AppTypography.heroFontSize(3840), AppTypography.heroMaxFontSize);
    });

    test('the bounds are continuous with the 10vw slope', () {
      expect(AppTypography.heroFontSize(480), AppTypography.heroMinFontSize);
      expect(AppTypography.heroFontSize(800), AppTypography.heroMaxFontSize);
    });
  });

  group('font declaration', () {
    test('display and mono roles resolve through a fallback chain', () {
      for (final style in <TextStyle>[
        AppTypography.displayHero,
        AppTypography.displayLarge,
        AppTypography.displayMedium,
        AppTypography.displaySmall,
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
