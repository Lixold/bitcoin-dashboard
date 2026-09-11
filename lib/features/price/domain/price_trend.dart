import 'price_history.dart';

/// Which way the price has moved over the selected range.
enum TrendVerdict { rising, sideways, falling }

/// The change between the first and the last point of a range, as a
/// verdict the screen can state in words.
///
/// The statement is the direction; the curve underneath is only its
/// evidence. Period high, period low and the position inside that span
/// answer a second question and would need a second statement — they are
/// deliberately out of this slice.
class PriceTrend {
  const PriceTrend({
    required this.changePercent,
    required this.span,
    required this.verdict,
  });

  /// The flat band, in percent: inside it the price is neither rising nor
  /// falling.
  ///
  /// **One band for all five ranges.** Five per cent over a day is not
  /// the same event as five per cent over a year, and if those are ever
  /// to read differently it is one number per range — which is issue #52,
  /// not a second constant smuggled in here.
  static const double flatBandPercent = 5;

  /// Fewest points a range needs before a direction is stated.
  ///
  /// A line through three points looks exactly like a trend and is none.
  /// Below this the screen says what it has instead of drawing a shape
  /// the reader would read as a claim.
  static const int minPoints = 30;

  /// The change from the first to the last point, in percent. Negative
  /// when the price fell.
  final double changePercent;

  /// The distance between the first and the last point — measured, not
  /// the nominal length of the range. The two differ: `1Y` spans a few
  /// hours short of 365 days.
  final Duration span;

  final TrendVerdict verdict;

  /// Derives the trend, or returns `null` when [history] is too short to
  /// carry one.
  ///
  /// That is the only reason it declines. A price of zero or less never
  /// reaches the series — [PriceHistory] drops it as a broken pair — so
  /// the first point is always a usable reference.
  static PriceTrend? from(PriceHistory history) {
    final points = history.points;
    if (points.length < minPoints) return null;

    final first = points.first;
    final last = points.last;
    final change = (last.price - first.price) / first.price * 100;

    return PriceTrend(
      changePercent: change,
      span: last.at.difference(first.at),
      verdict: verdictFor(change),
    );
  }

  /// Applies the flat band.
  ///
  /// **Both bounds belong to the level outside them.** Exactly +5.0 % is
  /// already rising and exactly −5.0 % is already falling — the design
  /// writes the two outer levels as "from ±{band} %", the same reading
  /// `AthDistance.verdictFor` gives its matrix. Both boundaries are
  /// tested.
  static TrendVerdict verdictFor(double changePercent) {
    if (changePercent >= flatBandPercent) return TrendVerdict.rising;
    if (changePercent <= -flatBandPercent) return TrendVerdict.falling;
    return TrendVerdict.sideways;
  }

  /// [span] in whole hours, rounded.
  ///
  /// Rounded rather than truncated: a `1D` document spans a few minutes
  /// under 24 hours because its last point is "now", and "over 23 hours"
  /// under a tab labelled 1D reads as a bug.
  int get spanHours => (span.inMinutes / 60).round();

  /// [span] in whole days, rounded — same reason.
  int get spanDays => (span.inHours / 24).round();

  /// Whether the period is better said in hours than in days.
  ///
  /// Only the shortest range falls here, where "1 day" is a clumsy way to
  /// write the 24 hours the design names.
  bool get readsInHours => spanDays < 2;
}
