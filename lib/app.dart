import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
    final router = ref.watch(appRouterProvider);

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
      routerConfig: router,
      // The menu bar wraps the app content rather than the router: it has
      // to sit inside `Localizations` to label itself, and it must not be
      // rebuilt by navigation.
      builder: (context, child) => AppPlatformMenus(
        onOpenSettings: () => router.push(settingsLocation),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// The application menu, on the one platform that has one.
///
/// macOS puts preferences in the app menu behind ⌘, and users expect it
/// there; the other four targets have no such menu, so on them this widget
/// is its [child] and nothing else. `Quit` is declared alongside because a
/// declared app menu replaces the default one — leaving it out would take
/// ⌘Q with it.
///
/// The check is `kIsWeb` first: on the web `defaultTargetPlatform` reports
/// the host operating system, so a browser on a Mac would otherwise try to
/// install a native menu bar.
class AppPlatformMenus extends StatelessWidget {
  const AppPlatformMenus({
    super.key,
    required this.onOpenSettings,
    required this.child,
  });

  final VoidCallback onOpenSettings;
  final Widget child;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return child;

    final l10n = AppL10n.of(context);

    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: l10n.appTitle,
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: l10n.settingsTitle,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
              onSelected: onOpenSettings,
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
