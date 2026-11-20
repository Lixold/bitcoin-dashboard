import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/payload_cache.dart';

export '../../../core/http/payload_cache.dart' show CachedPayload;

/// On-device copy of the last `market.json` the app fetched.
///
/// Storage, envelope and failure behaviour are [PayloadCache]'s; what stays
/// here are the two numbers belonging to *this* document.
class MarketCache {
  MarketCache();

  /// Hive box for cached payloads — [PayloadCache.boxName], restated so
  /// a caller that knows this cache does not have to know what it is
  /// built on.
  static const String boxName = PayloadCache.boxName;

  /// How long a stored copy is reused before the CDN is asked again.
  ///
  /// `cron-history` writes every fifteen minutes. Asking more often than
  /// the producer writes spends requests to receive the identical
  /// document; asking less often would show a payload as current while a
  /// newer one sits on the CDN. It is not the staleness threshold —
  /// that one lives with the snapshot and is three times longer.
  static const Duration ttl = Duration(minutes: 15);

  static const PayloadCache _cache = PayloadCache(key: 'market', ttl: ttl);

  Future<CachedPayload?> read() => _cache.read();

  Future<void> write(Map<String, dynamic> payload, DateTime now) =>
      _cache.write(payload, now);
}

final marketCacheProvider = Provider<MarketCache>((ref) {
  return MarketCache();
});
