import 'package:bitcoin_dashboard/core/widgets/progress_meter.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/data/network_health_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/mining_pool.dart';
import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:bitcoin_dashboard/features/network/domain/node_count.dart';
import 'package:bitcoin_dashboard/features/network/presentation/network_screen.dart';
import 'package:bitcoin_dashboard/features/network/presentation/pool_share_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// `data/network-health.json` as the CDN served it on 2026-09-14.
///
/// Nodes: 26,579 reachable, +0.3 % over 24 h, trend `stable`.
/// Pools: top 1 = 25.34 (Foundry USA), top 3 = 60.96, listed = 95.20 →
/// uncritical.
final NetworkHealthSnapshot _live = NetworkHealthSnapshot.fromJson(
  loadJsonFixture('network-health.json'),
);

/// Eleven hours after the producer wrote the fixture: comfortably inside
/// the 26-hour staleness threshold, on whatever day this suite runs.
final DateTime _now = _live.fetchedAt.add(const Duration(hours: 11));

/// The node reading the fixture carries, for the cases that vary the
/// pools and want the node statement left alone.
const NodeCount _stableNodes = NodeCount(
  count: 26579,
  percentChange24h: 0.3,
  trend: NodeTrend.stable,
);

/// A snapshot whose figures land where the test wants them, so a verdict
/// can be produced without restating either matrix here.
NetworkHealthSnapshot _snapshot({
  List<(String, double)> pools = const [
    ('Foundry USA', 25.34),
    ('AntPool', 21.92),
    ('F2Pool', 13.7),
  ],
  NodeCount? nodes = _stableNodes,
  String aggregatedHealth = 'good',
  DateTime? fetchedAt,
}) {
  return NetworkHealthSnapshot(
    fetchedAt: fetchedAt ?? _now,
    sources: const ['BTCNodes.io', 'Mempool.space'],
    fullNodes: nodes,
    aggregatedHealth: aggregatedHealth,
    pools: [
      for (final (name, share) in pools)
        MiningPool(name: name, hashratePercent: share),
    ],
  );
}

/// The screen, with [health] standing in for the CDN read.
Future<void> _pumpNetwork(
  WidgetTester tester,
  Override health, {
  Size view = TestView.tallTablet,
  Locale locale = const Locale('en'),
  DateTime? now,
}) async {
  useView(tester, view);
  await pumpApp(
    tester,
    child: const NetworkScreen(),
    overrides: [health],
    locale: locale,
    now: now ?? _now,
  );
}

