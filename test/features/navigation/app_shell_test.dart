import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/app_shell.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/dynamic_nav_pill.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/nav_bottom_sheet.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _harness() {
  return ProviderScope(
    overrides: [
      // Keep the test offline and deterministic: the live stream never emits.
      priceLiveProvider.overrideWith((ref) {
        final controller = StreamController<dynamic>();
        ref.onDispose(controller.close);
        return controller.stream.cast();
      }),
    ],
    child: MaterialApp(
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
      home: const AppShell(),
    ),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_shell_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('boots into the Price section with the pill labelled "Price"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DynamicNavPill),
        matching: find.text('Price'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the pill opens the bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(NavBottomSheet), findsNothing);

    await tester.tap(find.byType(DynamicNavPill));
    await tester.pumpAndSettle();

    expect(find.byType(NavBottomSheet), findsOneWidget);
  });

  testWidgets(
    'selecting Network swaps the body, updates the pill, and closes the sheet',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness());
      await tester.pump();

      await tester.tap(find.byType(DynamicNavPill));
      await tester.pumpAndSettle();

      // The sheet tile for Network. Two "Network" texts can co-exist after
      // selection (sheet during teardown, pill, body) — disambiguate by
      // tapping the descendant inside the sheet.
      final networkInSheet = find.descendant(
        of: find.byType(NavBottomSheet),
        matching: find.text('Network'),
      );
      expect(networkInSheet, findsOneWidget);

      await tester.tap(networkInSheet);
      await tester.pumpAndSettle();

      // Sheet is gone, body swapped to the Network placeholder, pill updated.
      expect(find.byType(NavBottomSheet), findsNothing);
      expect(find.byType(PriceScreen), findsNothing);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DynamicNavPill),
          matching: find.text('Network'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the sheet only exposes the four Phase-3 sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.byType(DynamicNavPill));
    await tester.pumpAndSettle();

    final sheet = find.byType(NavBottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Price')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Market')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Network')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('News')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Forecast')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Miner')),
      findsNothing,
    );
  });
}
