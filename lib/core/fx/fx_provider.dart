import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../http/cdn_client.dart';
import '../time/clock.dart';
import 'fx_cache.dart';
import 'fx_rates.dart';

/// Path of the document under [CdnClient.host].
const String fxRatesPath = 'data/fx-rates.json';

/// The published conversion rates behind every amount the app renders.
///
/// Reads `fx-rates.json` through [CdnClient], cached on device by
/// [FxCache]. Three outcomes, in order of preference:
///
///  1. a cached copy younger than [FxCache.ttl] — no request;
///  2. a fresh fetch, which replaces the cached copy;
///  3. the cached copy at any age, when the fetch fails.
///
/// Only when there is no cached copy at all does a failed fetch surface as
/// an error. That ordering is what makes an old rate a state of the screen
/// rather than an outage: the reader keeps the last published rate and is
/// told how old it is.
///
/// **It sits in `core/` rather than under `price/`, unlike the two caches
/// it is modelled on.** The currency is an app-wide setting and the rate
/// is what makes it true, so two features already read this document: the
/// price screen converts its amounts with it, and the settings sheet
/// offers exactly the currencies it quotes. CLAUDE.md §3 puts code used by
/// more than one feature here.
///
/// The provider does not decide whether the rate is old, whether a
/// currency can be reached, or what the screen shows when it cannot. It
/// answers one question — what did the producer last publish — and hands
/// the app a document that may quote nothing at all. An empty document is
/// a state `MoneyDisplay` renders; only an unreadable payload is an error.
///
/// Retry policy: none.
///
/// Riverpod 3 retries a failed provider by default — ten attempts with
/// exponential backoff, which holds every amount on the screen in its
/// pending state for roughly 38 seconds and spends eleven requests on a
/// document the ECB rewrites once a day. The resilience this data needs is
/// the cached copy below and the source-currency fallback above it, not a
/// burst of retries.
Duration? _neverRetry(int retryCount, Object error) => null;

final fxRatesProvider = FutureProvider.autoDispose<FxRates>((ref) async {
  final cdn = ref.watch(cdnClientProvider);
  final cache = ref.watch(fxCacheProvider);
  final now = ref.watch(clockProvider)().toUtc();

  final cached = await cache.read();
  if (cached != null && now.difference(cached.cachedAt) < FxCache.ttl) {
    return FxRates.fromJson(cached.payload);
  }

  try {
    final payload = await cdn.fetchJson(fxRatesPath);
    final rates = FxRates.fromJson(payload);
    // Cache only what parsed: storing a document the app cannot read
    // would serve the same failure back for the next three hours.
    await cache.write(payload, now);
    return rates;
  } on Object {
    if (cached != null) return FxRates.fromJson(cached.payload);
    rethrow;
  }
}, retry: _neverRetry);
