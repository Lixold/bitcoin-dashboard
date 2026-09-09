import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/cdn_cache.dart';

export '../../../core/http/cdn_cache.dart' show CachedPayload;

/// On-device copy of the last `network-health.json` the app fetched.
///
/// Storage, envelope and failure behaviour are [CdnCache]'s. What stays
/// here are the two numbers that belong to *this* document, so a caller
/// asks for "the network-health cache" rather than restating the key and
/// the TTL at every call site.
///
/// It wraps [CdnCache] rather than extending it. A subclass would put
/// `key` and `ttl` into this class's interface, and every test double
/// standing in for this cache would then have to implement two fields it
/// has no use for.
///
/// The constructor stays non-`const`: making it `const` would turn every
/// existing `NetworkHealthCache()` into a lint, and this extraction is
/// supposed to leave its callers alone.
class NetworkHealthCache {
  NetworkHealthCache();

  /// Hive box for cached CDN documents — [CdnCache.boxName], restated so
  /// a caller that knows this cache does not have to know what it is
  /// built on.
  static const String boxName = CdnCache.boxName;

  /// How long a stored copy is reused before the CDN is asked again.
  ///
  /// The producer writes once a day and the CDN answers with
  /// `max-age=86400`; a shorter cycle would spend battery to receive the
  /// identical document. It is not the staleness threshold — that one
  /// lives with the snapshot and is six times longer.
  static const Duration ttl = Duration(minutes: 60);

  static const CdnCache _cache = CdnCache(key: 'network-health', ttl: ttl);

  Future<CachedPayload?> read() => _cache.read();

  Future<void> write(Map<String, dynamic> payload, DateTime now) =>
      _cache.write(payload, now);
}

final networkHealthCacheProvider = Provider<NetworkHealthCache>((ref) {
  return NetworkHealthCache();
});
