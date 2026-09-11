/// Age at which the conversion rate stops being read as current and says
/// how old it is.
///
/// **Four days, not the 45 minutes the market payloads use.** The ECB
/// publishes once on each working day and not at all at the weekend, so a
/// Friday rate read on a Sunday is the normal case and has nothing to
/// report. Three days covers a weekend, four covers a weekend with a
/// public holiday attached to it; past that the ECB has skipped a working
/// day and the reader should know. A shorter threshold would turn amber
/// every Saturday and teach the reader to ignore the colour.
///
/// **Stale is a state of the rate, not a failure of the fetch.** Amounts
/// past this age stay converted and on screen with an age hint; they are
/// never withdrawn.
const Duration fxStaleAge = Duration(days: 4);

/// The currency every amount in this app is published in.
///
/// Both sources agree on it and neither is asked: `market.json` declares
/// `usd` in the payload, and the live price comes from the Binance pair
/// `BTCUSDT`, whose quote currency `PriceTick.quoteCurrencyOf` reports as
/// `USD`. Conversion is therefore a single lookup in one row rather than
/// a walk through a base currency — which is why [FxRates] keeps that row
/// and drops the rest of the matrix.
const String sourceCurrency = 'USD';

/// The part of `fx-rates.json` this app reads: one row of the matrix, and
/// the moment the producer read it.
///
/// **One row, not thirty.** The published document is a full 30 × 30
/// matrix so that a client never has to invert a rate (ADR-0005). This app
/// converts from exactly one currency — [sourceCurrency] — so the other
/// twenty-nine rows answer a question nothing here asks. The *fixture*
/// stays whole, because a fixture is a capture of what the CDN served; the
/// model is free to read only what it needs.
///
/// `fetchedAt` is the one field without which the document is unreadable:
/// the screen states how old a rate is before it trusts it, and a rate
/// whose age is unknown is worse than an absent one — the same rule
/// `MarketSnapshot` follows.
class FxRates {
  const FxRates({
    required this.fetchedAt,
    required this.currencies,
    required this.fromSource,
  });

  /// Reads the document published at `data/fx-rates.json`.
  factory FxRates.fromJson(Map<String, dynamic> json) {
    final meta = json['_meta'] as Map<String, dynamic>?;
    final fetchedAt = meta?['fetchedAt'] as String?;
    if (fetchedAt == null) {
      throw const FormatException('fx-rates.json is missing _meta.fetchedAt');
    }

    final row = <String, double>{};
    final published = json[sourceCurrency];
    if (published is Map<String, dynamic>) {
      for (final entry in published.entries) {
        // The matrix writes identity rates as the integer `1` and every
        // other rate as a fraction, so the row is `num` and not `double`.
        // A quote the producer could not compute is left out rather than
        // carried as a rate of zero.
        final rate = entry.value;
        if (rate is num && rate.isFinite && rate > 0) {
          row[entry.key.toUpperCase()] = rate.toDouble();
        }
      }
    }

    return FxRates(
      // The producer writes an explicit `+00:00` offset, so the parse
      // already yields UTC. `toUtc()` makes that independent of the
      // serialisation.
      fetchedAt: DateTime.parse(fetchedAt).toUtc(),
      currencies: _offerable(meta?['currencies'], row),
      fromSource: Map.unmodifiable(row),
    );
  }

  /// `_meta.fetchedAt` — when the producer read the ECB, not when the app
  /// fetched the file.
  final DateTime fetchedAt;

  /// The currencies this document can convert into, in the order the
  /// producer lists them.
  ///
  /// This is what the picker offers, so it is filtered by [fromSource]
  /// rather than taken from `_meta.currencies` alone: the meta is the
  /// producer's announcement, the row is the rate a selection actually
  /// looks up, and a code announced without a rate behind it would be an
  /// option the app cannot honour. The published document agrees on both;
  /// where it stops agreeing, the rate wins.
  final List<String> currencies;

  /// Rates from [sourceCurrency] into every currency the document quotes,
  /// keyed by upper-case ISO 4217 code.
  final Map<String, double> fromSource;

  /// The factor that turns an amount in [from] into one in [to], or `null`
  /// when this document cannot say.
  ///
  /// Only [sourceCurrency] has a row here, so any other `from` reports
  /// `null` rather than a rate that happens to look plausible — an amount
  /// the app cannot convert is rendered in the currency it arrived in, and
  /// that decision needs the `null` to make it.
  double? rate({required String from, required String to}) {
    final source = from.toUpperCase();
    final target = to.toUpperCase();
    if (source == target) return 1;
    if (source != sourceCurrency) return null;
    return fromSource[target];
  }

  /// Whether the document quotes anything at all.
  ///
  /// A payload that parses but carries no rates converts nothing, and the
  /// screen has to treat it exactly like a missing one.
  bool get isEmpty => fromSource.isEmpty;

  /// How long ago the producer read this rate, at [now].
  Duration ageAt(DateTime now) => now.toUtc().difference(fetchedAt);

  /// Whether the rate has outlived [fxStaleAge] at [now].
  ///
  /// The bound is strict, as it is on `MarketSnapshot`: a rate of exactly
  /// four days has not yet earned the hint.
  bool isStaleAt(DateTime now) => ageAt(now) > fxStaleAge;

  /// Whether this rate was published on the day [now] falls on.
  ///
  /// **Asked in UTC, deliberately.** The rate is stamped in UTC and the
  /// pill that reads it labels its time `UTC`, so the day it belongs to is
  /// a UTC day; asking in the reader's zone would also make the answer —
  /// and every test of it — depend on the machine the suite runs on.
  ///
  /// The screen uses it to decide whether naming the weekday tells the
  /// reader anything: on the day itself it does not, and after it the
  /// weekday is what explains a gap the ECB's calendar left.
  bool isFromDayOf(DateTime now) {
    final today = now.toUtc();
    return fetchedAt.year == today.year &&
        fetchedAt.month == today.month &&
        fetchedAt.day == today.day;
  }

  /// [currencies], honouring the producer's order and the row's veto.
  static List<String> _offerable(Object? meta, Map<String, double> row) {
    final announced = meta is List
        ? [
            for (final code in meta)
              if (code is String) code.toUpperCase(),
          ]
        : const <String>[];
    final offerable = [
      for (final code in announced)
        if (row.containsKey(code)) code,
    ];
    // No usable meta is not the same as no rates: fall back to what the
    // row itself quotes, in an order the reader can scan.
    if (offerable.isEmpty) return List.unmodifiable(row.keys.toList()..sort());
    return List.unmodifiable(offerable);
  }
}
