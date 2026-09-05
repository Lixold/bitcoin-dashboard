import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/widgets/app_header.dart';
import 'package:bitcoin_dashboard/core/widgets/brand_icon.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The whole app, with the live price stream replaced by one that never
/// emits — the header is what is under test, not the price.
Widget _app() {
  return ProviderScope(
    overrides: [
      priceLiveProvider.overrideWith((ref) {
        final controller = StreamController<dynamic>();
        ref.onDispose(controller.close);
        return controller.stream.cast();
      }),
    ],
    child: const BitcoinDashboardApp(),
  );
}

Finder _gearIcon = find.descendant(
  of: find.byType(AppHeader),
  matching: find.byType(BrandIcon),
);

BrandIcon _gear(WidgetTester tester) => tester.widget<BrandIcon>(_gearIcon);

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_header_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
  });

  tearDown(() async {
    await Hive.box<String>(SettingsController.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('the header names the app, never the section', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppHeader),
        matching: find.text('Bitcoin Dashboard'),
      ),
      findsOneWidget,
    );
    // The section name belongs to the navigation, not to the header.
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('Price')),
      findsNothing,
    );
  });

  testWidgets('the gear opens settings and closes it again', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);

    // The gear is the way back out: on the settings screen it marks the
    // open screen, and tapping it returns to the section it was opened
    // from. Without that it would be a control that does nothing.
    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('the pill is on the section header and not on settings', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // USD is the first-launch default in AppSettings.defaults().
    expect(find.text('USD / BTC'), findsOneWidget);

    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    // The currency is set on this screen, so the pill would be stating
    // what the row below it already says.
    expect(find.text('USD / BTC'), findsNothing);
  });

  testWidgets('the gear marks the settings screen while it is open', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_gear(tester).color, AppColors.lightOnSurfaceVariant);

    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    expect(_gear(tester).color, AppColors.primary);
  });

  testWidgets('the header keeps its composition across the breakpoints', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    // A phone, a tablet and a desktop window: 768 and 1024 are where the
    // navigation changes shape (#65), and the header does not follow it.
    for (final width in <double>[390, 900, 1400]) {
      tester.view.physicalSize = Size(width, 1000);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(_gearIcon, findsOneWidget, reason: 'gear at $width px');
      expect(
        find.text('USD / BTC'),
        findsOneWidget,
        reason: 'currency pill at $width px',
      );
    }
  });
}
