import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/dynamic_nav_pill.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _app() {
  return ProviderScope(
    overrides: [
      // Replace the live polling stream with one that never emits and
      // never schedules a Timer — keeps the smoke test deterministic
      // and offline-safe.
      priceLiveProvider.overrideWith((ref) {
        final controller = StreamController<dynamic>();
        ref.onDispose(controller.close);
        return controller.stream.cast();
      }),
    ],
    child: const BitcoinDashboardApp(),
  );
}

/// Reads the container of the running app so a test can drive settings the
/// way the settings screen does.
ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(DynamicNavPill)),
      listen: false,
    );

/// The nav sheet needs more room than the 800x600 default test view.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _pillLabel(String label) => find.descendant(
  of: find.byType(DynamicNavPill),
  matching: find.text(label),
);

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_hive_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
  });

  tearDown(() async {
    // Settings are persisted; a test that changes them must not leak into the
    // next one.
    await Hive.box<String>(SettingsController.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('app boots and shows the price screen with the floating pill', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(); // first frame

    expect(find.byType(DynamicNavPill), findsOneWidget);
    // App title appears in the screen header.
    expect(find.text('Bitcoin Dashboard'), findsWidgets);
  });

  testWidgets('switching the theme does not reset the section', (tester) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Leave the initial section.
    await tester.tap(find.byType(DynamicNavPill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Network').last);
    await tester.pumpAndSettle();
    expect(_pillLabel('Network'), findsOneWidget);

    // The root widget rebuilds on a theme change. The router must survive it:
    // built in `build()` it would be replaced and drop us back on /price.
    // `runAsync`: the settings notifier writes to Hive before it updates its
    // state, and a real file write does not complete inside the test's fake
    // async zone.
    final container = _containerOf(tester);
    await tester.runAsync(
      () => container
          .read(settingsControllerProvider.notifier)
          .setThemeMode(ThemeMode.light),
    );
    await tester.pumpAndSettle();

    expect(_pillLabel('Network'), findsOneWidget);
    expect(find.byType(PriceScreen), findsNothing);
  });

  testWidgets('the section survives a restart and restore', (tester) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DynamicNavPill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('News').last);
    await tester.pumpAndSettle();
    expect(_pillLabel('News'), findsOneWidget);

    // Tears the tree down, restores the platform restoration data, and pumps
    // a fresh app — the same path the OS takes after killing the process.
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_pillLabel('News'), findsOneWidget);
    expect(find.byType(PriceScreen), findsNothing);
  });

  testWidgets('a fresh start without restoration data opens the home section', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(_pillLabel('Price'), findsOneWidget);
  });
}
