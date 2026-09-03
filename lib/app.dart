import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/data/settings_controller.dart';
import 'l10n/generated/app_localizations.dart';

/// Root widget. Watches user settings (locale + theme mode) and rebuilds
/// MaterialApp accordingly. The settings notifier is the single source of
/// truth for app-wide preferences.
///
/// The router comes from [appRouterProvider] and is therefore built once,
/// not per build: constructing it here would reset navigation to the initial
/// location on every locale or theme change.
class BitcoinDashboardApp extends ConsumerWidget {
  const BitcoinDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Enables Flutter's state restoration, which the router hooks into to
      // bring the user back to the section they were in.
      restorationScopeId: 'bitcoin_dashboard',
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
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
