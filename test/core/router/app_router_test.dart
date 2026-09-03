import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/core/router/app_router.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/dynamic_nav_pill.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/nav_bottom_sheet.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_screen.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

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

Finder _pillLabel(String label) => find.descendant(
  of: find.byType(DynamicNavPill),
  matching: find.text(label),
);

void main() {
  late Directory tempDir;
  late AppL10n l10n;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_router_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
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

      // Also pins the branch order: the shell reads the section back from the
      // branch index, so a reordered branch list would show the wrong pill.
      for (final section in NavSection.visible()) {
        router.go(section.location);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, section.location);
        expect(
          _pillLabel(section.label(l10n)),
          findsOneWidget,
          reason: 'pill should show ${section.id}',
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
      expect(_pillLabel('Forecast'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('/settings opens the settings screen outside the shell', (
      tester,
    ) async {
      await pumpAt(tester, settingsLocation);

      expect(find.byType(SettingsScreen), findsOneWidget);
      // No navigation chrome: settings is not a section.
      expect(find.byType(DynamicNavPill), findsNothing);
    });

    testWidgets('no control in the shell points at /settings', (tester) async {
      // The gear arrives with #64. Until then the route has no entry point,
      // and the sheet lists sections only.
      await pumpAt(tester, homeLocation);

      await tester.tap(find.byType(DynamicNavPill));
      await tester.pumpAndSettle();

      expect(find.byType(NavBottomSheet), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });
  });

  group('back gesture', () {
    testWidgets('closes the nav sheet instead of leaving the app', (
      tester,
    ) async {
      final router = await pumpAt(tester, NavSection.news.location);

      await tester.tap(find.byType(DynamicNavPill));
      await tester.pumpAndSettle();
      expect(find.byType(NavBottomSheet), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(NavBottomSheet), findsNothing);
      expect(router.state.uri.path, NavSection.news.location);
    });
  });
}
