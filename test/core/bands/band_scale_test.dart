import 'package:bitcoin_dashboard/core/bands/band_scale.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/domain/pool_concentration.dart';
import 'package:bitcoin_dashboard/features/price/domain/ath_distance.dart';
import 'package:bitcoin_dashboard/features/price/domain/market_dominance.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_trend.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Level { calm, watch, alarm }

/// A scale with one inclusive and one exclusive bound, so both readings
/// of "on the line" are covered by the same fixture.
const BandScale<_Level> _scale = BandScale<_Level>(<Band<_Level>>[
  Band(_Level.calm, from: 0, tone: StatementTone.positive),
  Band(
    _Level.watch,
    from: 40,
    fromIsInclusive: false,
    tone: StatementTone.warning,
  ),
  Band(_Level.alarm, from: 80, tone: StatementTone.negative),
]);

void main() {
  group('bandFor', () {
    test('an inclusive bound belongs to the band above it', () {
      expect(_scale.bandFor(80).key, _Level.alarm);
      expect(_scale.bandFor(79.99).key, _Level.watch);
    });

    test('an exclusive bound belongs to the band below it', () {
      // The distinction #68 writes as "> 40 %": exactly 40.0 is not yet
      // the next level, a hair above it is.
      expect(_scale.bandFor(40).key, _Level.calm);
      expect(_scale.bandFor(40.0001).key, _Level.watch);
    });

    test('a value under the lowest bound still lands in a band', () {
      // The scale is total: the lowest band catches everything below it,
      // so no caller has to handle "no band".
      expect(_scale.bandFor(-12).key, _Level.calm);
    });

    test('the tone travels with the band', () {
      expect(_scale.bandFor(90).tone, StatementTone.negative);
      expect(_scale.bandFor(50).tone, StatementTone.warning);
      expect(_scale.bandFor(0).tone, StatementTone.positive);
    });
  });

  group('bounds', () {
    test('upperBoundOf is the next band down the list', () {
      expect(_scale.upperBoundOf(_scale.bands.first), 40);
      expect(_scale.upperBoundOf(_scale.bands[1]), 80);
    });

    test('the last band is unbounded', () {
      // A ceiling is a property of the axis that draws the scale, not of
      // the classification — the distance to the all-time high has none.
      expect(_scale.upperBoundOf(_scale.bands.last), isNull);
    });

    test('boundaries are the interior bounds only', () {
      // Where the verdict changes. The lowest band's `from` is where the
      // scale starts, not a line a reading crosses.
      expect(_scale.boundaries, [40, 80]);
    });
  });

  // The check issue #52 asks for before the mechanism gets a consumer:
  // could it express the threshold matrices the app already has? Each
  // group below rebuilds one of them as a scale and holds it against the
  // matrix's own `verdictFor` on both sides of every boundary. Nothing
  // here migrates production code — that is a follow-up — these are the
  // arithmetic, run rather than asserted on paper.
  group('expresses the four matrices already in the app', () {
    test('AthDistance — two inclusive bounds', () {
      const scale = BandScale<AthVerdict>(<Band<AthVerdict>>[
        Band(AthVerdict.near, from: 0, tone: StatementTone.positive),
        Band(
          AthVerdict.correction,
          from: AthDistance.nearThreshold,
          tone: StatementTone.warning,
        ),
        Band(
          AthVerdict.deep,
          from: AthDistance.deepThreshold,
          tone: StatementTone.negative,
        ),
      ]);

      for (final percentBelow in [0.0, 9.99, 10.0, 34.99, 35.0, 60.0]) {
        expect(
          scale.bandFor(percentBelow).key,
          AthDistance.verdictFor(
            percentBelow: percentBelow,
            isAtOrAbove: false,
          ),
          reason: '$percentBelow % below the high',
        );
      }

      // `atOrAbove` is the one level the scale does **not** express, and
      // it is not a threshold: it answers "is the live price at or over
      // the published high", a different figure entirely. A consumer
      // resolves it before consulting the scale.
      expect(
        AthDistance.verdictFor(percentBelow: 0, isAtOrAbove: true),
        AthVerdict.atOrAbove,
      );
    });

    test('MarketDominance — two inclusive bounds', () {
      const scale = BandScale<DominanceVerdict>(<Band<DominanceVerdict>>[
        Band(DominanceVerdict.low, from: 0, tone: StatementTone.warning),
        Band(
          DominanceVerdict.stable,
          from: MarketDominance.lowThreshold,
          tone: StatementTone.positive,
        ),
        Band(
          DominanceVerdict.high,
          from: MarketDominance.highThreshold,
          tone: StatementTone.warning,
        ),
      ]);

      for (final share in [0.0, 44.99, 45.0, 54.99, 55.0, 100.0]) {
        expect(
          scale.bandFor(share).key,
          MarketDominance.verdictFor(share),
          reason: '$share % share',
        );
      }
    });

    test('PriceTrend — an exclusive bound and an unbounded floor', () {
      const scale = BandScale<TrendVerdict>(<Band<TrendVerdict>>[
        Band(
          TrendVerdict.falling,
          from: double.negativeInfinity,
          tone: StatementTone.negative,
        ),
        Band(
          TrendVerdict.sideways,
          from: -PriceTrend.flatBandPercent,
          fromIsInclusive: false,
          tone: StatementTone.neutral,
        ),
        Band(
          TrendVerdict.rising,
          from: PriceTrend.flatBandPercent,
          tone: StatementTone.positive,
        ),
      ]);

      for (final change in [-40.0, -5.0, -4.99, 0.0, 4.99, 5.0, 40.0]) {
        expect(
          scale.bandFor(change).key,
          PriceTrend.verdictFor(change),
          reason: '$change % change',
        );
      }
    });

    test('PoolConcentration — two figures, mixed bounds, most severe wins', () {
      const topOne = BandScale<ConcentrationVerdict>(
        <Band<ConcentrationVerdict>>[
          Band(ConcentrationVerdict.ok, from: 0, tone: StatementTone.positive),
          Band(
            ConcentrationVerdict.warning,
            from: PoolConcentration.topOneWarningThreshold,
            fromIsInclusive: false,
            tone: StatementTone.warning,
          ),
          Band(
            ConcentrationVerdict.critical,
            from: PoolConcentration.topOneCriticalThreshold,
            fromIsInclusive: false,
            tone: StatementTone.negative,
          ),
        ],
      );
      const topThree = BandScale<ConcentrationVerdict>(
        <Band<ConcentrationVerdict>>[
          Band(ConcentrationVerdict.ok, from: 0, tone: StatementTone.positive),
          Band(
            ConcentrationVerdict.warning,
            from: PoolConcentration.topThreeWarningThreshold,
            fromIsInclusive: false,
            tone: StatementTone.warning,
          ),
          // The one inclusive line in the same matrix: "Top 3 ≥ 80 %".
          Band(
            ConcentrationVerdict.critical,
            from: PoolConcentration.topThreeCriticalThreshold,
            tone: StatementTone.negative,
          ),
        ],
      );

      // Two scales and the more severe of the two readings — severity is
      // the position in the list, which is why a scale is ordered.
      ConcentrationVerdict combined(double one, double three) {
        final a = topOne.bandFor(one);
        final b = topThree.bandFor(three);
        return topOne.bands.indexOf(a) >= topThree.bands.indexOf(b)
            ? a.key
            : b.key;
      }

      const probes = <(double, double)>[
        (22.37, 57.90),
        (40.0, 70.0),
        (40.01, 70.0),
        (40.0, 70.01),
        (50.0, 79.99),
        (50.01, 79.99),
        (40.0, 80.0),
        (60.0, 90.0),
      ];
      for (final (one, three) in probes) {
        expect(
          combined(one, three),
          PoolConcentration.verdictFor(topOneShare: one, topThreeShare: three),
          reason: 'top 1 $one %, top 3 $three %',
        );
      }
    });
  });
}
