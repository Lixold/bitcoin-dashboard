import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Material 3 themes built from the Bitcoin Dashboard design system.
///
/// Dark mode is the canonical surface; light mode mirrors the same tokens
/// with inverted neutrals. Colours come from [AppColors] and the text
/// theme threads [AppTypography] roles into the M3 slots.
class AppTheme {
  AppTheme._();

  /// Bitcoin orange — used as the seed for the M3 colour scheme.
  static const Color seed = AppColors.primary;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      secondary: AppColors.primary,
      onSecondary: isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      error: isDark ? AppColors.darkError : AppColors.lightError,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
      surfaceContainerHighest: isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.lightSurfaceVariant,
      onSurfaceVariant: isDark
          ? AppColors.darkOnSurfaceVariant
          : AppColors.lightOnSurfaceVariant,
      outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
    );

    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      // The display roles sit on the M3 slots that match them **by size**,
      // not by the matching name. Lining the names up one-for-one is what
      // made the two `displayMedium`s — the app's and the text theme's —
      // different sizes, so a widget reading one was never reading the
      // other:
      //
      //   AppTypography.displayHero    48-80  ->  displayLarge   (M3 57)
      //   AppTypography.displayLarge      32  ->  headlineLarge  (M3 32)
      //   AppTypography.displayMedium     24  ->  headlineSmall  (M3 24)
      //   AppTypography.displaySmall      18  ->  titleLarge     (M3 22)
      //
      // Two consequences of that, both checked rather than assumed:
      //
      //   * `displayMedium`, `displaySmall` and `headlineMedium` keep
      //     their Material defaults (45 / 36 / 28, platform sans). No app
      //     role is that big, and nothing reads those slots. A read that
      //     lands there is outside the design system — move it onto one
      //     of the four above rather than filling the slot with an
      //     invented size.
      //   * `titleLarge` also backs the M3 app bar title, so the settings
      //     screen's title renders in the app's smallest display role
      //     instead of the stock sans.
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.displayHero.copyWith(
          color: scheme.onSurface,
        ),
        headlineLarge: AppTypography.displayLarge.copyWith(
          color: scheme.onSurface,
        ),
        headlineSmall: AppTypography.displayMedium.copyWith(
          color: scheme.onSurface,
        ),
        titleLarge: AppTypography.displaySmall.copyWith(
          color: scheme.onSurface,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: scheme.onSurface),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: AppTypography.monoCaption.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelMedium: AppTypography.monoLabel.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelSmall: AppTypography.monoLabel.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
