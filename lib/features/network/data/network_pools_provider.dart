import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/cdn_client.dart';
import '../domain/network_health_snapshot.dart';
import 'network_health_cache.dart';

/// Path of the document under [CdnClient.host].
const String networkHealthPath = 'data/network-health.json';

/// The mining-pool shares behind the concentration statement.
///
/// Reads `network-health.json` through [CdnClient], cached on device by
/// [NetworkHealthCache]. Three outcomes, in order of preference:
///
///  1. a cached copy younger than [NetworkHealthCache.ttl] — no request;
///  2. a fresh fetch, which replaces the cached copy;
///  3. the cached copy at any age, when the fetch fails.
///
/// Only when there is no cached copy at all does a failed fetch surface
/// as an error. That ordering is what makes staleness a state of the
/// screen rather than an outage: the reader keeps the last known shares
/// and is told how old they are.
///
/// The provider does not decide whether the payload is stale — the screen
/// asks [NetworkHealthSnapshot.isStaleAt] at build time, so a screen left
/// open crosses the threshold when the clock does, not when the fetch
/// happened.
/// Retry policy: none.
///
/// Riverpod 3 retries a failed provider by default — ten attempts with
/// exponential backoff, which holds this screen in its loading state for
/// roughly 38 seconds and spends eleven requests on a document that
/// changes once a day. Both are wrong here. The resilience this data
/// needs is the cached copy below, not a burst of retries: if the CDN
/// cannot be reached and nothing is cached, the honest answer is the
/// error state and a retry the reader chooses.
///
/// Returning `null` from the callback declines every attempt. It follows
/// the same rule as `price_live_provider.dart`: this app states its retry
/// cadence rather than inheriting one.
Duration? _neverRetry(int retryCount, Object error) => null;

final networkPoolsProvider = FutureProvider.autoDispose<NetworkHealthSnapshot>((
  ref,
) async {
  final cdn = ref.watch(cdnClientProvider);
  final cache = ref.watch(networkHealthCacheProvider);
  final now = DateTime.now().toUtc();

  final cached = await cache.read();
  if (cached != null &&
      now.difference(cached.cachedAt) < NetworkHealthCache.ttl) {
    return NetworkHealthSnapshot.fromJson(cached.payload);
  }

  try {
    final payload = await cdn.fetchJson(networkHealthPath);
    final snapshot = NetworkHealthSnapshot.fromJson(payload);
    // Cache only what parsed: storing a document the app cannot read
    // would serve the same failure back for the next hour.
    await cache.write(payload, now);
    return snapshot;
  } on Object {
    if (cached != null) return NetworkHealthSnapshot.fromJson(cached.payload);
    rethrow;
  }
}, retry: _neverRetry);
