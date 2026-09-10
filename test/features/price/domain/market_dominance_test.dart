import 'package:bitcoin_dashboard/features/price/domain/market_dominance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('boundaries', () {
    test('exactly at the high threshold is already dominant', () {
      expect(MarketDominance.verdictFor(55), DominanceVerdict.high);
    });

    test('a hair under the high threshold is still leading', () {
      expect(MarketDominance.verdictFor(54.99), DominanceVerdict.stable);
    });

    test('exactly at the low threshold is still leading', () {
      expect(MarketDominance.verdictFor(45), DominanceVerdict.stable);
    });

    test('a hair under the low threshold is a declining share', () {
      expect(MarketDominance.verdictFor(44.99), DominanceVerdict.low);
    });
  });

  group('derivation', () {
    test('reads the payload share and derives the remainder', () {
      final dominance = MarketDominance.from(58.38111273322796)!;

      expect(dominance.share, closeTo(58.38, 0.01));
      expect(dominance.rest, closeTo(41.62, 0.01));
      expect(dominance.verdict, DominanceVerdict.high);
    });

    test('the two bars always account for the whole market', () {
      for (final share in [0.0, 12.5, 45.0, 58.4, 100.0]) {
        final dominance = MarketDominance.from(share)!;
        expect(dominance.share + dominance.rest, closeTo(100, 1e-9));
      }
    });

    test('no statement without a share', () {
      expect(MarketDominance.from(null), isNull);
    });

    test('a share outside 0–100 is not a share', () {
      // Not clamped: a payload claiming 130 % of the market is not a
      // figure to draw, it is a document to ignore.
      expect(MarketDominance.from(130), isNull);
      expect(MarketDominance.from(-1), isNull);
    });
  });
}
