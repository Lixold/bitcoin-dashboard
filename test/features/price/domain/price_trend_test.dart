import 'package:bitcoin_dashboard/features/price/domain/price_history.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_trend.dart';
import 'package:flutter_test/flutter_test.dart';

/// The moment the constructed series ends on. Fixed rather than `now`, so
/// a span assertion means the same thing on every day the suite runs.
final DateTime _end = DateTime.utc(2026, 9, 10, 19, 43, 40);

/// A series of [count] points ending at [_end], one [step] apart, whose
/// price runs from [first] to [last] in equal increments.
///
/// The shape does not matter to any assertion here — only the ends do,
/// because the change is measured between them.
PriceHistory _history({
  required int count,
  double first = 100,
  double last = 100,
  Duration step = const Duration(hours: 1),
}) {
  final start = _end.subtract(step * (count - 1));
  return PriceHistory(
    fetchedAt: _end,
    points: [
      for (var i = 0; i < count; i++)
        PricePoint(
          at: start.add(step * i),
          price: count == 1
              ? first
              : first + (last - first) * (i / (count - 1)),
        ),
    ],
  );
}

void main() {
  group('verdictFor', () {
    test('reads a clear gain as rising and a clear loss as falling', () {
      expect(PriceTrend.verdictFor(21.67), TrendVerdict.rising);
      expect(PriceTrend.verdictFor(-32.26), TrendVerdict.falling);
    });

    test('reads a small move as sideways in both directions', () {
      expect(PriceTrend.verdictFor(1.38), TrendVerdict.sideways);
      expect(PriceTrend.verdictFor(-1.38), TrendVerdict.sideways);
      expect(PriceTrend.verdictFor(0), TrendVerdict.sideways);
    });

    test('exactly the band is already the level outside it', () {
      // The design writes both outer levels as "from ±5 %", so neither
      // boundary belongs to the flat band. Written as the constant, not
      // as 5.0: a changed band must move these two cases with it.
      expect(
        PriceTrend.verdictFor(PriceTrend.flatBandPercent),
        TrendVerdict.rising,
      );
      expect(
        PriceTrend.verdictFor(-PriceTrend.flatBandPercent),
        TrendVerdict.falling,
      );
    });

    test('just inside the band is still sideways', () {
      expect(PriceTrend.verdictFor(4.99), TrendVerdict.sideways);
      expect(PriceTrend.verdictFor(-4.99), TrendVerdict.sideways);
    });
  });

  group('from', () {
    test('measures the first point against the last', () {
      final trend = PriceTrend.from(_history(count: 100, first: 80, last: 100));

      expect(trend, isNotNull);
      expect(trend!.changePercent, closeTo(25, 1e-9));
      expect(trend.verdict, TrendVerdict.rising);
    });

    test('a fall is a negative change, not an inverted positive one', () {
      final trend = PriceTrend.from(_history(count: 100, first: 100, last: 80));

      expect(trend!.changePercent, closeTo(-20, 1e-9));
      expect(trend.verdict, TrendVerdict.falling);
    });

    test('ignores what the series does between its ends', () {
      // A round trip up and back down is a change of zero, however
      // dramatic the curve looks. The chart shows the shape; the
      // statement is about the two ends and says so in its info trigger.
      final start = _end.subtract(const Duration(hours: 99));
      final trend = PriceTrend.from(
        PriceHistory(
          fetchedAt: _end,
          points: [
            for (var i = 0; i < 100; i++)
              PricePoint(
                at: start.add(Duration(hours: i)),
                price: i < 50 ? 100 + i * 10 : 100 + (99 - i) * 10,
              ),
          ],
        ),
      );

      expect(trend!.changePercent, closeTo(0, 1e-9));
      expect(trend.verdict, TrendVerdict.sideways);
    });

    test('declines a series shorter than the minimum', () {
      expect(
        PriceTrend.from(_history(count: PriceTrend.minPoints - 1)),
        isNull,
      );
      expect(PriceTrend.from(_history(count: 3)), isNull);
      expect(PriceTrend.from(_history(count: 0)), isNull);
    });

    test('exactly the minimum is long enough', () {
      // The boundary belongs to the state that says something: 30 points
      // carry a trend, 29 do not.
      expect(PriceTrend.from(_history(count: PriceTrend.minPoints)), isNotNull);
    });
  });

  group('span', () {
    test('a day of five-minute points reads as 24 hours, not 23', () {
      // The live payload: 288 points, the last interval short because the
      // last point is "now". Truncating instead of rounding would put
      // "over 23 hours" under a tab labelled 1D.
      final trend = PriceTrend.from(
        _history(count: 288, step: const Duration(minutes: 5)),
      );

      expect(trend!.readsInHours, isTrue);
      expect(trend.spanHours, 24);
    });

    test('a week of hourly points reads as 7 days', () {
      final trend = PriceTrend.from(_history(count: 169));

      expect(trend!.readsInHours, isFalse);
      expect(trend.spanDays, 7);
    });

    test('a year whose last interval is short still reads as 365 days', () {
      // The live 1Y document: 366 points, 364 full days and a last
      // interval of 71 000 s because the last point is "now". That is
      // 364.82 days, and the reader is told 365 — the range they picked.
      final points = <PricePoint>[];
      var at = _end.subtract(
        const Duration(days: 364) + const Duration(milliseconds: 71000000),
      );
      for (var i = 0; i < 365; i++) {
        points.add(PricePoint(at: at, price: 100));
        at = at.add(const Duration(days: 1));
      }
      points.add(PricePoint(at: _end, price: 100));

      final trend = PriceTrend.from(
        PriceHistory(fetchedAt: _end, points: points),
      );

      expect(points.length, 366);
      expect(trend!.spanDays, 365);
      expect(trend.readsInHours, isFalse);
    });

    test('the period stops reading in hours at a day and a half', () {
      // 35 hours still rounds to one day and is said in hours; 36 rounds
      // to two and is said in days. The switch is a rounding boundary, so
      // it is asserted rather than left to the reader of `readsInHours`.
      expect(
        PriceTrend.from(
          _history(count: 36, step: const Duration(hours: 1)),
        )!.readsInHours,
        isTrue,
        reason: '35 hours is one day, and one day is said as 35 hours',
      );
      expect(
        PriceTrend.from(
          _history(count: 37, step: const Duration(hours: 1)),
        )!.readsInHours,
        isFalse,
        reason: '36 hours rounds to two days',
      );
    });
  });
}
