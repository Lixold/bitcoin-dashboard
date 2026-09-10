import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/data/network_pools_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/mining_pool.dart';
import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:bitcoin_dashboard/features/network/presentation/network_screen.dart';
import 'package:bitcoin_dashboard/features/network/presentation/pool_share_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// `data/network-health.json` as the CDN served it on 2026-09-08.
///
/// Top 1 = 22.96 (AntPool), top 3 = 60.74, listed = 97.04 → uncritical.
final NetworkHealthSnapshot _live = NetworkHealthSnapshot.fromJson(
  loadJsonFixture('network-health.json'),
);

/// Eleven hours after the producer wrote the fixture: comfortably inside
/// the 26-hour staleness threshold, on whatever day this suite runs.
final DateTime _now = _live.fetchedAt.add(const Duration(hours: 11));

/// A snapshot whose top-one and top-three shares land where the test wants
/// them, so a verdict can be produced without restating the matrix here.
NetworkHealthSnapshot _snapshot({
  required List<(String, double)> pools,
  DateTime? fetchedAt,
}) {
  return NetworkHealthSnapshot(
    fetchedAt: fetchedAt ?? _now,
    pools: [
      for (final (name, share) in pools)
        MiningPool(name: name, hashratePercent: share),
    ],
  );
}

/// The screen, with [pools] standing in for the CDN read.
Future<void> _pumpNetwork(
  WidgetTester tester,
  Override pools, {
  Size view = TestView.tallTablet,
  Locale locale = const Locale('en'),
  DateTime? now,
}) async {
  useView(tester, view);
  await pumpApp(
    tester,
    child: const NetworkScreen(),
    overrides: [pools],
    locale: locale,
    now: now ?? _now,
  );
}

