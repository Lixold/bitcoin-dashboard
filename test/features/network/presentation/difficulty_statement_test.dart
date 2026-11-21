import 'package:bitcoin_dashboard/core/widgets/progress_meter.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/data/difficulty_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/difficulty_snapshot.dart';
import 'package:bitcoin_dashboard/features/network/presentation/difficulty_statement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The reading the captured payload of 2026-11-21 makes: +10.2 %, 5 d 9 h
/// to go, 857 blocks left, 9.1 min average block time.
final DifficultySnapshot _captured = DifficultySnapshot.fromJson(
  loadJsonFixture('mempool-space-difficulty-adjustment.json'),
  observedAt: DateTime.utc(2026, 11, 21, 12, 29),
);

DifficultySnapshot _falling() => DifficultySnapshot(
  changePercent: -3.44,
  remaining: const Duration(hours: 7, minutes: 20),
  progressPercent: 99.9,
  remainingBlocks: 1,
  averageBlockTime: const Duration(minutes: 10, seconds: 21),
  observedAt: DateTime.utc(2026, 11, 21, 12, 29),
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
    child: const SingleChildScrollView(child: DifficultyStatement()),
    overrides: [reading],
    locale: locale,
    brightness: brightness,
  );
}

void main() {
  group('loading', () {
    testWidgets('names its subject and judges nothing yet', (tester) async {
      await _pump(tester, difficultyProvider.overrideWith(asyncLoading()));
      await tester.pump();

      expect(find.text('DIFFICULTY ADJUSTMENT'), findsOneWidget);
      expect(find.text('LOADING DIFFICULTY…'), findsOneWidget);
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
        difficultyProvider.overrideWith(asyncError(Exception('unreachable'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Difficulty adjustment not available'), findsOneWidget);
      expect(
        find.textContaining('other statements on this screen are not affected'),
        findsOneWidget,
      );
      expect(find.textContaining('a stale one would be wrong'), findsOneWidget);
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(ProgressMeter), findsNothing);
    });

    testWidgets('retry asks mempool.space again', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        difficultyProvider.overrideWith((ref) async {
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
    testWidgets('states the verdict, the countdown and the sentence', (
      tester,
    ) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Harder'), findsOneWidget);
      expect(find.text('+10.2 % EXPECTED'), findsOneWidget);
      expect(find.text('UNTIL THE NEXT ADJUSTMENT'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('DAYS'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);
      expect(
        find.textContaining(
          'In about 5 days the difficulty will probably rise by 10.2 %, '
          'which makes mining harder.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byType(LiveDot), findsWidgets);
      expect(find.textContaining('REFRESHES EVERY 5 MIN'), findsOneWidget);
    });

    testWidgets('reads both directions neutrally', (tester) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
      );
      await tester.pumpAndSettle();

      final verdict = tester.widget<StatementVerdict>(
        find.byType(StatementVerdict),
      );
      final pill = tester.widget<InsightPill>(find.byType(InsightPill));
      expect(verdict.tone, StatementTone.neutral);
      expect(pill.tone, StatementTone.neutral);
    });

    testWidgets('shows how far through the period the estimate is', (
      tester,
    ) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
      );
      await tester.pumpAndSettle();

      expect(find.text('POSITION IN THE PERIOD'), findsOneWidget);
      expect(find.text('1,159 OF 2,016 BLOCKS'), findsOneWidget);
      expect(find.text('57.5 %'), findsOneWidget);
      expect(
        find.text(
          'The estimate rests on the 1,159 blocks of this period so far; '
          '857 are still to come.',
        ),
        findsOneWidget,
      );
      final meter = tester.widget<ProgressMeter>(find.byType(ProgressMeter));
      expect(meter.percent, closeTo(57.49, 0.01));
    });

    testWidgets('labels the block time against the ten-minute target', (
      tester,
    ) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
      );
      await tester.pumpAndSettle();

      expect(find.text('WHY IT CHANGES'), findsOneWidget);
      expect(find.text('Average block time'), findsOneWidget);
      expect(find.text('9.1'), findsOneWidget);
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(
        find.text(
          'Blocks came faster than the ten-minute target, so the difficulty '
          'rises to slow them down.',
        ),
        findsOneWidget,
      );
      expect(find.text('SOURCE · MEMPOOL.SPACE'), findsOneWidget);
    });

    testWidgets('a falling difficulty reads easier, in hours below a day', (
      tester,
    ) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_falling())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Easier'), findsOneWidget);
      expect(find.text('−3.4 % EXPECTED'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);
      expect(find.text('MINUTES'), findsOneWidget);
      expect(
        find.textContaining(
          'In about 7 hours the difficulty will probably fall by 3.4 %, '
          'which makes mining easier.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'The estimate rests on the 2,015 blocks of this period so far; '
          '1 is still to come.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('slower than the ten-minute'), findsOneWidget);
    });

    testWidgets('speaks German with German numbers and the dative', (
      tester,
    ) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schwerer'), findsOneWidget);
      expect(find.text('+10,2 % ERWARTET'), findsOneWidget);
      expect(find.text('TAGE'), findsOneWidget);
      expect(
        find.textContaining(
          'In etwa 5 Tagen steigt die Difficulty voraussichtlich um 10,2 %, '
          'das macht Mining schwerer.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('1.159 VON 2.016 BLÖCKEN'), findsOneWidget);
    });

    testWidgets('opens the explanation from the info trigger', (tester) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InfoTrigger));
      await tester.pumpAndSettle();

      expect(find.textContaining('Every 2,016 blocks'), findsOneWidget);
    });

    testWidgets('fits a phone without overflow', (tester) async {
      await _pump(
        tester,
        difficultyProvider.overrideWith(asyncData(_captured)),
        view: TestView.phone,
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Schwerer'), findsOneWidget);
    });
  });
}
