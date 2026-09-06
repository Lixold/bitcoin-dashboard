import 'package:bitcoin_dashboard/features/network/domain/mining_pool.dart';
import 'package:bitcoin_dashboard/features/network/domain/pool_concentration.dart';
import 'package:flutter_test/flutter_test.dart';

List<MiningPool> _pools(Map<String, double> shares) => [
  for (final entry in shares.entries)
    MiningPool(name: entry.key, hashratePercent: entry.value),
];

void main() {
  group('verdictFor — every cell of the #68 threshold matrix', () {
    test('ok while top 3 <= 70 % and top 1 <= 40 %', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 22.37, topThreeShare: 57.90),
        ConcentrationVerdict.ok,
      );
    });

    test('warning once top 3 exceeds 70 %', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 30, topThreeShare: 72),
        ConcentrationVerdict.warning,
      );
    });

    test('warning once top 1 exceeds 40 %, even with a calm top 3', () {
      // 45 + 10 + 10 = 65: the top-three line is untouched, the single
      // pool alone carries the verdict.
      expect(
        PoolConcentration.verdictFor(topOneShare: 45, topThreeShare: 65),
        ConcentrationVerdict.warning,
      );
    });

    test('critical once top 3 reaches 80 %', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 40, topThreeShare: 80),
        ConcentrationVerdict.critical,
      );
    });

    test('critical once top 1 exceeds 50 %', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 51, topThreeShare: 60),
        ConcentrationVerdict.critical,
      );
    });

    test(
      'critical wins when a set trips both a warning and a critical row',
      () {
        // top 3 = 75 is a warning row, top 1 = 55 is a critical one.
        expect(
          PoolConcentration.verdictFor(topOneShare: 55, topThreeShare: 75),
          ConcentrationVerdict.critical,
        );
      },
    );
  });

  group('verdictFor — the four boundaries', () {
    test('top 1 of exactly 40 % is still ok, 40.1 % is a warning', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 40, topThreeShare: 60),
        ConcentrationVerdict.ok,
      );
      expect(
        PoolConcentration.verdictFor(topOneShare: 40.1, topThreeShare: 60),
        ConcentrationVerdict.warning,
      );
    });

    test('top 1 of exactly 50 % is a warning, 50.1 % is critical', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 50, topThreeShare: 60),
        ConcentrationVerdict.warning,
      );
      expect(
        PoolConcentration.verdictFor(topOneShare: 50.1, topThreeShare: 60),
        ConcentrationVerdict.critical,
      );
    });

    test('top 3 of exactly 70 % is still ok, 70.1 % is a warning', () {
      expect(
        PoolConcentration.verdictFor(topOneShare: 30, topThreeShare: 70),
        ConcentrationVerdict.ok,
      );
      expect(
        PoolConcentration.verdictFor(topOneShare: 30, topThreeShare: 70.1),
        ConcentrationVerdict.warning,
      );
    });

    test('top 3 of exactly 80 % is critical — the one inclusive bound', () {
      // The asymmetry is the issue's, not an oversight: `Top 3 >= 80 %`
      // against `Top 1 > 50 %`. 79.9 must still be a warning.
      expect(
        PoolConcentration.verdictFor(topOneShare: 30, topThreeShare: 79.9),
        ConcentrationVerdict.warning,
      );
      expect(
        PoolConcentration.verdictFor(topOneShare: 30, topThreeShare: 80),
        ConcentrationVerdict.critical,
      );
    });
  });

  group('from — deriving the statement', () {
    test('reports the largest pool and the sum of the three largest', () {
      // The live payload of 2026-09-06.
      final concentration = PoolConcentration.from(
        _pools({
          'Foundry USA': 22.37,
          'AntPool': 18.42,
          'F2Pool': 17.11,
          'ViaBTC': 11.84,
          'SpiderPool': 11.18,
          'Luxor': 4.61,
          'Binance Pool': 3.95,
          'SECPOOL': 3.29,
          'MARA Pool': 2.63,
          'OCEAN': 1.97,
        }),
      );

      expect(concentration, isNotNull);
      expect(concentration!.topPoolName, 'Foundry USA');
      expect(concentration.topPoolShare, closeTo(22.37, 1e-9));
      expect(concentration.topThreeShare, closeTo(57.90, 1e-9));
      expect(concentration.verdict, ConcentrationVerdict.ok);
    });

    test('listedShare is what the list covers, not 100 %', () {
      // The ten entries of the live payload add up to 97.37 %. The gap is
      // unattributed and has no entry of its own — the screen may say what
      // the list covers, but must never turn the difference into a pool.
      final concentration = PoolConcentration.from(
        _pools({
          'Foundry USA': 22.37,
          'AntPool': 18.42,
          'F2Pool': 17.11,
          'ViaBTC': 11.84,
          'SpiderPool': 11.18,
          'Luxor': 4.61,
          'Binance Pool': 3.95,
          'SECPOOL': 3.29,
          'MARA Pool': 2.63,
          'OCEAN': 1.97,
        }),
      );

      expect(concentration!.listedShare, closeTo(97.37, 1e-9));
      expect(concentration.pools.length, 10);
    });

    test('sorts by share, so payload order does not decide the statement', () {
      // Deliberately ascending — the producer's sort is not contractual.
      final concentration = PoolConcentration.from(
        _pools({'Small': 5, 'Middle': 20, 'Largest': 41}),
      );

      expect(concentration!.topPoolName, 'Largest');
      expect(concentration.topPoolShare, 41);
      expect(concentration.pools.map((p) => p.name), [
        'Largest',
        'Middle',
        'Small',
      ]);
      // 41 > 40 with a top three of 66: the warning comes from the single
      // pool, which the ascending payload would have hidden unsorted.
      expect(concentration.verdict, ConcentrationVerdict.warning);
    });

    test('breaks ties by name so one payload yields one statement', () {
      final concentration = PoolConcentration.from(
        _pools({'Beta': 20, 'Alpha': 20, 'Gamma': 20}),
      );

      expect(concentration!.pools.map((p) => p.name), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
      expect(concentration.topPoolName, 'Alpha');
    });

    test('returns null below three pools — no substitute top-three value', () {
      expect(PoolConcentration.from(_pools({'Solo': 60, 'Other': 30})), isNull);
      expect(PoolConcentration.from(_pools({'Solo': 60})), isNull);
      expect(PoolConcentration.from(const []), isNull);
    });

    test('forms the statement from exactly three pools', () {
      final concentration = PoolConcentration.from(
        _pools({'A': 30, 'B': 25, 'C': 25}),
      );

      expect(concentration, isNotNull);
      expect(concentration!.topThreeShare, 80);
      expect(concentration.listedShare, 80);
      expect(concentration.verdict, ConcentrationVerdict.critical);
    });
  });
}
