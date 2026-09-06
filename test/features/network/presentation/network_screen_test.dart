import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/data/network_pools_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/mining_pool.dart';
import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:bitcoin_dashboard/features/network/presentation/network_screen.dart';
import 'package:bitcoin_dashboard/features/network/presentation/pool_share_list.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// A snapshot whose top-one and top-three shares land where the test wants
/// them, so a verdict can be produced without restating the matrix here.
NetworkHealthSnapshot _snapshot({
  required List<(String, double)> pools,
  DateTime? fetchedAt,
}) {
  return NetworkHealthSnapshot(
    fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
    pools: [
      for (final (name, share) in pools)
        MiningPool(name: name, hashratePercent: share),
    ],
  );
}

/// The live payload of 2026-09-06 — top 1 = 22.37, top 3 = 57.90 → ok.
final _okPools = <(String, double)>[
  ('Foundry USA', 22.37),
  ('AntPool', 18.42),
  ('F2Pool', 17.11),
  ('ViaBTC', 11.84),
  ('SpiderPool', 11.18),
  ('Luxor', 4.61),
  ('Binance Pool', 3.95),
  ('SECPOOL', 3.29),
  ('MARA Pool', 2.63),
  ('OCEAN', 1.97),
];

/// Builds the screen with [create] standing in for the CDN read.
///
/// Takes the create function rather than a ready-made override because
/// `flutter_riverpod` does not export the `Override` type, so a helper
/// cannot name one in its signature.
Widget _harness({
  required FutureOr<NetworkHealthSnapshot> Function(Ref) create,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
}) {
  return ProviderScope(
    overrides: [networkPoolsProvider.overrideWith(create)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: NetworkScreen()),
    ),
  );
}

FutureOr<NetworkHealthSnapshot> Function(Ref) _data(
  NetworkHealthSnapshot snapshot,
) =>
    (ref) async => snapshot;

/// A future that never completes — the loading state, held still.
FutureOr<NetworkHealthSnapshot> _loading(Ref ref) =>
    Completer<NetworkHealthSnapshot>().future;

FutureOr<NetworkHealthSnapshot> _error(Ref ref) async =>
    throw Exception('CDN unreachable');

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_network_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('loading', () {
    testWidgets('names the subject and says the distribution is loading', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(_harness(create: _loading));
      await tester.pump();

      expect(find.textContaining('MINING POOL CONCENTRATION'), findsOneWidget);
      expect(find.textContaining('Loading the distribution'), findsOneWidget);
      // No verdict and no figures while there is nothing to judge.
      expect(find.byType(StatementVerdict), findsNothing);
      expect(find.byType(InsightPill), findsNothing);
    });
  });

  group('error', () {
    testWidgets('names what still works and offers a retry', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(_harness(create: _error));
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
      useTallView(tester);
      await tester.pumpWidget(_harness(create: _error));
      await tester.pumpAndSettle();

      expect(find.byType(PoolShareList), findsNothing);
      expect(find.byType(StatementVerdict), findsNothing);
    });
  });

  group('data', () {
    testWidgets('states the ok verdict with both figures and the sentence', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('DISTRIBUTION BROAD'), findsOneWidget);
      // Top 1 = 22.37 -> 22.4, top 3 = 57.90 -> 57.9.
      expect(find.text('22.4'), findsOneWidget);
      expect(find.text('57.9'), findsOneWidget);
      expect(find.text('Foundry USA'), findsWidgets);
      expect(
        find.textContaining('No pool holds more than 22.4 %'),
        findsOneWidget,
        reason: 'every figure needs its sentence',
      );
    });

    testWidgets('shows the thresholds the verdict is measured against', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
      );
      await tester.pumpAndSettle();

      expect(find.text('THRESHOLD 40 %'), findsOneWidget);
      expect(find.text('CRITICAL FROM 50 %'), findsOneWidget);
      expect(find.text('THRESHOLD 70 %'), findsOneWidget);
      expect(find.text('CRITICAL FROM 80 %'), findsOneWidget);
      expect(
        find.textContaining('17.6 PP BELOW THE 40 % THRESHOLD'),
        findsOneWidget,
      );
    });

    testWidgets('says what the list covers without inventing an Others pool', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Σ 97.37 % ATTRIBUTED TO THE LISTED POOLS'),
        findsOneWidget,
      );
      expect(find.textContaining('OTHERS'), findsNothing);
    });

    testWidgets('keeps the tail behind a toggle and reveals it on tap', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
      );
      await tester.pumpAndSettle();

      // Leaders are visible, the seventh pool is not.
      expect(find.text('AntPool'), findsWidgets);
      expect(find.text('OCEAN'), findsNothing);

      await tester.tap(find.text('SHOW MORE POOLS'));
      await tester.pumpAndSettle();

      expect(find.text('OCEAN'), findsOneWidget);
      expect(find.text('HIDE MORE POOLS'), findsOneWidget);
    });

    testWidgets('opens the mining pool explanation from the info trigger', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
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
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
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
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
            // Top 1 = 45, top 3 = 65: only the single-pool line is crossed.
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
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
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
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
            _snapshot(
              pools: _okPools,
              fetchedAt: DateTime.now().toUtc().subtract(
                const Duration(hours: 31),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DATA 31 HOURS OLD'), findsOneWidget);
      // Stale is not an error: the verdict and the figures stay.
      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.text('22.4'), findsOneWidget);
      expect(find.text('Pool distribution unavailable'), findsNothing);
    });

    testWidgets('a payload inside 26 hours carries no age hint', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
            _snapshot(
              pools: _okPools,
              fetchedAt: DateTime.now().toUtc().subtract(
                const Duration(hours: 25),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('HOURS OLD'), findsNothing);
    });
  });

  group('empty', () {
    testWidgets('below three pools it states why, with no substitute figure', (
      tester,
    ) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
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
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(
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
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
      );
      await tester.pumpAndSettle();

      // The two figure columns stack rather than sitting side by side.
      final topOne = tester.getTopLeft(find.text('22.4'));
      final topThree = tester.getTopLeft(find.text('57.9'));
      expect(topThree.dy, greaterThan(topOne.dy));
      expect(topThree.dx, topOne.dx);

      await tester.tap(find.text('SHOW MORE POOLS'));
      await tester.pumpAndSettle();
      expect(find.text('OCEAN'), findsOneWidget);
    });

    testWidgets('places the figures side by side when there is room', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(create: _data(_snapshot(pools: _okPools))),
      );
      await tester.pumpAndSettle();

      final topOne = tester.getTopLeft(find.text('22.4'));
      final topThree = tester.getTopLeft(find.text('57.9'));
      expect(topThree.dy, topOne.dy);
      expect(topThree.dx, greaterThan(topOne.dx));
    });
  });

  group('localisation', () {
    testWidgets('renders German copy and German decimals', (tester) async {
      useTallView(tester);
      await tester.pumpWidget(
        _harness(
          create: _data(_snapshot(pools: _okPools)),
          locale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unbedenklich'), findsOneWidget);
      expect(find.text('22,4'), findsOneWidget);
      expect(find.text('57,9'), findsOneWidget);
      expect(
        find.textContaining('Kein Pool hält mehr als 22,4 %'),
        findsOneWidget,
      );
    });
  });
}
