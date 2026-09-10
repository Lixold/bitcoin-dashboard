import 'package:bitcoin_dashboard/features/price/domain/ath_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('boundaries', () {
    // Both thresholds belong to the level above them. These four cases
    // are the reason the operators in `verdictFor` are not symmetric —
    // do not "harmonise" them without changing these expectations.
    test('exactly at the near threshold is already a correction', () {
      expect(
        AthDistance.verdictFor(percentBelow: 10, isAtOrAbove: false),
        AthVerdict.correction,
      );
    });

    test('a hair under the near threshold is still near', () {
      expect(
        AthDistance.verdictFor(percentBelow: 9.99, isAtOrAbove: false),
        AthVerdict.near,
      );
    });

    test('exactly at the deep threshold is already deep', () {
      expect(
        AthDistance.verdictFor(percentBelow: 35, isAtOrAbove: false),
        AthVerdict.deep,
      );
    });

    test('a hair under the deep threshold is still a correction', () {
      expect(
        AthDistance.verdictFor(percentBelow: 34.99, isAtOrAbove: false),
        AthVerdict.correction,
      );
    });
  });

  group('derivation', () {
    test('measures the distance against the published high', () {
      final distance = AthDistance.from(high: 126080, price: 78679.4)!;

      expect(distance.percentBelow, closeTo(37.6, 0.05));
      expect(distance.percentOfHigh, closeTo(62.4, 0.05));
      expect(distance.verdict, AthVerdict.deep);
    });

    test('a price at the high is neither below it nor a correction', () {
      final distance = AthDistance.from(high: 126080, price: 126080)!;

      expect(distance.percentBelow, 0);
      expect(distance.percentOfHigh, 100);
      expect(distance.verdict, AthVerdict.atOrAbove);
    });

    test('a price above the published high never reads as negative', () {
      // Reachable in normal operation: the payload is up to fifteen
      // minutes old, so a new high shows on the live socket first. The
      // sentence for this level is the only one that does not say "below
      // the high".
      final distance = AthDistance.from(high: 126080, price: 130000)!;

      expect(distance.percentBelow, 0);
      expect(distance.verdict, AthVerdict.atOrAbove);
      expect(
        distance.percentOfHigh,
        greaterThan(100),
        reason: 'the meter clamps this itself; the figure stays honest',
      );
    });

    test('no statement without a high', () {
      expect(AthDistance.from(high: null, price: 78679.4), isNull);
    });

    test('no statement without a price', () {
      expect(AthDistance.from(high: 126080, price: null), isNull);
    });

    test('a high of zero is not a reference to divide by', () {
      expect(AthDistance.from(high: 0, price: 78679.4), isNull);
    });
  });
}
