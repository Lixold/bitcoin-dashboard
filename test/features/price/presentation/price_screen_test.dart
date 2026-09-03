import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_tick.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _harness({required Widget child, Size size = const Size(420, 900)}) {
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

  testWidgets('renders the header and the live price hero', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(child: const PriceScreen()));
    await tester.pump();

    expect(find.text('Bitcoin Dashboard'), findsOneWidget);
    expect(find.textContaining(r'$96,442.50'), findsOneWidget);
  });

  testWidgets('the live price renders in the hero figure role', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(child: const PriceScreen(), size: const Size(390, 844)),
    );
    await tester.pump();

    // The role, not the family: the family depends on the platform and
    // is substituted by the test font manager anyway.
    final hero = tester.widget<Text>(find.textContaining(r'$96,442.50'));
    expect(hero.style?.height, isNull);
    expect(hero.style?.fontFeatures, AppTypography.figureFeatures);
    expect(hero.style?.fontWeight, AppTypography.displayHero.fontWeight);
  });

  testWidgets('the hero scales with the window it is rendered in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Three points on the design system's clamp(48px, 10vw, 80px): a
    // phone under the floor, a window inside the range, a desktop frame
    // over the ceiling. A fixed hero size would fail two of them.
    for (final probe in <(Size, double)>[
      (const Size(390, 844), AppTypography.heroMinFontSize),
      (const Size(640, 900), 64),
      (const Size(1200, 900), AppTypography.heroMaxFontSize),
    ]) {
      final (size, expected) = probe;
      await tester.pumpWidget(_harness(child: const PriceScreen(), size: size));
      await tester.pump();

      final hero = tester.widget<Text>(find.textContaining(r'$96,442.50'));
      expect(
        hero.style?.fontSize,
        expected,
        reason: 'hero at a ${size.width.toInt()} px window',
      );
    }
  });
}
