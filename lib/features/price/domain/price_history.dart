import 'market_snapshot.dart';

/// One published price, at the moment the producer recorded it.
class PricePoint {
  const PricePoint({required this.at, required this.price});

  /// Read from `timestamps[i]`, never derived from `i`.
  ///
  /// The spacing inside a document is nominal, not guaranteed: the last
  /// interval is always shorter than the rest because the last point is
  /// "now". ADR-0005 makes this the client's rule, and it is the reason
  /// the two arrays become a list of pairs here rather than a start plus
  /// a step.
  final DateTime at;

  final double price;
}

/// The part of `history-{range}.json` this slice reads.
///
/// The document publishes `range`, `currency`, `fetchedAt`, `timestamps`
/// and `prices`. `range` is not parsed — the caller asked for a range and
/// already knows which one — and `currency` is not parsed either, because
/// nothing this statement renders is an amount: the figure is a
/// percentage and the chart carries no axis values. #32 is what gives
/// amounts on this screen a currency, and it does not reach this
/// document.
///
/// **Two ways a payload is unreadable, and they are the only two.**
/// Without `fetchedAt` nothing on screen can say how old the series is.
/// With the two arrays at different lengths, which price belongs to which
/// moment is unknown — ADR-0005 guarantees them index-aligned and equally
/// long, so a document that breaks that is not a series with a gap, it is
/// a series whose pairing cannot be trusted. Everything else is a state:
/// a short series and an empty one are rendered, not raised.
class PriceHistory {
  const PriceHistory({required this.fetchedAt, required this.points});

  /// Reads the document published at `data/history-{range}.json`.
  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    final fetchedAt = json['fetchedAt'] as String?;
    if (fetchedAt == null) {
      throw const FormatException('history payload is missing fetchedAt');
    }

    final timestamps = json['timestamps'] as List<dynamic>? ?? const [];
    final prices = json['prices'] as List<dynamic>? ?? const [];
    if (timestamps.length != prices.length) {
      throw FormatException(
        'history payload pairs ${timestamps.length} timestamps '
        'with ${prices.length} prices',
      );
    }

    final points = <PricePoint>[];
    for (var i = 0; i < timestamps.length; i++) {
      final Object? at = timestamps[i];
      final Object? price = prices[i];
      // The producer drops a pair whose timestamp or price is not a
      // finite number rather than emitting `null` (ADR-0005). Skipping
      // one here costs a point; letting it through would put a NaN into
      // the chart's bounds and blank the whole curve.
      //
      // **A price of zero or less is dropped for the same reason**, not
      // kept as a low point. It is not a price, and as the first point of
      // a series it would make the change a division by nothing — which
      // is what lets `PriceTrend.from` have exactly one reason to decline
      // rather than two the screen would have to tell apart.
      if (at is! num || price is! num) continue;
      final value = price.toDouble();
      if (!value.isFinite || value <= 0) continue;
      points.add(
        PricePoint(
          at: DateTime.fromMillisecondsSinceEpoch(at.toInt(), isUtc: true),
          price: value,
        ),
      );
    }

    return PriceHistory(
      // The producer writes an explicit `+00:00` offset, so the parse
      // already yields UTC. `toUtc()` makes that independent of the
      // serialisation.
      fetchedAt: DateTime.parse(fetchedAt).toUtc(),
      points: points,
    );
  }

  /// `fetchedAt` — when the producer read its source, not when the app
  /// fetched the file.
  final DateTime fetchedAt;

  /// The series, oldest first. Empty is a state the screen renders.
  final List<PricePoint> points;

  /// How current this payload is at [now].
  ///
  /// The same two thresholds as `market.json`, and deliberately the same
  /// constants rather than a copy of the numbers: both documents come out
  /// of `cron-history` on the same fifteen-minute run, so a second
  /// definition here would be a second truth about one producer. #52
  /// derives both from the cadence itself.
  PayloadFreshness freshnessAt(DateTime now) {
    final age = ageAt(now);
    if (age > marketLongStaleAge) return PayloadFreshness.longStale;
    if (age > marketStaleAge) return PayloadFreshness.stale;
    return PayloadFreshness.fresh;
  }

  /// How long ago the producer wrote this payload, at [now].
  Duration ageAt(DateTime now) => now.toUtc().difference(fetchedAt);

  /// The moment the series starts, or `null` when it holds no points.
  DateTime? get from => points.isEmpty ? null : points.first.at;
}
