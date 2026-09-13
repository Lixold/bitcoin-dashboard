import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/cdn_cache.dart';

export '../../../core/http/cdn_cache.dart' show CachedPayload;

/// On-device copy of the last Fear & Greed payload the app fetched.
///
/// Storage, envelope and failure behaviour are [CdnCache]'s; what stays
/// here is the number belonging to *this* document.
///
/// **The storage is [CdnCache]'s, the source is not a CDN.** This is the
/// first cached document the app fetches straight from a public API, and
/// the class it reuses is named after where the other four come from. The
/// mechanism fits exactly — one JSON document, one TTL, offline-first,
/// one Hive entry per key — so the choice was between renaming the class
/// in this PR and reusing it under a name that no longer covers all its
/// callers. The rename touches six files across four cache wrappers,
/// which is a second topic in a PR that already carries a slice and the
/// #52 mechanism, so it is its own issue and the name is left alone here.
class SentimentCache {
  SentimentCache();

  /// Hive box for cached payloads — [CdnCache.boxName], restated so a
  /// caller that knows this cache does not have to know what it is built
  /// on.
  static const String boxName = CdnCache.boxName;

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

  static const CdnCache _cache = CdnCache(key: 'sentiment', ttl: ttl);

  Future<CachedPayload?> read() => _cache.read();

  Future<void> write(Map<String, dynamic> payload, DateTime now) =>
      _cache.write(payload, now);
}

final sentimentCacheProvider = Provider<SentimentCache>((ref) {
  return SentimentCache();
});
