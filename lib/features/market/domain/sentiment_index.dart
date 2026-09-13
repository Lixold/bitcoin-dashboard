import '../../../core/bands/band_scale.dart';
import 'sentiment_band.dart';

/// One published index value and the calendar day it belongs to.
class SentimentPoint {
  const SentimentPoint({required this.at, required this.value});

  /// UTC midnight of the day this value was published for.
  ///
  /// **A calendar day, not an instant.** alternative.me stamps every
  /// entry at 00:00 UTC, so anything that shows this date has to format
  /// it in UTC: converted to local time it moves to the previous day
  /// everywhere west of Greenwich, and the screen would then report a
  /// value under yesterday's date.
  final DateTime at;

  /// The index itself, 0–100.
  final int value;
}

/// Which of the three insight sentences a reading calls for.
enum SentimentInsight {
  /// The current band is younger than the window: the sentence names the
  /// day the run began.
  switched,

  /// Every value in the window sits in the current band: there is no day
  /// to name, so the sentence says so instead.
  steady,

  /// The run is too short to be worth dating — the sentence falls back to
  /// the range of the window.
  short,
}

/// The Fear & Greed index over the window the statement is about.
///
/// The payload is `GET https://api.alternative.me/fng/?limit=30`
/// (ADR-0002). Everything the screen states is derived here: no widget
/// reads a raw value, classifies a number, or works out how long a band
/// has held.
///
/// **Three traps in this payload, all of them confirmed against the live
/// source on 2026-09-13:**
///
///  * every field is a string, the numeric ones included;
///  * `time_until_update` exists on the first element only — it is
///    deliberately not read at all, see below;
///  * `metadata.error` is the source's own failure channel and arrives
///    with HTTP 200, so a body that parses is not yet a body that says
///    anything.
///
/// **`time_until_update` is not the cache's TTL.** The field names the
/// seconds until the next value is published, which on a morning read is
/// most of a day; honouring it would leave the app not asking for ten
/// hours and contradict the one-hour cadence ADR-0002 records for this
/// source. The hour stays in `SentimentCache`, and this class never sees
/// the field.
///
/// **The window's age is the value's own date, never the moment of the
/// fetch.** A value is published once a day and carries the day it is
/// for, which is why this slice has no stale state: a copy served from
/// cache during an outage still shows the date of the value it holds and
/// is honest without a second marker. `CachedPayload.cachedAt` answers a
/// different question — may the app skip the request — and must not reach
/// the screen.
class SentimentIndex {
  const SentimentIndex({required this.points});

  /// Reads the document `api.alternative.me/fng/` returns.
  ///
  /// Entries whose value or timestamp cannot be read, and values outside
  /// the 0–100 the index is defined on, are dropped rather than raised:
  /// one unusable day out of thirty costs a point on the curve, while a
  /// raised exception would cost the whole statement. A payload that
  /// leaves *no* usable point is the error state — there is no empty
  /// state here, because a window with nothing in it says nothing.
  factory SentimentIndex.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    if (metadata is Map<String, dynamic>) {
      final error = metadata['error'];
      // Not a transport failure: HTTP 200 with a message in the body.
      // The reader cannot act on the difference, so it lands in the same
      // error state — but it has to be noticed first.
      if (error != null) {
        throw FormatException('alternative.me reported: $error');
      }
    }

    final entries = json['data'];
    if (entries is! List) {
      throw const FormatException('fng payload carries no data array');
    }

    final points = <SentimentPoint>[];
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final value = int.tryParse('${entry['value']}');
      final seconds = int.tryParse('${entry['timestamp']}');
      if (value == null || seconds == null) continue;
      if (value < sentimentScaleMin || value > sentimentScaleMax) continue;
      points.add(
        SentimentPoint(
          at: DateTime.fromMillisecondsSinceEpoch(
            seconds * Duration.millisecondsPerSecond,
            isUtc: true,
          ),
          value: value,
        ),
      );
    }

    if (points.isEmpty) {
      throw const FormatException('fng payload carries no readable value');
    }

    // Sorted defensively. The source serves newest first today, which is
    // the opposite of the order everything below reads in, and that order
    // is not part of any contract this app can hold it to.
    points.sort((a, b) => a.at.compareTo(b.at));
    return SentimentIndex(points: List.unmodifiable(points));
  }

  /// How many days the statement speaks about.
  ///
  /// It is the `limit` the request asks for and the number the sentences
  /// name. The two are the same constant on purpose: the copy says "over
  /// the last 30 days", and a window that silently became 25 would make
  /// that sentence false.
  static const int windowDays = 30;

  /// Shortest run the insight sentence will put a date on.
  ///
  /// Below it, "inside the Greed band without interruption since
  /// 12 September" claims a continuity that one or two days do not have —
  /// the sentence would read as a trend where there is a single value.
  static const int minimumRunDays = 3;

  /// The window, oldest first.
  final List<SentimentPoint> points;

  /// The current reading — the most recent day in the window.
  SentimentPoint get latest => points.last;

  /// The band [latest] falls into, with its tone and its bounds.
  Band<SentimentBand> get band =>
      sentimentScale.bandFor(latest.value.toDouble());

  /// Mean of the window, unrounded. The screen rounds it for display; the
  /// exact value is what a test can hold this to.
  double get mean =>
      points.fold<int>(0, (sum, point) => sum + point.value) / points.length;

  /// Lowest value in the window.
  int get lowest =>
      points.map((point) => point.value).reduce((a, b) => a < b ? a : b);

  /// Highest value in the window.
  int get highest =>
      points.map((point) => point.value).reduce((a, b) => a > b ? a : b);

  /// How many days the current band has held without interruption,
  /// counting back from [latest].
  ///
  /// **The current run, not the first band change in the window.** A
  /// window that switches twice has one current run and two changes, and
  /// the sentence is about the one the reader is standing in.
  int get runLength {
    final current = band.key;
    var length = 0;
    for (var i = points.length - 1; i >= 0; i--) {
      if (sentimentScale.bandFor(points[i].value.toDouble()).key != current) {
        break;
      }
      length++;
    }
    return length;
  }

  /// The day the current run began.
  DateTime get runStart => points[points.length - runLength].at;

  /// Which sentence the window calls for.
  ///
  /// [SentimentInsight.steady] additionally requires a full window: its
  /// wording names all thirty values, so a short payload — which the
  /// source has never served, but which nothing prevents — takes the
  /// dated sentence instead of making a count-specific claim about a
  /// window that is not that long.
  SentimentInsight get insight {
    final run = runLength;
    if (run < minimumRunDays) return SentimentInsight.short;
    if (run == points.length && points.length == windowDays) {
      return SentimentInsight.steady;
    }
    return SentimentInsight.switched;
  }
}
