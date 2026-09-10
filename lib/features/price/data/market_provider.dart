import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/cdn_client.dart';
import '../../../core/time/clock.dart';
import '../domain/market_snapshot.dart';
import 'market_cache.dart';

/// Path of the document under [CdnClient.host].
const String marketPath = 'data/market.json';

/// The published market snapshot behind the all-time-high and
/// market-share statements.
///
/// Reads `market.json` through [CdnClient], cached on device by
/// [MarketCache]. Three outcomes, in order of preference:
///
///  1. a cached copy younger than [MarketCache.ttl] — no request;
///  2. a fresh fetch, which replaces the cached copy;
///  3. the cached copy at any age, when the fetch fails.
///
/// Only when there is no cached copy at all does a failed fetch surface
/// as an error. That ordering is what makes staleness a state of the
/// screen rather than an outage: the reader keeps the last published
/// figures and is told how old they are.
///
/// The provider does not decide whether the payload is stale, and it does
/// not decide whether a statement can be formed. It answers one question
/// — what did the producer last publish — and hands the screen a snapshot
/// whose figures may individually be absent. A missing field is a state
/// the screen renders; only an unreadable payload is an error.
///
/// Retry policy: none.
///
/// Riverpod 3 retries a failed provider by default — ten attempts with
/// exponential backoff, which holds these statements in their loading
/// state for roughly 38 seconds and spends eleven requests on a document
/// that changes every fifteen minutes. The resilience this data needs is
/// the cached copy below, not a burst of retries: if the CDN cannot be
/// reached and nothing is cached, the honest answer is the error state
/// and a retry the reader chooses.
Duration? _neverRetry(int retryCount, Object error) => null;

final marketProvider = FutureProvider.autoDispose<MarketSnapshot>((ref) async {
  final cdn = ref.watch(cdnClientProvider);
  final cache = ref.watch(marketCacheProvider);
  final now = ref.watch(clockProvider)().toUtc();

  final cached = await cache.read();
  if (cached != null && now.difference(cached.cachedAt) < MarketCache.ttl) {
    return MarketSnapshot.fromJson(cached.payload);
  }

  try {
    final payload = await cdn.fetchJson(marketPath);
    final snapshot = MarketSnapshot.fromJson(payload);
    // Cache only what parsed: storing a document the app cannot read
    // would serve the same failure back for the next quarter of an hour.
    await cache.write(payload, now);
    return snapshot;
  } on Object {
    if (cached != null) return MarketSnapshot.fromJson(cached.payload);
    rethrow;
  }
}, retry: _neverRetry);
