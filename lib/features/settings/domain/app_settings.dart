import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show ThemeMode;

/// User-facing app settings. Persisted in Hive via [SettingsController].
///
/// Kept deliberately small — only what affects rendering globally. Per-feature
/// settings (e.g. selected news languages) live in their own provider.
class AppSettings {
  const AppSettings({
    required this.locale,
    required this.themeMode,
    required this.fiatCurrency,
  });

  /// Sensible defaults for the very first launch.
  factory AppSettings.defaults() => const AppSettings(
    locale: Locale('en'),
    themeMode: ThemeMode.system,
    fiatCurrency: 'USD',
  );

  final Locale locale;
  final ThemeMode themeMode;

  /// ISO 4217 code, e.g. `EUR`, `USD`. Conversion is client-side via the
  /// FX-rates JSON on the CDN (see ADR-002).
  final String fiatCurrency;

  AppSettings copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    String? fiatCurrency,
  }) => AppSettings(
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    fiatCurrency: fiatCurrency ?? this.fiatCurrency,
  );
}
