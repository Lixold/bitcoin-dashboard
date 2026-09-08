import 'dart:async';

import 'package:bitcoin_dashboard/core/router/app_router.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/app_navigation.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_screen.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/harness.dart';

Widget _harness(GoRouter router) {
  return ProviderScope(
    overrides: [
      // Keep the test offline and deterministic: the live stream never emits.
      priceLiveProvider.overrideWith((ref) {
        final controller = StreamController<dynamic>();
        ref.onDispose(controller.close);
        return controller.stream.cast();
      }),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

/// Index of the destination the navigation marks as active. The tests below
/// run at a width where the rail is the expression; which expression appears
/// at which width is the navigation's own test.
int? _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

void main() {
  late AppL10n l10n;

  setUpTestHive();
  setUpAll(() async {
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = createAppRouter(initialLocation: location);
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();
    return router;
  }

  group('deep links', () {
    testWidgets('every reachable section has a route that opens it', (
      tester,
    ) async {
      final router = await pumpAt(tester, NavSection.price.location);

      // Also pins the branch order: the shell reads the section back from
      // the branch index, so a reordered branch list would mark the wrong
      // destination.
      for (final section in NavSection.visible()) {
        router.go(section.location);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, section.location);
        expect(
          _selectedIndex(tester),
          NavSection.visible().indexOf(section),
          reason: 'the navigation should mark ${section.id}',
        );
      }
    });

    testWidgets('/ opens the home section', (tester) async {
      final router = await pumpAt(tester, '/');

      expect(router.state.uri.path, homeLocation);
      expect(find.byType(PriceScreen), findsOneWidget);
    });

    testWidgets('a section without a shipped slice has no route and lands on '
        'the home section', (tester) async {
      // `forecast` and `miner` render a placeholder and cannot be reached from
      // the UI. They deliberately get no route (CLAUDE.md §5) — a typed URL
      // must not turn placeholder surface into a destination.
      final router = await pumpAt(tester, NavSection.forecast.location);

      expect(router.state.uri.path, homeLocation);
      expect(find.byType(PriceScreen), findsOneWidget);
      expect(find.text(l10n.navForecast.toUpperCase()), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('/settings opens the settings screen outside the shell', (
      tester,
    ) async {
      await pumpAt(tester, settingsLocation);

      expect(find.byType(SettingsScreen), findsOneWidget);
      // No navigation chrome: settings is not a section.
      expect(find.byType(AppNavigation), findsNothing);
    });

    testWidgets('the navigation does not list settings as a section', (
      tester,
    ) async {
      // The header's gear is the way in. The navigation lists sections
      // only — settings is a task, not a destination.
      await pumpAt(tester, homeLocation);

      expect(find.byType(AppNavigation), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppNavigation),
          matching: find.textContaining(
            RegExp(l10n.settingsTitle, caseSensitive: false),
          ),
        ),
        findsNothing,
      );
    });
  });

  group('back gesture', () {
    testWidgets('closes settings and returns to the section it was opened '
        'from', (tester) async {
      // Settings is pushed on top of the section rather than replacing it,
      // so the system back gesture has something to pop before it can
      // leave the app.
      final router = await pumpAt(tester, NavSection.news.location);

      router.push(settingsLocation);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(router.state.uri.path, NavSection.news.location);
    });
  });
}
