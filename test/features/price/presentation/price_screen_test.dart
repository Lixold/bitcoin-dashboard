import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_tick.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _harness({
  required Widget child,
  Size size = const Size(420, 900),
}) {
  return ProviderScope(
    overrides: [
      priceLiveProvider.overrideWith((ref) {
        final controller = StreamController<PriceTick>();
        ref.onDispose(controller.close);
        controller.add(
          PriceTick(
            symbol: 'BTCUSDT',
            price: 96442.50,
            observedAt: DateTime.utc(2026, 5, 14, 14, 32),
          ),
        );
        return controller.stream;
      }),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_price_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('renders header, hero, chart, and metric cards on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(child: const PriceScreen()));
    await tester.pump();

    expect(find.text('Bitcoin Dashboard'), findsOneWidget);
    expect(find.text('Market evolution'), findsOneWidget);
    expect(find.text('Market data'), findsOneWidget);
    expect(find.text('All-time high'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    // Phone width — sidebar must not render.
    expect(find.text('Market insights'), findsNothing);
  });

  testWidgets('shows the sidebar insights card on a wide layout',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(child: const PriceScreen()));
    await tester.pump();

    expect(find.text('Market insights'), findsOneWidget);
  });
}
