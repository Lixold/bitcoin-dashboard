import 'dart:async';

import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:bitcoin_dashboard/core/widgets/brand_icon.dart';
import 'package:bitcoin_dashboard/core/widgets/loading_skeleton.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/price/data/market_provider.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
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

  _marketTests();
}

// -- Market statements ------------------------------------------------------

/// The payload the CDN served on 2026-09-09 at 18:30:59 UTC.
MarketSnapshot _snapshot() =>
    MarketSnapshot.fromJson(loadJsonFixture('market.json'));

/// Four minutes after the capture: inside the 45-minute threshold.
final DateTime _fresh = DateTime.utc(2026, 9, 9, 18, 35);

/// Pumps the screen with the market payload in [snapshot] and the clock
/// frozen at [now].
///
/// The clock is frozen rather than left running because every assertion
/// about the age of a payload is a comparison against a "now", and a test
/// that does not say which one drifts with the day the suite runs on.
Future<void> _pumpMarket(
  WidgetTester tester, {
  MarketSnapshot? snapshot,
  DateTime? now,
  Locale locale = const Locale('en'),
  bool withPrice = true,
}) => pumpApp(
  tester,
  child: const PriceScreen(),
  locale: locale,
  now: now ?? _fresh,
  overrides: [
    if (withPrice) priceLiveProvider.overrideWith(_oneTick),
    marketProvider.overrideWith(asyncData(snapshot ?? _snapshot())),
  ],
);