void main() {
  setUpTestHive();

  group('loading', () {
    testWidgets('names the subject and says the distribution is loading', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncLoading()),
      );
      await tester.pump();

      expect(find.textContaining('MINING POOL CONCENTRATION'), findsOneWidget);
      // The qualifier line is set in caps, like the subject above it.
      expect(find.textContaining('LOADING THE DISTRIBUTION'), findsOneWidget);
      // No verdict and no figures while there is nothing to judge.
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
    });
  });

  group('error', () {
    testWidgets('names what still works and offers a retry', (tester) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncError(Exception('unreachable'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pool distribution unavailable'), findsOneWidget);
      expect(
        find.textContaining('The live price is unaffected'),
        findsOneWidget,
        reason: 'the error state has to name what is still working',
      );
      expect(find.text('TRY AGAIN'), findsOneWidget);
    });

    testWidgets('shows no figures it cannot back', (tester) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncError(Exception('unreachable'))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PoolShareList), findsNothing);
      expect(find.byType(StatementVerdict), findsNothing);
    });
  });

  group('data', () {
    testWidgets('states the ok verdict with both figures and the sentence', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('DISTRIBUTION BROAD'), findsOneWidget);
      // Top 1 = 22.96 -> 23.0, top 3 = 60.74 -> 60.7.
      expect(find.text('23.0'), findsOneWidget);
      expect(find.text('60.7'), findsOneWidget);
      expect(find.text('AntPool'), findsWidgets);
      expect(
        find.textContaining(
          'No pool holds more than 23.0 % of the computing power, and the '
          'three largest together do not cross the 70 % line',
        ),
        findsOneWidget,
        reason: 'every figure needs its sentence',
      );
    });

    testWidgets('shows the thresholds the verdict is measured against', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('THRESHOLD 40 %'), findsOneWidget);
      expect(find.text('CRITICAL FROM 50 %'), findsOneWidget);
      expect(find.text('THRESHOLD 70 %'), findsOneWidget);
      expect(find.text('CRITICAL FROM 80 %'), findsOneWidget);
      expect(
        find.textContaining('17.0 PP BELOW THE 40 % THRESHOLD'),
        findsOneWidget,
      );
    });

    testWidgets('says what the list covers without inventing an Others pool', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Σ 97.04 % ATTRIBUTED TO THE LISTED POOLS'),
        findsOneWidget,
      );
      expect(find.textContaining('OTHERS'), findsNothing);
    });

    testWidgets('keeps the tail behind a toggle and reveals it on tap', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      // Leaders are visible, the ninth pool is not.
      expect(find.text('Foundry USA'), findsWidgets);
      expect(find.text('OCEAN'), findsNothing);

      await tester.tap(find.text('SHOW MORE POOLS'));
      await tester.pumpAndSettle();

      expect(find.text('OCEAN'), findsOneWidget);
      expect(find.text('HIDE MORE POOLS'), findsOneWidget);
    });

    testWidgets('opens the mining pool explanation from the info trigger', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InfoTrigger));
      await tester.pumpAndSettle();

      expect(find.text('Mining pool'), findsOneWidget);
      expect(
        find.textContaining('combine their computing power'),
        findsOneWidget,
      );
    });
  });

  group('data · warning', () {
    testWidgets('escalates when the top three cross 70 %', (tester) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(
          asyncData(
            _snapshot(
              pools: const [
                ('Foundry USA', 38.14),
                ('AntPool', 20.63),
                ('ViaBTC', 13.68),
                ('F2Pool', 8.91),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elevated'), findsOneWidget);
      expect(find.text('CONCENTRATION ELEVATED'), findsOneWidget);
      expect(
        find.textContaining('The hashrate is unevenly distributed'),
        findsOneWidget,
      );
      // The category switches with the verdict — it is a key, not a label
      // welded to the section.
      expect(find.textContaining('Attention:'), findsOneWidget);
    });

    testWidgets('escalates on a single pool above 40 % with a calm top three', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(
          // Top 1 = 45, top 3 = 65: only the single-pool line is crossed.
          asyncData(
            _snapshot(
              pools: const [
                ('Foundry USA', 45.0),
                ('AntPool', 10.0),
                ('ViaBTC', 10.0),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elevated'), findsOneWidget);
      expect(
        find.textContaining('the largest pool holds 45.0 %'),
        findsOneWidget,
        reason: 'the sentence must name the figure that actually escalated',
      );
    });
  });

  group('data · critical', () {
    testWidgets('states the critical verdict when one pool passes 50 %', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(
          asyncData(
            _snapshot(
              pools: const [
                ('Foundry USA', 52.36),
                ('AntPool', 17.21),
                ('ViaBTC', 10.44),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('CONCENTRATION CRITICAL'), findsOneWidget);
      expect(find.textContaining('withhold blocks'), findsOneWidget);
    });
  });

  group('stale', () {
    testWidgets('keeps the figures and adds an age hint', (tester) async {
      // The payload does not change; the clock moves past the threshold.
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
        now: _live.fetchedAt.add(const Duration(hours: 31)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DATA 31 HOURS OLD'), findsOneWidget);
      // Stale is not an error: the verdict and the figures stay.
      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('23.0'), findsOneWidget);
      expect(find.text('Pool distribution unavailable'), findsNothing);
    });

    testWidgets('a payload inside 26 hours carries no age hint', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
        now: _live.fetchedAt.add(const Duration(hours: 25)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('HOURS OLD'), findsNothing);
    });
  });

  group('empty', () {
    testWidgets('below three pools it states why, with no substitute figure', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(
          asyncData(
            _snapshot(
              pools: const [('Foundry USA', 26.44), ('AntPool', 14.79)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Statement about the three largest pools cannot be formed'),
        findsOneWidget,
      );
      expect(find.textContaining('only 2 pools'), findsOneWidget);
      // No verdict, no insight, and above all no em dash standing in for
      // the top-three figure.
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(
        find.text('The three largest combined'.toUpperCase()),
        findsNothing,
      );
      // The largest pool it did receive is still named.
      expect(find.text('26.4'), findsOneWidget);
    });

    testWidgets('does not claim a coverage sum it has no source for', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(
          asyncData(
            _snapshot(
              pools: const [('Foundry USA', 26.44), ('AntPool', 14.79)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('ATTRIBUTED TO THE LISTED POOLS'),
        findsNothing,
      );
      expect(find.textContaining('2 POOLS DELIVERED'), findsOneWidget);
    });
  });

  group('narrow viewport', () {
    testWidgets('lays out on a 390 px phone without overflowing', (
      tester,
    ) async {
      // The evidence rows carry fixed columns (rank, name, figure) around
      // a flexible bar. A RenderFlex overflow throws here, so rendering at
      // the narrowest shipped width is the assertion.
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
        view: TestView.tallPhone,
      );
      await tester.pumpAndSettle();

      // The two figure columns stack rather than sitting side by side.
      final topOne = tester.getTopLeft(find.text('23.0'));
      final topThree = tester.getTopLeft(find.text('60.7'));
      expect(topThree.dy, greaterThan(topOne.dy));
      expect(topThree.dx, topOne.dx);

      await tester.tap(find.text('SHOW MORE POOLS'));
      await tester.pumpAndSettle();
      expect(find.text('OCEAN'), findsOneWidget);
    });

    testWidgets('places the figures side by side when there is room', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
        view: TestView.tallDesktop,
      );
      await tester.pumpAndSettle();

      final topOne = tester.getTopLeft(find.text('23.0'));
      final topThree = tester.getTopLeft(find.text('60.7'));
      expect(topThree.dy, topOne.dy);
      expect(topThree.dx, greaterThan(topOne.dx));
    });
  });

  group('localisation', () {
    testWidgets('renders German copy and German decimals', (tester) async {
      await _pumpNetwork(
        tester,
        networkPoolsProvider.overrideWith(asyncData(_live)),
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unbedenklich'), findsOneWidget);
      expect(find.text('23,0'), findsOneWidget);
      expect(find.text('60,7'), findsOneWidget);
      expect(
        find.textContaining('Kein Pool hält mehr als 23,0 %'),
        findsOneWidget,
      );
    });
  });
}
