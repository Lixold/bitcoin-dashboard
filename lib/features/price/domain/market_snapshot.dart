/// Age at which `market.json` stops carrying the live dot and says how
/// old it is.
///
/// `cron-history` writes every fifteen minutes, so 45 minutes is three
/// missed runs — long enough that a punctual producer never trips it,
/// short enough that a silently dead worker shows up within the hour.
///
/// **Stale is a state of the data, not a failure of the fetch.** Values
/// past this age stay on screen with an age hint; they are never replaced
/// by the error state.
///
/// Deliberately not shared with `stalePayloadAge`, which is 26 hours
/// because its producer runs daily. The threshold follows each payload's
/// producer cadence; two different numbers are correct. #52 replaces both
/// by deriving the threshold from the cadence itself.
const Duration marketStaleAge = Duration(minutes: 45);

/// Age at which the age hint gains the alert glyph.
///
/// A payload three quarters of an hour old is a hiccup. One a full day
/// old means nobody is writing, and the reader should see that at a
/// glance rather than by reading the timestamp.
const Duration marketLongStaleAge = Duration(hours: 24);

/// How current the payload is, as three named states.
///
/// The screen asks for this at build time rather than being told once at
/// fetch time, so a screen left open crosses the threshold when the clock
/// does.
enum PayloadFreshness { fresh, stale, longStale }

/// The part of `market.json` this slice reads.
///
/// **Every figure is nullable, and that is the contract, not caution.** A
/// field the producer did not write is a state — the statement that rests
/// on it falls away and the others stay whole. Only a payload that cannot
/// be read at all is an error, and here that means exactly one thing: no
/// `fetchedAt`. Without it nothing on screen can say how old it is, and a
/// figure whose age is unknown is worse than an absent one.
///
/// `volume24h`, `atl`, `atlDate` and the supply figures are in the
/// payload and are not parsed here — see the issue for why each stays
/// out.
class MarketSnapshot {
  const MarketSnapshot({
    required this.fetchedAt,
    this.currency,
    this.ath,
    this.athDate,
    this.btcDominance,
    this.marketCap,
  });

  /// Reads the document published at `data/market.json`.
  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    final fetchedAt = json['fetchedAt'] as String?;
    if (fetchedAt == null) {
      throw const FormatException('market.json is missing fetchedAt');
    }

    return MarketSnapshot(
      // The producer writes an explicit `+00:00` offset, so the parse
      // already yields UTC. `toUtc()` makes that independent of the
      // serialisation: an offset the producer changes must not silently
      // shift every age this screen reports.
      fetchedAt: DateTime.parse(fetchedAt).toUtc(),
      currency: json['currency'] as String?,
      ath: _number(json['ath']),
      athDate: _date(json['athDate']),
      btcDominance: _number(json['btcDominance']),
      marketCap: _number(json['marketCap']),
    );
  }

  /// `fetchedAt` — when the producer read its source, not when the app
  /// fetched the file.
  final DateTime fetchedAt;

  /// The currency every amount in this payload is quoted in, as the
  /// payload itself declares it — `usd` today.
  ///
  /// Read from the document rather than assumed, because the amounts are
  /// rendered with a symbol and a symbol is a claim. Without it the
  /// amounts cannot be labelled and are left out; the percentages do not
  /// depend on it and stay.
  final String? currency;

  /// The highest price ever recorded, in [currency].
  ///
  /// The contract writes this as an integer and today it is one. Parsed
  /// as a number so that a producer which starts emitting a fraction
  /// changes a figure rather than the state of the screen.
  final double? ath;

  /// When [ath] was set.
  final DateTime? athDate;

  /// Bitcoin's share of the total crypto market capitalisation, in
  /// percent.
  final double? btcDominance;

  /// Total crypto market capitalisation, in [currency].
  final double? marketCap;

  /// How current this payload is at [now].
  ///
  /// Both bounds are strict: a payload of exactly 45 minutes is not yet
  /// stale, and one of exactly 24 hours has not yet earned the glyph.
  PayloadFreshness freshnessAt(DateTime now) {
    final age = ageAt(now);
    if (age > marketLongStaleAge) return PayloadFreshness.longStale;
    if (age > marketStaleAge) return PayloadFreshness.stale;
    return PayloadFreshness.fresh;
  }

  /// How long ago the producer wrote this payload, at [now].
  Duration ageAt(DateTime now) => now.toUtc().difference(fetchedAt);

  static double? _number(Object? value) => (value as num?)?.toDouble();

  static DateTime? _date(Object? value) {
    final raw = value as String?;
    if (raw == null) return null;
    // A date the producer cannot format is a missing date, not a broken
    // payload: the statement it belongs to falls away, the rest stays.
    return DateTime.tryParse(raw)?.toUtc();
  }
}