void _marketTests() {
  group('data', () {
    testWidgets('states how far below the high the price stands', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      // 96,442.50 against a high of 126,080 is 23.5 % below — a
      // correction, neither near the high nor a deep one.
      expect(find.text('Below the high'), findsOneWidget);
      expect(find.text('23.5'), findsOneWidget);
      expect(find.text('% below the high'), findsOneWidget);
    });

    testWidgets('every figure carries the sentence that reads it', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      // CLAUDE.md §5: a number without its sentence is a placeholder by
      // another name. Both figures on this screen have one.
      expect(
        find.textContaining('23.5 % below the all-time high'),
        findsOneWidget,
      );
      expect(
        find.textContaining('of the entire crypto market value'),
        findsOneWidget,
      );
      expect(find.byType(InsightPill), findsNWidgets(2));
    });

    testWidgets('names the record the distance is measured from', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      expect(find.text('ALL-TIME HIGH'), findsOneWidget);
      expect(find.text(r'$126,080.00'), findsOneWidget);
      expect(find.textContaining('AT 76.5 % OF THE HIGH'), findsOneWidget);
      expect(find.text('100 % — ALL-TIME HIGH'), findsOneWidget);
    });

    testWidgets('states the share and shows what the rest holds', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      expect(find.text('Dominant'), findsOneWidget);
      expect(find.text('58.4'), findsOneWidget);
      expect(find.text('58.4 %'), findsOneWidget);
      expect(find.text('41.6 %'), findsOneWidget);
      expect(find.text('MARKET CAPITALISATION'), findsOneWidget);
      expect(find.text(r'$1.58T'), findsOneWidget);
    });

    testWidgets('a fresh payload carries the live dot and no age hint', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('NO UPDATE SINCE'), findsNothing);
      expect(find.byType(LiveDot), findsWidgets);
    });

    testWidgets('the distance carries its explanation, the share does not', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      // The design gives one trigger, to the statement where "all-time
      // high" needs saying.
      expect(find.byType(InfoTrigger), findsOneWidget);
      // No sheet behind it: the explanation is the tooltip, so the glyph
      // is an "i" rather than a "?" that promises a page.
      expect(find.text('i'), findsOneWidget);
    });
  });

  group('stale', () {
    testWidgets('past the threshold it says how old it is and keeps the '
        'figures', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, now: DateTime.utc(2026, 9, 9, 19, 16, 59));
      await tester.pumpAndSettle();

      expect(find.textContaining('NO UPDATE SINCE'), findsWidgets);
      expect(find.text('23.5'), findsOneWidget, reason: 'figures stay');
      expect(find.text('58.4'), findsOneWidget, reason: 'figures stay');
    });

    testWidgets('inside the threshold it carries no age hint', (tester) async {
      useView(tester, TestView.tallPhone);
      // Exactly 45 minutes: the bound is strict, so this is not yet stale.
      await _pumpMarket(tester, now: DateTime.utc(2026, 9, 9, 19, 15, 59));
      await tester.pumpAndSettle();

      expect(find.textContaining('NO UPDATE SINCE'), findsNothing);
    });

    testWidgets('a day without a write earns the alert glyph', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, now: DateTime.utc(2026, 9, 10, 19, 35));
      await tester.pumpAndSettle();

      expect(find.textContaining('NO UPDATE SINCE'), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is BrandIcon && widget.glyph == UiGlyph.alert,
        ),
        findsWidgets,
      );
    });

    testWidgets('three quarters of an hour is a hiccup, not an alarm', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, now: DateTime.utc(2026, 9, 9, 19, 16, 59));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is BrandIcon && widget.glyph == UiGlyph.alert,
        ),
        findsNothing,
      );
    });
  });

  group('empty', () {
    testWidgets('a missing high drops that statement and keeps the share', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(
        tester,
        snapshot: MarketSnapshot.fromJson(const {
          'fetchedAt': '2026-09-09T18:30:59+00:00',
          'currency': 'usd',
          'btcDominance': 58.38,
          'marketCap': 1578083556466,
        }),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Distance to all-time high'.toUpperCase()),
        findsNothing,
      );
      expect(find.text('Dominant'), findsOneWidget);
      // No dash, no empty frame, no substitute line.
      expect(find.text('—'), findsNothing);
    });

    testWidgets('a missing share drops that statement and keeps the high', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(
        tester,
        snapshot: MarketSnapshot.fromJson(const {
          'fetchedAt': '2026-09-09T18:30:59+00:00',
          'currency': 'usd',
          'ath': 126080,
          'athDate': '2025-10-06T10:57:42.000Z',
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('Below the high'), findsOneWidget);
      expect(find.text('Dominant'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('a high without a date still reads as a sentence', (
      tester,
    ) async {
      // The clause naming the date drops out; a dash in its place would
      // be the placeholder §5 rules out, inside a sentence rather than
      // in a figure slot.
      useView(tester, TestView.tallPhone);
      await _pumpMarket(
        tester,
        snapshot: MarketSnapshot.fromJson(const {
          'fetchedAt': '2026-09-09T18:30:59+00:00',
          'currency': 'usd',
          'ath': 126080,
        }),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('23.5 % below the all-time high.'),
        findsOneWidget,
      );
      // The em dash the meter label carries is typography; this is about
      // the one that would sit where the date was meant to be.
      expect(find.textContaining('set on —'), findsNothing);
    });

    testWidgets('with neither figure the section is simply not there', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(
        tester,
        snapshot: MarketSnapshot.fromJson(const {
          'fetchedAt': '2026-09-09T18:30:59+00:00',
        }),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Statement), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
    });

    testWidgets('without a live price the distance cannot be stated', (
      tester,
    ) async {
      // The distance is the live price measured against the published
      // high, so it needs both. The share needs neither and stays.
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, withPrice: false);
      await tester.pumpAndSettle();

      expect(find.text('Below the high'), findsNothing);
      expect(find.text('Dominant'), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('holds the space without printing a figure', (tester) async {
      useView(tester, TestView.tallPhone);
      await pumpApp(
        tester,
        child: const PriceScreen(),
        now: _fresh,
        overrides: [marketProvider.overrideWith(asyncLoading())],
      );
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsWidgets);
      expect(find.byType(InsightPill), findsNothing);
    });

    testWidgets('never shows a zero that reads like a price', (tester) async {
      // The bug this replaces: the hero used to format `0` while loading,
      // which renders as $0.00 and is indistinguishable from a real
      // quote.
      useView(tester, TestView.tallPhone);
      await pumpApp(
        tester,
        child: const PriceScreen(),
        now: _fresh,
        overrides: [marketProvider.overrideWith(asyncLoading())],
      );
      await tester.pump();

      expect(find.textContaining(r'$0.00'), findsNothing);
      expect(find.textContaining('0.0'), findsNothing);
    });
  });

  group('error', () {
    testWidgets('names what still works and offers a retry', (tester) async {
      useView(tester, TestView.tallPhone);
      await pumpApp(
        tester,
        child: const PriceScreen(),
        now: _fresh,
        overrides: [
          priceLiveProvider.overrideWith(_oneTick),
          marketProvider.overrideWith(asyncError(Exception('CDN unreachable'))),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Market data unreachable'), findsOneWidget);
      expect(
        find.textContaining('comes straight from Binance'),
        findsOneWidget,
      );
      expect(find.text('TRY AGAIN'), findsOneWidget);
      // The live price is a different source and is unaffected.
      expect(find.textContaining(r'$96,442.50'), findsOneWidget);
    });

    testWidgets('drops both statements, not one', (tester) async {
      useView(tester, TestView.tallPhone);
      await pumpApp(
        tester,
        child: const PriceScreen(),
        now: _fresh,
        overrides: [
          priceLiveProvider.overrideWith(_oneTick),
          marketProvider.overrideWith(asyncError(Exception('CDN unreachable'))),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(InsightPill), findsNothing);
    });
  });

  group('localisation', () {
    testWidgets('renders German copy and German decimals', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, locale: const Locale('de'));
      await tester.pumpAndSettle();

      expect(find.text('Unter dem Hoch'), findsOneWidget);
      expect(find.text('23,5'), findsOneWidget);
      expect(find.text('58,4'), findsOneWidget);
      expect(
        find.textContaining('des gesamten Kryptomarktwerts'),
        findsOneWidget,
      );
    });

    testWidgets('the short form is a Billion in German, not a trillion', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, locale: const Locale('de'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bio.'), findsOneWidget);
    });

    testWidgets('the amounts stay in the currency the data is quoted in', (
      tester,
    ) async {
      // Until #32 converts, a German reader sees German digits under a
      // dollar sign — the number is dollars and the symbol has to say so.
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester, locale: const Locale('de'));
      await tester.pumpAndSettle();

      // The gap before the symbol is a non-breaking space, invisible in
      // a diff: it is what keeps the amount and its symbol on one line.
      expect(find.text('126.080,00 \$'), findsOneWidget);
    });
  });

  group('narrow viewport', () {
    testWidgets('lays out on a 390 px phone without overflowing', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out on a desktop frame without overflowing', (
      tester,
    ) async {
      useView(tester, TestView.tallDesktop);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
