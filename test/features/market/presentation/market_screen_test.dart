import 'package:bitcoin_dashboard/core/widgets/progress_meter.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/market/data/sentiment_provider.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_index.dart';
import 'package:bitcoin_dashboard/features/market/presentation/market_screen.dart';
import 'package:bitcoin_dashboard/features/market/presentation/sentiment_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The window alternative.me served on 2026-09-13 — 61 today, mean 62.8,
/// range 31–74, greed since 20 August.
final SentimentIndex _live = SentimentIndex.fromJson(
  loadJsonFixture('sentiment-fng.json'),
);

/// A window ending on the fixture's last day, values oldest first.
SentimentIndex _window(List<int> values) {
  final last = DateTime.utc(2026, 9, 13);
  return SentimentIndex(
    points: [
      for (var i = 0; i < values.length; i++)
        SentimentPoint(
          at: last.subtract(Duration(days: values.length - 1 - i)),
          value: values[i],
        ),
    ],
  );
}

Future<void> _pumpMarket(
  WidgetTester tester,
  Override sentiment, {
  Size view = TestView.tallTablet,
  Locale locale = const Locale('en'),
  DateTime? now,
}) async {
  useView(tester, view);
  await pumpApp(
    tester,
    child: const MarketScreen(),
    overrides: [sentiment],
    locale: locale,
    now: now ?? DateTime.utc(2026, 9, 13, 18),
  );
}

void main() {
  setUpTestHive();

  group('loading', () {
    testWidgets('names the subject and says it is loading', (tester) async {
      await _pumpMarket(tester, sentimentProvider.overrideWith(asyncLoading()));
      await tester.pump();

      expect(find.textContaining('SENTIMENT'), findsWidgets);
      expect(find.textContaining('LOADING'), findsOneWidget);
      // Nothing to judge yet: no verdict, no sentence, no curve.
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
      expect(find.byType(SentimentSparkline), findsNothing);
    });
  });

  group('error', () {
    testWidgets('names what still works and offers a retry', (tester) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncError(Exception('unreachable'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load sentiment'), findsOneWidget);
      expect(
        find.textContaining('Price and network data are not affected'),
        findsOneWidget,
        reason: 'one section failing must not read as the app failing',
      );
      expect(find.text('RETRY'), findsOneWidget);
    });

    testWidgets('shows no figure it cannot back', (tester) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncError(Exception('unreachable'))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(SentimentSparkline), findsNothing);
      expect(find.byType(ProgressMeter), findsNothing);
    });
  });

  group('data', () {
    testWidgets('states the band, the figure and the sentence behind it', (
      tester,
    ) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Greed'), findsWidgets);
      expect(find.text('61'), findsOneWidget);
      expect(find.text('/ 100'), findsOneWidget);
      expect(
        find.textContaining(
          'The market is slightly overbought – 63 on average over the last '
          '30 days, inside the Greed band without interruption since '
          'August 20.',
        ),
        findsOneWidget,
        reason: 'the figure does not ship without its sentence',
      );
    });

    testWidgets('marks the four boundaries the verdict changes at', (
      tester,
    ) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('26'), findsOneWidget);
      expect(find.text('47'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(find.text('76'), findsOneWidget);
      expect(find.text('SCALE 0–100'), findsOneWidget);
    });

    testWidgets('carries no badge and no live dot', (tester) async {
      // The verdict word *is* the band's name, and the value is set once
      // a day — a second word beside it and a pulsing dot would both
      // claim more than the payload does.
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StatusBadge), findsNothing);
      expect(find.byType(LiveDot), findsNothing);
      expect(find.byType(InfoTrigger), findsOneWidget);
    });

    testWidgets('shows the window as evidence, with its range and source', (
      tester,
    ) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SentimentSparkline), findsOneWidget);
      expect(find.text('30 DAYS · AUG 15–SEP 13, 2026'), findsOneWidget);
      expect(find.text('RANGE 31–74'), findsOneWidget);
      expect(find.text('OLDEST POINT AUG 15, 2026'), findsOneWidget);
      expect(find.text('Source: alternative.me'), findsOneWidget);
      // All five bands are named beside the curve, current one included.
      expect(find.text('EXTREME FEAR'), findsOneWidget);
      expect(find.text('EXTREME GREED'), findsOneWidget);
    });

    testWidgets('the stamp is the value\'s day, not the day of the fetch', (
      tester,
    ) async {
      // A week later, with the payload served from cache: the screen
      // still reports the day the value belongs to. This is why the
      // slice needs no stale state.
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncData(_live)),
        now: DateTime.utc(2026, 9, 20, 9),
      );
      await tester.pumpAndSettle();

      expect(find.text('AS OF SEP 13, 2026'), findsOneWidget);
      expect(find.textContaining('SEP 20'), findsNothing);
    });
  });

  group('the three sentences', () {
    testWidgets('a window that never left its band names no date', (
      tester,
    ) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(
          asyncData(_window(List<int>.filled(30, 60))),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'The market is slightly overbought – 60 on average over the last '
          '30 days, all 30 values inside the Greed band.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a run shorter than three days falls back to the range', (
      tester,
    ) async {
      // Twenty-nine days of fear and one of greed: the band is a day old
      // and "without interruption since" would overstate it.
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(
          asyncData(_window([...List<int>.filled(29, 30), 60])),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'The market is slightly overbought – 31 on average over the last '
          '30 days, range 30–60.',
        ),
        findsOneWidget,
      );
    });
  });

  group('German', () {
    testWidgets('states the same reading in German', (tester) async {
      await _pumpMarket(
        tester,
        sentimentProvider.overrideWith(asyncData(_live)),
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gier'), findsWidgets);
      expect(find.text('STAND 13. SEPT. 2026'), findsOneWidget);
      expect(
        find.textContaining(
          'Der Markt ist leicht überkauft – im Mittel der letzten 30 Tage 63, '
          'seit dem 20. August durchgehend im Gier-Band.',
        ),
        findsOneWidget,
      );
      expect(find.text('SKALA 0–100'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('renders on a phone as well as on a wide window', (
      tester,
    ) async {
      for (final view in [TestView.tallPhone, TestView.tallDesktop]) {
        await _pumpMarket(
          tester,
          sentimentProvider.overrideWith(asyncData(_live)),
          view: view,
        );
        await tester.pumpAndSettle();

        expect(find.byType(SentimentSparkline), findsOneWidget);
        expect(find.text('61'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
