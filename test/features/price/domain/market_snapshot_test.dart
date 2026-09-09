import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The moment every age in this file is measured from.
final DateTime _now = DateTime.utc(2026, 9, 9, 19);

void main() {
  group('the captured payload', () {
    test('reads every field the two statements rest on', () {
      final snapshot = MarketSnapshot.fromJson(loadJsonFixture('market.json'));

      expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 9, 18, 30, 59));
      expect(snapshot.currency, 'usd');
      expect(snapshot.ath, 126080);
      expect(snapshot.athDate, DateTime.utc(2025, 10, 6, 10, 57, 42));
      expect(snapshot.btcDominance, closeTo(58.38, 0.01));
      expect(snapshot.marketCap, 1578083556466);
    });
  });

  group('a missing field is a state', () {
    test('an absent high leaves the share untouched', () {
      final snapshot = MarketSnapshot.fromJson(const {
        'fetchedAt': '2026-09-09T18:30:59+00:00',
        'btcDominance': 58.38,
      });

      expect(snapshot.ath, isNull);
      expect(snapshot.athDate, isNull);
      expect(snapshot.btcDominance, 58.38);
    });

    test('an absent share leaves the high untouched', () {
      final snapshot = MarketSnapshot.fromJson(const {
        'fetchedAt': '2026-09-09T18:30:59+00:00',
        'ath': 126080,
      });

      expect(snapshot.btcDominance, isNull);
      expect(snapshot.ath, 126080);
    });

    test('an explicit null reads the same as an absent key', () {
      final snapshot = MarketSnapshot.fromJson(const {
        'fetchedAt': '2026-09-09T18:30:59+00:00',
        'ath': null,
        'btcDominance': null,
      });

      expect(snapshot.ath, isNull);
      expect(snapshot.btcDominance, isNull);
    });

    test('an unparseable date is a missing date, not a broken payload', () {
      final snapshot = MarketSnapshot.fromJson(const {
        'fetchedAt': '2026-09-09T18:30:59+00:00',
        'ath': 126080,
        'athDate': 'the sixth of October',
      });

      expect(snapshot.ath, 126080);
      expect(snapshot.athDate, isNull);
    });

    test('a fractional high is a figure, not a state change', () {
      // The contract writes `ath` as an integer and today it is one.
      // A producer that starts emitting a fraction must not empty the
      // statement.
      final snapshot = MarketSnapshot.fromJson(const {
        'fetchedAt': '2026-09-09T18:30:59+00:00',
        'ath': 126080.42,
      });

      expect(snapshot.ath, closeTo(126080.42, 0.001));
    });
  });

  group('an unreadable payload is an error', () {
    test('without fetchedAt nothing on screen can say how old it is', () {
      expect(
        () => MarketSnapshot.fromJson(const {'ath': 126080}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('freshness', () {
    MarketSnapshot at(Duration age) =>
        MarketSnapshot(fetchedAt: _now.subtract(age));

    test('inside the threshold the payload is fresh', () {
      expect(
        at(const Duration(minutes: 44)).freshnessAt(_now),
        PayloadFreshness.fresh,
      );
    });

    test('exactly at the threshold it is not yet stale', () {
      expect(
        at(const Duration(minutes: 45)).freshnessAt(_now),
        PayloadFreshness.fresh,
      );
    });

    test('three missed writes make it stale', () {
      expect(
        at(const Duration(minutes: 46)).freshnessAt(_now),
        PayloadFreshness.stale,
      );
    });

    test('exactly a day old has not yet earned the glyph', () {
      expect(
        at(const Duration(hours: 24)).freshnessAt(_now),
        PayloadFreshness.stale,
      );
    });

    test('past a day nobody is writing, and it says so', () {
      expect(
        at(const Duration(hours: 25)).freshnessAt(_now),
        PayloadFreshness.longStale,
      );
    });

    test('the age is measured against the clock it is given', () {
      expect(at(const Duration(minutes: 90)).ageAt(_now).inMinutes, 90);
    });
  });
}
