import 'package:flutter/material.dart';

/// Material 3 themes with a Bitcoin-orange seed.
///
/// We deliberately keep the surface palette neutral (close to the seed's
/// generated tonal palette) and rely on Material 3 dynamic role colours.
class AppTheme {
  AppTheme._();

  /// Bitcoin orange — used as the seed for the M3 colour scheme.
  static const Color seed = Color(0xFFF7931A);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
