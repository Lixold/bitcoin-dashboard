import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/app_settings.dart';

/// Persisted, app-wide settings. Backed by a single Hive box so we avoid
/// pulling in a serialiser just for three primitive fields.
///
/// `build()` runs synchronously because [main] opens the box before the
/// first frame; the UI never sees an uninitialised state.
class SettingsController extends Notifier<AppSettings> {
  /// Hive box name. Pre-opened in [main].
  static const String boxName = 'settings_v1';

  static const String _kLocale = 'locale';
  static const String _kThemeMode = 'themeMode';
  static const String _kFiatCurrency = 'fiatCurrency';

  // All settings values are strings (language tag, theme mode name,
  // currency code). Typing the box statically removes four `as String?`
  // casts further down and lets the analyzer flag any accidental
  // non-string write before runtime.
  Box<String> get _box => Hive.box<String>(boxName);

  @override
  AppSettings build() {
    final defaults = AppSettings.defaults();
    return AppSettings(
      locale: _readLocale() ?? defaults.locale,
      themeMode: _readThemeMode() ?? defaults.themeMode,
      fiatCurrency: _box.get(_kFiatCurrency) ?? defaults.fiatCurrency,
    );
  }

  // -- mutations -----------------------------------------------------------

  Future<void> setLocale(Locale locale) async {
    await _box.put(_kLocale, locale.toLanguageTag());
    state = state.copyWith(locale: locale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_kThemeMode, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setFiatCurrency(String code) async {
    await _box.put(_kFiatCurrency, code);
    state = state.copyWith(fiatCurrency: code);
  }

  // -- decoding helpers ----------------------------------------------------

  Locale? _readLocale() {
    final raw = _box.get(_kLocale);
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    return parts.length == 1 ? Locale(parts[0]) : Locale(parts[0], parts[1]);
  }

  ThemeMode? _readThemeMode() {
    final raw = _box.get(_kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }
}

/// Provider for [SettingsController]. App-wide singleton.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
