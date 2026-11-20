import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/payload_cache.dart';

export '../../../core/http/payload_cache.dart' show CachedPayload;

/// On-device copy of the last Fear & Greed payload the app fetched.
///
/// Storage, envelope and failure behaviour are [PayloadCache]'s; what stays
/// here is the number belonging to *this* document.
///
/// This is the one cached document the app fetches straight from a public
/// API rather than from the CDN; the storage is the same either way.
class SentimentCache {
  SentimentCache();

  /// Hive box for cached payloads — [PayloadCache.boxName], restated so a
  /// caller that knows this cache does not have to know what it is built
  /// on.
  static const String boxName = PayloadCache.boxName;

  /// How long a stored copy is reused before the source is asked again.
  ///
  /// One hour, the cadence ADR-0002 records for this endpoint. The
  /// payload names its own remaining lifetime in `time_until_update`, and
  /// that field is deliberately not used: it is present on the first
  /// element only, and on a morning read it would tell the app to stay
  /// away for most of a day.
  ///
  /// It is not a staleness threshold. This document has none — the value
  /// carries its own calendar day, and that date is the age display.
  static const Duration ttl = Duration(hours: 1);

  static const PayloadCache _cache = PayloadCache(key: 'sentiment', ttl: ttl);

  Future<CachedPayload?> read() => _cache.read();

  Future<void> write(Map<String, dynamic> payload, DateTime now) =>
      _cache.write(payload, now);
}

final sentimentCacheProvider = Provider<SentimentCache>((ref) {
  return SentimentCache();
});
