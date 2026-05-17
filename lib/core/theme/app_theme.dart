import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Material 3 themes built from the Bitcoin Dashboard design system.
///
/// Dark mode is the canonical surface; light mode mirrors the same tokens
/// with inverted neutrals. Colours come from [AppColors] and the text
/// theme threads [AppTypography] families into the M3 roles.
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
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.displayHero.copyWith(color: scheme.onSurface),
        displayMedium: AppTypography.displayLarge.copyWith(color: scheme.onSurface),
        displaySmall: AppTypography.displayMedium.copyWith(color: scheme.onSurface),
        headlineMedium: AppTypography.displayLarge.copyWith(color: scheme.onSurface),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: scheme.onSurface),
        bodySmall: AppTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        labelLarge: AppTypography.monoCaption.copyWith(color: scheme.onSurfaceVariant),
        labelMedium: AppTypography.monoLabel.copyWith(color: scheme.onSurfaceVariant),
        labelSmall: AppTypography.monoLabel.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
