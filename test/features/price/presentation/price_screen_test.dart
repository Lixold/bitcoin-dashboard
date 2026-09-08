import 'dart:async';

import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_tick.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

final PriceTick _tick = PriceTick(
  symbol: 'BTCUSDT',
  price: 96442.50,
  observedAt: DateTime.utc(2026, 5, 14, 14, 32),
);

/// One tick on the wire, then silence — the harness's default stream never
/// emits, and this screen has a price to render.
Stream<PriceTick> _oneTick(Ref ref) {
  final controller = StreamController<PriceTick>();
  ref.onDispose(controller.close);
  controller.add(_tick);
  return controller.stream;
}

Future<void> _pumpPrice(WidgetTester tester) => pumpApp(
  tester,
  child: const PriceScreen(),
  overrides: [priceLiveProvider.overrideWith(_oneTick)],
);

void main() {
  setUpTestHive();

  testWidgets('renders the header and the live price hero', (tester) async {
    useView(tester, TestView.phone);

    await _pumpPrice(tester);
    await tester.pump();

    expect(find.text('Bitcoin Dashboard'), findsOneWidget);
    expect(find.textContaining(r'$96,442.50'), findsOneWidget);
  });

  testWidgets('the live price renders in the hero figure role', (tester) async {
    useView(tester, TestView.phone);

    await _pumpPrice(tester);
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
    // Three points on the design system's clamp(48px, 10vw, 80px): a
    // phone under the floor, a window inside the range, a desktop frame
    // over the ceiling. A fixed hero size would fail two of them.
    for (final probe in <(Size, double)>[
      (const Size(390, 844), AppTypography.heroMinFontSize),
      (const Size(640, 900), 64),
      (const Size(1200, 900), AppTypography.heroMaxFontSize),
    ]) {
      final (size, expected) = probe;
      useView(tester, size);

      await _pumpPrice(tester);
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
