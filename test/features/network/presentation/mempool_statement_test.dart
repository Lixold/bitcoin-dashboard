import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/data/mempool_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/mempool_snapshot.dart';
import 'package:bitcoin_dashboard/features/network/presentation/mempool_statement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The reading the captured payloads of 2026-11-20 make: 81,456
/// transactions, 36.06 MvB, fees 6 / 4 / 2 sat/vB.
final MempoolSnapshot _captured = MempoolSnapshot.fromJson(
  mempool: loadJsonFixture('mempool-space-mempool.json'),
  fees: loadJsonFixture('mempool-space-fees-recommended.json'),
  observedAt: DateTime.utc(2026, 11, 20, 13, 11),
);

MempoolSnapshot _withBlocks(double blocks) => MempoolSnapshot(
  count: 50000,
  vsize: blocks * 1000000,
  fastestFee: 9,
  hourFee: 3,
  economyFee: 1,
  observedAt: DateTime.utc(2026, 11, 20, 13, 11),
);

Future<void> _pump(
  WidgetTester tester,
  Override reading, {
  Size view = TestView.tallTablet,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
}) async {
  useView(tester, view);
  await pumpApp(
    tester,
    child: const SingleChildScrollView(child: MempoolStatement()),
    overrides: [reading],
    locale: locale,
    brightness: brightness,
  );
}

void main() {
  group('loading', () {
    testWidgets('names its subject and judges nothing yet', (tester) async {
      await _pump(tester, mempoolProvider.overrideWith(asyncLoading()));
      await tester.pump();

      expect(find.text('MEMPOOL AND FEES'), findsOneWidget);
      expect(find.text('LOADING MEMPOOL…'), findsOneWidget);
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
      expect(find.byType(LiveDot), findsNothing);
    });
  });

  group('error', () {
    testWidgets('says what failed, what still works and why nothing older '
        'stands in', (tester) async {
      await _pump(
        tester,
        mempoolProvider.overrideWith(asyncError(Exception('unreachable'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mempool not available'), findsOneWidget);
      expect(
        find.textContaining('node count and pool shares are not affected'),
        findsOneWidget,
      );
      expect(find.textContaining('a stale one would be wrong'), findsOneWidget);
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.textContaining('sat/vB'), findsNothing);
    });

    testWidgets('retry asks mempool.space again', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        mempoolProvider.overrideWith((ref) async {
          calls++;
          throw Exception('unreachable');
        }),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.tap(find.text('TRY AGAIN'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  });

  group('data', () {
    testWidgets('states the verdict, the figure and the sentence', (
      tester,
    ) async {
      await _pump(tester, mempoolProvider.overrideWith(asyncData(_captured)));
      await tester.pumpAndSettle();

      expect(find.text('Busy'), findsOneWidget);
      expect(find.text('36.1 BLOCKS WAITING'), findsOneWidget);
      expect(find.text('36.1'), findsOneWidget);
      expect(find.text('81,456 transactions'), findsOneWidget);
      expect(
        find.textContaining(
          'The mempool is busy: a transaction paying 4 sat/vB confirms in '
          'about an hour.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byType(LiveDot), findsWidgets);
    });

    testWidgets('carries the band tone into verdict and sentence', (
      tester,
    ) async {
      await _pump(tester, mempoolProvider.overrideWith(asyncData(_captured)));
      await tester.pumpAndSettle();

      final verdict = tester.widget<StatementVerdict>(
        find.byType(StatementVerdict),
      );
      final pill = tester.widget<InsightPill>(find.byType(InsightPill));
      expect(verdict.tone, StatementTone.warning);
      expect(pill.tone, StatementTone.warning);
    });

    testWidgets('labels the other two fees by what they buy', (tester) async {
      await _pump(tester, mempoolProvider.overrideWith(asyncData(_captured)));
      await tester.pumpAndSettle();

      expect(find.text('WHAT A FEE BUYS'), findsOneWidget);
      expect(find.text('Next block'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('No time promise'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('SOURCE · MEMPOOL.SPACE'), findsOneWidget);
    });

    testWidgets('shows the band boundaries the verdict is read against', (
      tester,
    ) async {
      await _pump(tester, mempoolProvider.overrideWith(asyncData(_captured)));
      await tester.pumpAndSettle();

      expect(find.text('NORMAL FROM 10 · BUSY FROM 30'), findsOneWidget);
      expect(find.text('CONGESTED FROM 45'), findsOneWidget);
      expect(find.text('60+'), findsOneWidget);
      expect(
        find.text("8.9 BLOCKS' WORTH BELOW THE CONGESTION LINE"),
        findsOneWidget,
      );
    });

    testWidgets('opens the explanation from the info trigger', (tester) async {
      await _pump(tester, mempoolProvider.overrideWith(asyncData(_captured)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InfoTrigger));
      await tester.pumpAndSettle();

      expect(find.text('Mempool'), findsOneWidget);
      expect(
        find.textContaining('Most of the queue usually pays the lowest fees'),
        findsOneWidget,
      );
    });
  });

  group('each band reads as its own verdict', () {
    final cases = <(double, String, StatementTone)>[
      (4, 'Calm', StatementTone.positive),
      (12, 'Normal', StatementTone.positive),
      (30, 'Busy', StatementTone.warning),
      (52, 'Congested', StatementTone.negative),
    ];
    for (final (blocks, word, tone) in cases) {
      testWidgets('$blocks blocks → $word', (tester) async {
        await _pump(
          tester,
          mempoolProvider.overrideWith(asyncData(_withBlocks(blocks))),
        );
        await tester.pumpAndSettle();

        expect(find.text(word), findsOneWidget);
        expect(
          tester.widget<StatementVerdict>(find.byType(StatementVerdict)).tone,
          tone,
        );
      });
    }

    testWidgets('above the line, the note counts upwards', (tester) async {
      await _pump(
        tester,
        mempoolProvider.overrideWith(asyncData(_withBlocks(52))),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("7.0 BLOCKS' WORTH ABOVE THE CONGESTION LINE"),
        findsOneWidget,
      );
    });

    testWidgets('a figure just below a boundary is not rounded onto it', (
      tester,
    ) async {
      await _pump(
        tester,
        mempoolProvider.overrideWith(asyncData(_withBlocks(29.96))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('30.0'), findsOneWidget);
    });
  });

  group('layout and locale', () {
    testWidgets('lays out on a 390 px phone without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        mempoolProvider.overrideWith(asyncData(_captured)),
        view: TestView.tallPhone,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Busy'), findsOneWidget);
    });

    testWidgets('renders in the light scheme', (tester) async {
      await _pump(
        tester,
        mempoolProvider.overrideWith(asyncData(_captured)),
        brightness: Brightness.light,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Busy'), findsOneWidget);
    });

    testWidgets('renders German copy and German figures', (tester) async {
      await _pump(
        tester,
        mempoolProvider.overrideWith(asyncData(_captured)),
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belebt'), findsOneWidget);
      expect(find.text('36,1'), findsOneWidget);
      expect(find.text('81.456 Transaktionen'), findsOneWidget);
      expect(
        find.textContaining(
          'Der Mempool ist belebt: Eine Transaktion mit 4 sat/vB',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });
}
