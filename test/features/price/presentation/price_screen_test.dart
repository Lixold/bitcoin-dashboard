import 'dart:async';

import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:bitcoin_dashboard/core/widgets/brand_icon.dart';
import 'package:bitcoin_dashboard/core/widgets/loading_skeleton.dart';
import 'package:bitcoin_dashboard/core/widgets/progress_meter.dart';
import 'package:bitcoin_dashboard/core/widgets/segmented_control.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/price/data/history_provider.dart';
import 'package:bitcoin_dashboard/features/price/data/market_provider.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_history.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_range.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_tick.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_trend.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_trend_chart.dart';
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

  _trendTests();
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

    testWidgets('neither of these two figures carries an insight pill', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpMarket(tester);
      await tester.pumpAndSettle();

      // The screen design leaves the insight slot of *these two*
      // statements empty: the verdict word, its badge and the evidence
      // carry the reading, and two more tinted blocks under two figures
      // is what the price screen is meant not to look like. The movement
      // statement above them does fill the slot — its figure is a bare
      // percentage with nothing else to read it by — so this counts the
      // pills rather than asserting there are none.
      expect(
        find.descendant(
          of: find.byType(ProgressMeter).first,
          matching: find.byType(InsightPill),
        ),
        findsNothing,
      );
      expect(find.byType(InsightPill), findsNothing);
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

    testWidgets('a high without a date keeps the distance and drops the row', (
      tester,
    ) async {
      // The date is evidence, not the figure. Without it the row falls
      // away; a dash in its place would be the placeholder §5 rules out.
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

      expect(find.text('Below the high'), findsOneWidget);
      expect(find.text('23.5'), findsOneWidget);
      expect(find.text('DATE'), findsNothing);
      // The em dash the meter label carries is typography; this is about
      // the one that would sit where the date was meant to be.
      expect(find.text('—'), findsNothing);
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

      // Not "no statement on the screen": the movement statement above
      // rests on a different document and is unaffected. What has to be
      // gone is everything the market payload carries.
      expect(find.byType(ProgressMeter), findsNothing);
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.text('ALL-TIME HIGH'), findsNothing);
      expect(find.text('MARKET CAPITALISATION'), findsNothing);
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
      expect(find.byType(StatementVerdict), findsNothing);
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

      // Both of the two that rest on `market.json` — the movement
      // statement reads its own document and is not part of this failure.
      expect(find.text('Below the high'), findsNothing);
      expect(find.text('Dominant'), findsNothing);
      expect(find.byType(ProgressMeter), findsNothing);
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
      expect(find.text('MARKTKAPITALISIERUNG'), findsOneWidget);
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

// -- Market movement --------------------------------------------------------

/// The 1W and 1M documents the CDN served on 2026-09-10 at 19:45:39 UTC.
///
/// Two ranges, not five: the two are enough to show that the statement
/// changes with the tab, and they fall on opposite sides of the flat band
/// while doing it — 1W lost 5.5 %, 1M gained 21.7 %. `3M` has no capture
/// because 2 161 points is 70 kB of fixture for a curve no assertion
/// reads; `1D` and `1Y` are constructed below, where the shape of the
/// series is the point rather than its values.
PriceHistory _capture(String range) =>
    PriceHistory.fromJson(loadJsonFixture('history-$range.json'));

/// Four minutes after the captures were taken: inside the 45-minute
/// threshold.
final DateTime _historyFresh = DateTime.utc(2026, 9, 10, 19, 50);

/// A series built for a test rather than captured from the CDN.
///
/// **Nothing here is a live reading.** The CDN serves full series in all
/// five ranges, so a short one and an empty one cannot be captured — they
/// are constructed, and the values mean nothing beyond the shape each
/// test needs.
PriceHistory _constructed({
  required int count,
  double first = 100,
  double last = 100,
  Duration step = const Duration(hours: 1),
  DateTime? fetchedAt,
}) {
  final end = fetchedAt ?? DateTime.utc(2026, 9, 10, 19, 45, 39);
  final start = end.subtract(step * (count - 1));
  return PriceHistory(
    fetchedAt: end,
    points: [
      for (var i = 0; i < count; i++)
        PricePoint(
          at: start.add(step * i),
          price: count == 1
              ? first
              : first + (last - first) * (i / (count - 1)),
        ),
    ],
  );
}

/// Pumps the screen with [histories] behind the range control.
///
/// A range with no entry stays in its loading state, which is what a test
/// that only cares about one range wants.
Future<void> _pumpTrend(
  WidgetTester tester, {
  Map<PriceRange, PriceHistory> histories = const {},
  DateTime? now,
  Locale locale = const Locale('en'),
  Object? failure,
}) => pumpApp(
  tester,
  child: const PriceScreen(),
  locale: locale,
  now: now ?? _historyFresh,
  overrides: [
    priceLiveProvider.overrideWith(_oneTick),
    marketProvider.overrideWith(asyncData(_snapshot())),
    historyProvider.overrideWith((ref, range) async {
      if (failure != null) throw failure;
      final history = histories[range];
      if (history == null) return Completer<PriceHistory>().future;
      return history;
    }),
  ],
);

/// The movement statement, which is the first on the screen.
///
/// The two market statements below it read a different document with a
/// different stamp, so a screen-wide assertion about an age or a verdict
/// would be answered by the wrong one.
final Finder _movement = find.byType(Statement).first;

/// The text of the start-of-series label under the chart.
String _startLabel(WidgetTester tester) {
  final labels = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(PriceTrendChart),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .whereType<String>()
      .toList();
  // Title, point count, start, "NOW" — the start is the one before last.
  return labels[labels.length - 2];
}

void _trendTests() {
  group('movement', () {
    testWidgets('states which way the price went and over how long', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      // 63,474.26 to 77,226.77 over 29 d 23 h — a gain of 21.7 % well
      // outside the 5 % band.
      expect(find.text('MARKET MOVEMENT'), findsOneWidget);
      expect(find.text('Rising'), findsOneWidget);
      expect(find.text('UPWARD'), findsOneWidget);
      expect(find.text('+21.7 %'), findsOneWidget);
      expect(find.text('over 30 days'), findsOneWidget);
    });

    testWidgets('the figure carries the sentence that reads it', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      expect(find.byType(InsightPill), findsOneWidget);
      expect(find.textContaining('the price gained 21.7 %'), findsOneWidget);
      // The band is in the sentence as a number, from the constant rather
      // than typed into the copy.
      expect(find.textContaining('above the 5 % band'), findsOneWidget);
    });

    testWidgets('the curve is the evidence, counted from the series', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      expect(find.byType(PriceTrendChart), findsOneWidget);
      expect(find.text('PRICE HISTORY'), findsOneWidget);
      // 721 today, and a different number tomorrow: the count is read off
      // the series, never from a per-range constant.
      expect(find.text('721 POINTS'), findsOneWidget);
      expect(find.text('NOW'), findsOneWidget);
      expect(
        tester.widget<PriceTrendChart>(find.byType(PriceTrendChart)).tone,
        TrendChartTone.current,
      );
    });

    testWidgets('a fresh series carries the live dot and no age hint', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _movement,
          matching: find.textContaining('NO UPDATE SINCE'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: _movement, matching: find.byType(LiveDot)),
        findsWidgets,
      );
    });

    testWidgets('the explanation says which two points were measured', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      final triggers = tester.widgetList<InfoTrigger>(find.byType(InfoTrigger));
      expect(
        triggers.map((trigger) => trigger.label),
        contains(startsWith('The change measures the first against')),
      );
    });
  });

  group('range', () {
    testWidgets('all five ranges are offered and none is a sixth', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      for (final label in <String>['1D', '1W', '1M', '3M', '1Y']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // No ALL and no greyed-out "coming soon": the source ends at 365
      // days, and a tab with nothing behind it is a placeholder.
      expect(find.text('ALL'), findsNothing);
      expect(
        tester
            .widget<AppSegmentedControl<PriceRange>>(
              find.byType(AppSegmentedControl<PriceRange>),
            )
            .segments,
        hasLength(PriceRange.values.length),
      );
    });

    testWidgets('the statement changes with the tab, not just the curve', (
      tester,
    ) async {
      // The point of the whole slice: 1W and 1M do not read the same
      // sentence. If they did, the control would be decoration.
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneWeek: _capture('1W'),
          PriceRange.oneMonth: _capture('1M'),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Rising'), findsOneWidget);
      expect(find.text('+21.7 %'), findsOneWidget);
      expect(find.text('721 POINTS'), findsOneWidget);

      await tester.tap(find.text('1W'));
      await tester.pumpAndSettle();

      // −5.51 % is past the band, so the same screen now says the
      // opposite word — and the sentence, the badge and the point count
      // move with it.
      expect(find.text('Falling'), findsOneWidget);
      expect(find.text('DOWNWARD'), findsOneWidget);
      expect(find.text('−5.5 %'), findsOneWidget);
      expect(find.text('over 7 days'), findsOneWidget);
      expect(find.text('169 POINTS'), findsOneWidget);
      expect(find.textContaining('the price lost 5.5 %'), findsOneWidget);
      expect(find.text('Rising'), findsNothing);
    });

    testWidgets('a selected range survives leaving the screen and coming '
        'back', (tester) async {
      // Local widget state would reset here, which is not what picking a
      // range means.
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneWeek: _capture('1W'),
          PriceRange.oneMonth: _capture('1M'),
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1W'));
      await tester.pumpAndSettle();
      expect(find.text('Falling'), findsOneWidget);

      // The screen is rebuilt from scratch; the scope, and the choice in
      // it, are not.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneWeek: _capture('1W'),
          PriceRange.oneMonth: _capture('1M'),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('1M'), findsOneWidget, reason: 'the strip is back');
    });

    testWidgets('the strip is one full-width row of compact options', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      final control = tester.widget<AppSegmentedControl<PriceRange>>(
        find.byType(AppSegmentedControl<PriceRange>),
      );
      expect(control.density, SegmentedDensity.compact);
      expect(control.block, isTrue);
    });

    testWidgets('the start label says as much of the start as the range '
        'needs', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          // Constructed: only the spacing and the length matter here.
          PriceRange.oneDay: _constructed(
            count: 288,
            step: const Duration(minutes: 5),
          ),
          PriceRange.oneMonth: _capture('1M'),
          PriceRange.oneYear: _constructed(
            count: 366,
            step: const Duration(days: 1),
          ),
        },
      );
      await tester.pumpAndSettle();

      // A month: a day and a month place it. The exact date depends on
      // the zone the test runs in, so this asserts the shape.
      expect(_startLabel(tester), matches(RegExp(r'^[A-Z]{3} \d{1,2}$')));

      await tester.tap(find.text('1D'));
      await tester.pumpAndSettle();
      expect(
        _startLabel(tester),
        contains(':'),
        reason: 'a day needs the time',
      );

      await tester.tap(find.text('1Y'));
      await tester.pumpAndSettle();
      expect(
        _startLabel(tester),
        matches(RegExp(r'^[A-Z]{3} \d{4}$')),
        reason: 'a year needs the year',
      );
    });
  });

  group('flat band', () {
    testWidgets('exactly the band already reads as a direction', (
      tester,
    ) async {
      // The boundary the unit tests fix, seen through the screen: +5.0 %
      // is "Rising", not "Sideways".
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneMonth: _constructed(count: 60, first: 100, last: 105),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Rising'), findsOneWidget);
      expect(find.text('+5.0 %'), findsOneWidget);
    });

    testWidgets('inside the band there is no direction to state', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneMonth: _constructed(count: 60, first: 100, last: 101),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Sideways'), findsOneWidget);
      expect(find.text('NO DIRECTION'), findsOneWidget);
      expect(find.text('+1.0 %'), findsOneWidget);
      expect(find.textContaining('inside the 5 % band'), findsOneWidget);
    });

    testWidgets('a change of nothing takes no sign', (tester) async {
      // "+0.0 %" and "−0.0 %" both claim a direction the figure does not
      // have.
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneMonth: _constructed(count: 60, first: 100, last: 100),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('0.0 %'), findsOneWidget);
      expect(find.text('+0.0 %'), findsNothing);
      expect(find.text('−0.0 %'), findsNothing);
    });
  });

  group('stale', () {
    testWidgets('past the threshold it says how old it is and keeps the '
        'figures', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
        now: DateTime.utc(2026, 9, 10, 20, 31),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _movement,
          matching: find.textContaining('NO UPDATE SINCE'),
        ),
        findsOneWidget,
      );
      expect(find.text('Rising'), findsOneWidget, reason: 'the verdict stays');
      expect(find.text('+21.7 %'), findsOneWidget, reason: 'the figure stays');
    });

    testWidgets('the curve drops to neutral when it is no longer now', (
      tester,
    ) async {
      // The last point of an aged series is not "now" any more, and the
      // live price in the hero is newer than it. The accent belongs to
      // the current reading.
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
        now: DateTime.utc(2026, 9, 10, 20, 31),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<PriceTrendChart>(find.byType(PriceTrendChart)).tone,
        TrendChartTone.aged,
      );
    });
  });

  group('short series', () {
    testWidgets('says what it has instead of drawing a direction', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _constructed(count: 3)},
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('SERIES INCOMPLETE · 3 OF 30 POINTS'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _movement, matching: find.byType(StatementVerdict)),
        findsNothing,
        reason: 'no direction to state, so no verdict line',
      );
      expect(find.text('Rising'), findsNothing);
      expect(find.text('Sideways'), findsNothing);
      expect(find.text('Falling'), findsNothing);
      expect(find.textContaining('Only 3 of 30 points'), findsOneWidget);
    });

    testWidgets('the points are drawn as points, not as a trend', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _constructed(count: 3)},
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<PriceTrendChart>(find.byType(PriceTrendChart)).tone,
        TrendChartTone.sparse,
      );
      expect(find.text('3 POINTS'), findsOneWidget);
    });

    testWidgets('the other ranges stay selectable', (tester) async {
      // A strip that vanished on the one short range would strand the
      // reader on it.
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneMonth: _constructed(count: 3),
          PriceRange.oneWeek: _capture('1W'),
        },
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppSegmentedControl<PriceRange>), findsOneWidget);

      await tester.tap(find.text('1W'));
      await tester.pumpAndSettle();

      expect(find.text('Falling'), findsOneWidget);
      expect(find.textContaining('SERIES INCOMPLETE'), findsNothing);
    });

    testWidgets('one point short of the minimum is still short', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneMonth: _constructed(
            count: PriceTrend.minPoints - 1,
            first: 100,
            last: 200,
          ),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Rising'), findsNothing);
      expect(find.textContaining('SERIES INCOMPLETE'), findsOneWidget);
    });
  });

  group('empty series', () {
    testWidgets('drops the card rather than drawing an empty frame', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _constructed(count: 0)},
      );
      await tester.pumpAndSettle();

      expect(find.byType(PriceTrendChart), findsNothing);
      expect(find.text('NO POINTS FOR THIS RANGE'), findsOneWidget);
      expect(
        find.textContaining('Nothing has been published for this range'),
        findsOneWidget,
      );
      // No dash, no zero, no empty outline.
      expect(find.text('—'), findsNothing);
      expect(find.text('0 POINTS'), findsNothing);
    });

    testWidgets('the range strip stays', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _constructed(count: 0)},
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppSegmentedControl<PriceRange>), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('holds the chart height without printing a figure', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      // No entry for any range: every one stays in flight.
      await _pumpTrend(tester);
      await tester.pump();

      expect(find.text('LOADING THE HISTORY…'), findsOneWidget);
      expect(find.byType(PriceTrendChart), findsNothing);
      expect(
        find.descendant(of: _movement, matching: find.byType(StatementVerdict)),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is LoadingSkeleton &&
              widget.height == PriceTrendChart.compactHeight,
        ),
        findsOneWidget,
        reason: 'the skeleton is as tall as the curve will be',
      );
    });

    testWidgets('the range strip stays put while a range loads', (
      tester,
    ) async {
      // It is driven by the reader's choice, not by the payload. A
      // control that vanished on every tap would flicker once per switch.
      useView(tester, TestView.tallPhone);
      await _pumpTrend(tester);
      await tester.pump();

      expect(find.byType(AppSegmentedControl<PriceRange>), findsOneWidget);
    });
  });

  group('error', () {
    testWidgets('names what still works and offers a retry', (tester) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(tester, failure: Exception('CDN unreachable'));
      await tester.pumpAndSettle();

      expect(find.text('History unreachable'), findsOneWidget);
      expect(
        find.textContaining('The published history could not be reached'),
        findsOneWidget,
      );
      expect(find.text('TRY AGAIN'), findsWidgets);
      // A different source, and unaffected.
      expect(find.textContaining(r'$96,442.50'), findsOneWidget);
    });

    testWidgets('the statement and its range strip go together', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(tester, failure: Exception('CDN unreachable'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSegmentedControl<PriceRange>), findsNothing);
      expect(find.byType(PriceTrendChart), findsNothing);
    });

    testWidgets('a failing history leaves the two market statements alone', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(tester, failure: Exception('CDN unreachable'));
      await tester.pumpAndSettle();

      expect(find.text('Below the high'), findsOneWidget);
      expect(find.text('Dominant'), findsOneWidget);
    });
  });

  group('localisation', () {
    testWidgets('renders German range labels and German decimals', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      // Day and year abbreviate differently in German — the reason these
      // are keys rather than literals.
      expect(find.text('1T'), findsOneWidget);
      expect(find.text('1J'), findsOneWidget);
      expect(find.text('1D'), findsNothing);
      expect(find.text('MARKTENTWICKLUNG'), findsOneWidget);
      expect(find.text('Steigend'), findsOneWidget);
      expect(find.text('+21,7 %'), findsOneWidget);
      expect(find.text('über 30 Tage'), findsOneWidget);
    });

    testWidgets('the shortest range is said in hours, not in one day', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {
          PriceRange.oneDay: _constructed(
            count: 288,
            step: const Duration(minutes: 5),
            first: 100,
            last: 99,
          ),
        },
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1T'));
      await tester.pumpAndSettle();

      expect(find.text('über 24 Stunden'), findsOneWidget);
    });
  });

  group('narrow viewport', () {
    testWidgets('lays out on a 390 px phone without overflowing', (
      tester,
    ) async {
      useView(tester, TestView.tallPhone);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('gives the curve more height on a desktop frame', (
      tester,
    ) async {
      useView(tester, TestView.tallDesktop);
      await _pumpTrend(
        tester,
        histories: {PriceRange.oneMonth: _capture('1M')},
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        PriceTrendChart.heightFor(TestView.tallDesktop.width),
        PriceTrendChart.wideHeight,
      );
    });
  });
}
