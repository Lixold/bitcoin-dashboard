import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/app_shell.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Reads the container of the running app so a test can drive settings the
/// way the settings screen does.
ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
      listen: false,
    );

/// The bar uppercases its labels, as the design system's `text-transform`
/// does.
Finder _destination(String label) => find.text(label.toUpperCase());

/// Index of the destination the bar marks as active.
int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  setUpTestHive(clearBetweenTests: true);

  testWidgets('app boots into the price section with its navigation', (
    tester,
  ) async {
    useView(tester, TestView.phone);

    await pumpAppRoot(tester);
    await tester.pump(); // first frame

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      _selectedIndex(tester),
      NavSection.visible().indexOf(NavSection.price),
    );
    // App title appears in the screen header.
    expect(find.text('Bitcoin Dashboard'), findsWidgets);
  });

  testWidgets('switching the theme does not reset the section', (tester) async {
    useView(tester, TestView.phone);

    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    // Leave the initial section.
    await tester.tap(_destination('Network'));
    await tester.pumpAndSettle();
    expect(
      _selectedIndex(tester),
      NavSection.visible().indexOf(NavSection.network),
    );

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

    expect(
      _selectedIndex(tester),
      NavSection.visible().indexOf(NavSection.network),
    );
    expect(find.byType(PriceScreen), findsNothing);
  });

  testWidgets('the section survives a restart and restore', (tester) async {
    useView(tester, TestView.phone);

    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    await tester.tap(_destination('Market'));
    await tester.pumpAndSettle();
    expect(
      _selectedIndex(tester),
      NavSection.visible().indexOf(NavSection.market),
    );

    // Tears the tree down, restores the platform restoration data, and pumps
    // a fresh app — the same path the OS takes after killing the process.
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(
      _selectedIndex(tester),
      NavSection.visible().indexOf(NavSection.market),
    );
    expect(find.byType(PriceScreen), findsNothing);
  });

  testWidgets('a fresh start without restoration data opens the home section', (
    tester,
  ) async {
    useView(tester, TestView.phone);

    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(
      _selectedIndex(tester),
      NavSection.visible().indexOf(NavSection.price),
    );
  });
}