void main() {
  setUpTestHive();

  group('loading', () {
    testWidgets('shows one skeleton for the section, not one per statement', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncLoading()),
      );
      await tester.pump();

      expect(find.textContaining('LOADING NETWORK DATA'), findsOneWidget);
      // Neither statement's subject is named yet, and there is no data
      // stand to put in the eyebrow.
      expect(find.textContaining('MINING POOL CONCENTRATION'), findsNothing);
      expect(find.textContaining('FULL NODES'), findsNothing);
      expect(find.textContaining('AS OF'), findsNothing);
      // Nothing to judge, so nothing is judged.
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
    });
  });

  group('error', () {
    testWidgets('names the section, what still works, and offers a retry', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(
          asyncError(Exception('unreachable')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network data unavailable'), findsOneWidget);
      expect(
        find.textContaining('The live price is not affected'),
        findsOneWidget,
        reason: 'the error state has to name what is still working',
      );
      expect(find.text('TRY AGAIN'), findsOneWidget);
      // One error for the document, not one per statement.
      expect(find.text('Pool distribution unavailable'), findsNothing);
    });

    testWidgets('shows no figures it cannot back', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(
          asyncError(Exception('unreachable')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PoolShareList), findsNothing);
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.text('26,579'), findsNothing);
    });
  });

  group('data · nodes', () {
    testWidgets('states the verdict, the count and the sentence that reads '
        'it', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('FULL NODES'), findsOneWidget);
      expect(find.text('Secure'), findsOneWidget);
      expect(find.text('REACHABLE FULL NODES'), findsOneWidget);
      expect(find.text('26,579'), findsOneWidget);
      expect(
        find.textContaining(
          '26,579 reachable nodes worldwide — no single actor can control '
          'the network.',
        ),
        findsOneWidget,
        reason: 'every figure needs its sentence',
      );
    });

    testWidgets('carries the 24 h change as context, with its sign', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('+0.3 % in 24 h'), findsOneWidget);
      // The change carries no verdict of its own and no badge restates it.
      expect(find.byType(StatusBadge), findsOneWidget);
      expect(
        find.textContaining('24 H COMPARISON FIGURE MISSING'),
        findsNothing,
      );
    });

    testWidgets('offers the two sources as its whole evidence', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('SOURCES · BTCNODES.IO · MEMPOOL.SPACE'),
        findsOneWidget,
      );
    });

    testWidgets('asserts no scale it has no denominator for', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      // Every bar on the screen belongs to the pool statement below.
      // A count has no reference value, so nothing here is a share of
      // anything and no bar may suggest otherwise.
      final firstMeter = tester.getTopLeft(find.byType(ProgressMeter).first);
      final nodeEvidence = tester.getBottomLeft(
        find.text('SOURCES · BTCNODES.IO · MEMPOOL.SPACE'),
      );
      expect(firstMeter.dy, greaterThan(nodeEvidence.dy));
    });

    testWidgets('opens the full-node explanation from the info trigger', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InfoTrigger).first);
      await tester.pumpAndSettle();

      expect(find.text('Full node'), findsOneWidget);
      expect(
        find.textContaining('it is a lower bound, not a total'),
        findsOneWidget,
      );
    });
  });

  group('order', () {
    testWidgets('the node statement stands above the pool statement', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      // Both texts being present proves nothing about the order, so the
      // assertion is on the position.
      final nodes = tester.getTopLeft(find.text('26,579'));
      final pools = tester.getTopLeft(find.text('25.3'));
      expect(nodes.dy, lessThan(pools.dy));
    });
  });

  group('data · pools', () {
    testWidgets('states the ok verdict with both figures and the sentence', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('DISTRIBUTION BROAD'), findsOneWidget);
      // Top 1 = 25.34 -> 25.3, top 3 = 60.96 -> 61.0.
      expect(find.text('25.3'), findsOneWidget);
      expect(find.text('61.0'), findsOneWidget);
      expect(find.text('Foundry USA'), findsWidgets);
      expect(
        find.textContaining(
          'No pool holds more than 25.3 % of the computing power, and the '
          'three largest together do not cross the 70 % line',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the thresholds the verdict is measured against', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(find.text('THRESHOLD 40 %'), findsOneWidget);
      expect(find.text('CRITICAL FROM 50 %'), findsOneWidget);
      expect(find.text('THRESHOLD 70 %'), findsOneWidget);
      expect(find.text('CRITICAL FROM 80 %'), findsOneWidget);
      expect(
        find.textContaining('14.7 PP BELOW THE 40 % THRESHOLD'),
        findsOneWidget,
      );
    });

    testWidgets('says what the list covers without inventing an Others pool', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Σ 95.20 % ATTRIBUTED TO THE LISTED POOLS'),
        findsOneWidget,
      );
      expect(find.textContaining('OTHERS'), findsNothing);
    });

    testWidgets('keeps the tail behind a toggle and reveals it on tap', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
      );
      await tester.pumpAndSettle();

      // Leaders are visible, the tenth pool is not.
      expect(find.text('Foundry USA'), findsWidgets);
      expect(find.text('SECPOOL'), findsNothing);

      await tester.tap(find.text('SHOW MORE POOLS'));
      await tester.pumpAndSettle();

      expect(find.text('SECPOOL'), findsOneWidget);
      expect(find.text('HIDE MORE POOLS'), findsOneWidget);
    });
  });

  group('data · warning', () {
    testWidgets('escalates when the top three cross 70 %', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(
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
      // The statement above it is unaffected by the pool reading.
      expect(find.text('Secure'), findsOneWidget);
    });

    testWidgets('escalates on a single pool above 40 % with a calm top three', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(
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
        networkHealthProvider.overrideWith(
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

  group('trend unknown', () {
    testWidgets('keeps the figure and says which comparison is missing', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(
          asyncData(
            _snapshot(
              nodes: const NodeCount(
                count: 26579,
                percentChange24h: null,
                trend: NodeTrend.unknown,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '24 H COMPARISON FIGURE MISSING · THE NODE COUNT ITSELF IS CURRENT',
        ),
        findsOneWidget,
      );
      // The verdict hangs on the count, so it stands.
      expect(find.text('Secure'), findsOneWidget);
      expect(find.text('26,579'), findsOneWidget);
      expect(find.text('24 h change not available'), findsOneWidget);
      expect(find.textContaining('in 24 h'), findsNothing);
    });

    testWidgets('an unknown aggregate verdict alone does not raise the hint', (
      tester,
    ) async {
      // `aggregateHealth()` reports "unknown" as soon as either dimension
      // is missing, so a failed pool source with an intact node count
      // lands here. Binding the hint to it would claim a missing
      // comparison that is on screen.
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(
          asyncData(_snapshot(aggregatedHealth: 'unknown')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+0.3 % in 24 h'), findsOneWidget);
      expect(
        find.textContaining('24 H COMPARISON FIGURE MISSING'),
        findsNothing,
      );
    });
  });

  group('nodes unavailable', () {
    testWidgets('states why, names what still works, and shows no figure', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_snapshot(nodes: null))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Node count not available'), findsOneWidget);
      expect(
        find.textContaining('The pool distribution below is not affected'),
        findsOneWidget,
      );
      // No verdict it cannot back, and above all no dash where the count
      // belongs.
      expect(find.text('Secure'), findsNothing);
      expect(find.text('REACHABLE FULL NODES'), findsNothing);
      expect(find.text('—'), findsNothing);
      // The statement keeps its head: this is not a section failure.
      expect(find.text('FULL NODES'), findsOneWidget);
      expect(find.text('Network data unavailable'), findsNothing);
    });

    testWidgets('leaves the pool statement below it intact', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_snapshot(nodes: null))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('25.3'), findsOneWidget);
      expect(find.byType(PoolShareList), findsOneWidget);
    });
  });

  group('stale', () {
    testWidgets('carries one age hint for the section, above both '
        'statements', (tester) async {
      // The payload does not change; the clock moves past the threshold.
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
        now: _live.fetchedAt.add(const Duration(hours: 31)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('NETWORK DATA 31 HOURS OLD'),
        findsOneWidget,
        reason: 'one document, one fetch, one hint',
      );
      // Above the first figure, with nothing between the two.
      final hint = tester.getTopLeft(
        find.textContaining('NETWORK DATA 31 HOURS OLD'),
      );
      expect(hint.dy, lessThan(tester.getTopLeft(find.text('26,579')).dy));

      // Stale is not an error: both verdicts and both figures stay.
      expect(find.text('Secure'), findsOneWidget);
      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('25.3'), findsOneWidget);
      expect(find.text('Network data unavailable'), findsNothing);
    });

    testWidgets('a payload inside 26 hours carries no age hint', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
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
        networkHealthProvider.overrideWith(
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
      // No pool verdict, and above all no em dash standing in for the
      // top-three figure. The node statement above keeps its own.
      expect(find.text('Uncritical'), findsNothing);
      expect(find.text('Secure'), findsOneWidget);
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
        networkHealthProvider.overrideWith(
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
        networkHealthProvider.overrideWith(asyncData(_live)),
        view: TestView.tallPhone,
      );
      await tester.pumpAndSettle();

      // The two pool figure columns stack rather than sitting side by side.
      final topOne = tester.getTopLeft(find.text('25.3'));
      final topThree = tester.getTopLeft(find.text('61.0'));
      expect(topThree.dy, greaterThan(topOne.dy));
      expect(topThree.dx, topOne.dx);

      await tester.tap(find.text('SHOW MORE POOLS'));
      await tester.pumpAndSettle();
      expect(find.text('SECPOOL'), findsOneWidget);
    });

    testWidgets('places the pool figures side by side when there is room', (
      tester,
    ) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
        view: TestView.tallDesktop,
      );
      await tester.pumpAndSettle();

      final topOne = tester.getTopLeft(find.text('25.3'));
      final topThree = tester.getTopLeft(find.text('61.0'));
      expect(topThree.dy, topOne.dy);
      expect(topThree.dx, greaterThan(topOne.dx));
    });
  });

  group('localisation', () {
    testWidgets('renders German copy and German figures', (tester) async {
      await _pumpNetwork(
        tester,
        networkHealthProvider.overrideWith(asyncData(_live)),
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sicher'), findsOneWidget);
      expect(find.text('26.579'), findsOneWidget);
      expect(find.text('+0,3 % in 24 h'), findsOneWidget);
      expect(
        find.textContaining('26.579 erreichbare Nodes weltweit'),
        findsOneWidget,
      );
      expect(find.text('Unbedenklich'), findsOneWidget);
      expect(find.text('25,3'), findsOneWidget);
      expect(find.text('61,0'), findsOneWidget);
    });
  });
}
