import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/data/settings_controller.dart';
import 'features/shell/home_shell.dart';
import 'l10n/generated/app_localizations.dart';

/// Root widget. Watches user settings (locale + theme mode) and rebuilds
/// MaterialApp accordingly. The settings notifier is the single source of
/// truth for app-wide preferences.
class BitcoinDashboardApp extends ConsumerWidget {
  const BitcoinDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
