import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_history.dart';
import 'package:flutter_test/flutter_test.dart';

/// The capture's own stamp, and the moment every age here is measured
/// against.
final DateTime _fetchedAt = DateTime.utc(2026, 9, 10, 19, 45, 39);

Map<String, dynamic> _payload({
  List<Object?>? timestamps,
  List<Object?>? prices,
  String? fetchedAt = '2026-09-10T19:45:39+00:00',
}) => <String, dynamic>{
  'fetchedAt': ?fetchedAt,
  'range': '1W',
  'currency': 'usd',
  'timestamps': timestamps ?? <Object?>[1788983400000, 1788983700000],
  'prices': prices ?? <Object?>[78310.95, 78213.21],
};

void main() {
  group('fromJson', () {
    test('pairs each price with the timestamp at its own index', () {
      final history = PriceHistory.fromJson(_payload());

      expect(history.points, hasLength(2));
      expect(
        history.points.first.at,
        DateTime.fromMillisecondsSinceEpoch(1788983400000, isUtc: true),
      );
      expect(history.points.first.price, 78310.95);
      expect(history.points.last.price, 78213.21);
    });

    test('reads the producer stamp as UTC', () {
      expect(PriceHistory.fromJson(_payload()).fetchedAt, _fetchedAt);
      expect(PriceHistory.fromJson(_payload()).fetchedAt.isUtc, isTrue);
    });

    test('an integer price is a price', () {
      // The contract writes prices fractional and the producer does too,
      // but a whole number is valid JSON for the same field.
      final history = PriceHistory.fromJson(
        _payload(prices: <Object?>[78310, 78213]),
      );

      expect(history.points.first.price, 78310.0);
    });

    test('an empty series is a state, not an error', () {
      final history = PriceHistory.fromJson(
        _payload(timestamps: <Object?>[], prices: <Object?>[]),
      );

      expect(history.points, isEmpty);
      expect(history.from, isNull);
    });

    test('a payload without the arrays is an empty series', () {
      final history = PriceHistory.fromJson(const <String, dynamic>{
        'fetchedAt': '2026-09-10T19:45:39+00:00',
      });

      expect(history.points, isEmpty);
    });

    test('without fetchedAt the payload cannot be read', () {
      // Nothing on screen could then say how old the series is, and a
      // series of unknown age is worse than an absent one.
      expect(
        () => PriceHistory.fromJson(_payload(fetchedAt: null)),
        throwsA(isA<FormatException>()),
      );
    });

    test('arrays of different lengths cannot be read', () {
      // Not a series with a gap — a series whose pairing is unknown.
      // ADR-0005 guarantees them index-aligned and equally long.
      expect(
        () => PriceHistory.fromJson(
          _payload(
            timestamps: <Object?>[1788983400000, 1788983700000],
            prices: <Object?>[78310.95],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('drops a pair that is not a finite, positive price', () {
      // The producer drops these rather than emitting null. A NaN reaching
      // the chart would blank the whole curve, and a zero as the first
      // point would make the change a division by nothing.
      final history = PriceHistory.fromJson(
        _payload(
          timestamps: <Object?>[1, 2, 3, 4, 5],
          prices: <Object?>[double.nan, 0, -5, null, 78310.95],
        ),
      );

      expect(history.points, hasLength(1));
      expect(history.points.single.price, 78310.95);
    });

    test('a timestamp past the 32-bit range survives the parse', () {
      // ADR-0005 records the `Number(p[0]) | 0` wrap that shipped in
      // cron-history once. Dart has 64-bit ints, and this is the guard
      // that says so.
      final history = PriceHistory.fromJson(
        _payload(timestamps: <Object?>[1788983400000], prices: <Object?>[1.0]),
      );

      expect(history.points.single.at.year, 2026);
    });
  });

  group('freshness', () {
    test('inside three quarters of an hour it is fresh', () {
      final history = PriceHistory.fromJson(_payload());

      expect(
        history.freshnessAt(_fetchedAt.add(const Duration(minutes: 45))),
        PayloadFreshness.fresh,
        reason: 'the bound is strict — exactly 45 minutes is not yet stale',
      );
      expect(
        history.freshnessAt(
          _fetchedAt.add(const Duration(minutes: 45, seconds: 1)),
        ),
        PayloadFreshness.stale,
      );
    });

    test('a day without a write earns the louder stage', () {
      final history = PriceHistory.fromJson(_payload());

      expect(
        history.freshnessAt(_fetchedAt.add(const Duration(hours: 24))),
        PayloadFreshness.stale,
      );
      expect(
        history.freshnessAt(
          _fetchedAt.add(const Duration(hours: 24, seconds: 1)),
        ),
        PayloadFreshness.longStale,
      );
    });

    test('the age is measured against a now the caller names', () {
      final history = PriceHistory.fromJson(_payload());

      expect(
        history.ageAt(_fetchedAt.add(const Duration(minutes: 4))),
        const Duration(minutes: 4),
      );
    });
  });
}
