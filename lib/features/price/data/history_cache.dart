import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/cdn_cache.dart';
import '../domain/price_range.dart';

export '../../../core/http/cdn_cache.dart' show CachedPayload;

/// On-device copies of the five `history-{range}.json` documents.
///
/// Storage, envelope and failure behaviour are [CdnCache]'s. What stays
/// here are the numbers belonging to these documents — and, unlike
/// `MarketCache`, the fact that there are five of them.
///
/// **Five entries, one cache object, no new construct.** Each range gets
/// its own key in the box every cached CDN document already shares, so
/// switching to `1W` and back to `1M` costs no second request and no
/// second box to open and migrate. The five are told apart by
/// [PriceRange.cacheKey].
class HistoryCache {
  const HistoryCache();

  /// Hive box for cached CDN documents — [CdnCache.boxName], restated so
  /// a caller that knows this cache does not have to know what it is
  /// built on.
  static const String boxName = CdnCache.boxName;

  /// How long a stored copy is reused before the CDN is asked again.
  ///
  /// Fifteen minutes for every range, which is `market.json`'s number
  /// because it is the same producer on the same run: `cron-history`
  /// writes all five history documents and the market snapshot together.
  /// A longer TTL for the long ranges would look thrifty and would show
  /// `1Y` as current while a newer copy of it sat on the CDN — the
  /// document is rewritten every quarter of an hour whatever span it
  /// covers.
  ///
  /// It is not the staleness threshold. That one asks whether the
  /// producer is still current and lives with the payload.
  static const Duration ttl = Duration(minutes: 15);

  Future<CachedPayload?> read(PriceRange range) => _cacheFor(range).read();

  Future<void> write(
    PriceRange range,
    Map<String, dynamic> payload,
    DateTime now,
  ) => _cacheFor(range).write(payload, now);

  CdnCache _cacheFor(PriceRange range) =>
      CdnCache(key: range.cacheKey, ttl: ttl);
}

final historyCacheProvider = Provider<HistoryCache>((ref) {
  return const HistoryCache();
});
