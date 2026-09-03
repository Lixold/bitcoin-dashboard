import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests lock the mapping of the app's display roles onto the
/// Material 3 slots. The mapping is by size, so an assertion here reads
/// as "this slot carries that role", never as a repeated size literal —
/// a size change in [AppTypography] should move both sides together.
void main() {
  final themes = <String, ThemeData>{
    'dark': AppTheme.dark(),
    'light': AppTheme.light(),
  };

  themes.forEach((name, theme) {
    group('$name text theme', () {
      final text = theme.textTheme;

      test('the display roles sit on the slots that match them by size', () {
        expect(text.displayLarge?.fontSize, AppTypography.displayHero.fontSize);
        expect(
          text.headlineLarge?.fontSize,
          AppTypography.displayLarge.fontSize,
        );
        expect(
          text.headlineSmall?.fontSize,
          AppTypography.displayMedium.fontSize,
        );
        expect(text.titleLarge?.fontSize, AppTypography.displaySmall.fontSize);
      });

      test('those four slots carry the serif stack at weight 500', () {
        for (final style in <TextStyle?>[
          text.displayLarge,
          text.headlineLarge,
          text.headlineSmall,
          text.titleLarge,
        ]) {
          expect(style?.fontFamilyFallback, AppTypography.displayStack);
          expect(style?.fontWeight, FontWeight.w500);
          expect(style?.color, theme.colorScheme.onSurface);
        }
      });

      test('no slot below the hero carries a display role by name', () {
        // The mapping used to shift the names one step, which put the 32
        // role on `displayMedium` and the 24 role on `displaySmall` — so
        // `theme.textTheme.displayMedium` and `AppTypography.displayMedium`
        // were two different sizes. These slots keep their Material
        // defaults now; nothing in the app reads them.
        expect(
          text.displayMedium?.fontSize,
          isNot(AppTypography.displayLarge.fontSize),
        );
        expect(
          text.displaySmall?.fontSize,
          isNot(AppTypography.displayMedium.fontSize),
        );
        expect(
          text.headlineMedium?.fontSize,
          isNot(AppTypography.displayLarge.fontSize),
        );
      });
    });
  });
}
