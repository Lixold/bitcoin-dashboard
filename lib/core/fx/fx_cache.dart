import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../http/cdn_cache.dart';

export '../http/cdn_cache.dart' show CachedPayload;

/// On-device copy of the last `fx-rates.json` the app fetched.
///
/// Storage, envelope and failure behaviour are [CdnCache]'s; what stays
/// here are the two numbers belonging to *this* document.
class FxCache {
  const FxCache();

  /// Hive box for cached CDN documents — [CdnCache.boxName], restated so
  /// a caller that knows this cache does not have to know what it is
  /// built on.
  static const String boxName = CdnCache.boxName;

  /// How long a stored copy is reused before the CDN is asked again.
  ///
  /// **Three hours, not the producer's twenty-four.** Every other cache in
  /// the app sets its TTL to the producer's period, because for a document
  /// rewritten every fifteen minutes the two coincide: ask at the cadence
  /// it is written at and the copy is never more than one run behind.
  /// `cron-fx-rates` runs once a day, at 16:15 UTC, and there the two come
  /// apart — a copy taken at 16:00 would be held until 16:00 tomorrow and
  /// would miss the rate published fifteen minutes after it was stored, by
  /// almost a full day.
  ///
  /// Three hours bounds that miss to part of an afternoon at the cost of
  /// at most eight requests a day for an 18 kB document, and needs no
  /// clock arithmetic against the publication time to do it. It is not the
  /// staleness threshold: that one asks whether the *ECB* is still current
  /// and lives with the rate as `fxStaleAge`, where it is measured in days.
  static const Duration ttl = Duration(hours: 3);

  static const CdnCache _cache = CdnCache(key: 'fx-rates', ttl: ttl);

  Future<CachedPayload?> read() => _cache.read();

  Future<void> write(Map<String, dynamic> payload, DateTime now) =>
      _cache.write(payload, now);
}

final fxCacheProvider = Provider<FxCache>((ref) {
  return const FxCache();
});
