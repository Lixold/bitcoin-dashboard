import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../domain/sentiment_index.dart';
import 'sentiment_api.dart';
import 'sentiment_cache.dart';

/// The Fear & Greed window behind the sentiment statement.
///
/// Reads the alternative.me endpoint through [SentimentApi], cached on
/// device by [SentimentCache]. Three outcomes, in order of preference:
///
///  1. a cached copy younger than [SentimentCache.ttl] — no request;
///  2. a fresh fetch, which replaces the cached copy;
///  3. the cached copy at any age, when the fetch fails.
///
/// Only when there is no cached copy at all does a failed fetch surface
/// as an error. A value published once a day is worth showing the day
/// after: it carries its own date, so the screen states which day it is
/// reading without needing an age hint on top.
///
/// Retry policy: none.
///
/// Riverpod 3 retries a failed provider by default — ten attempts with
/// exponential backoff, which holds this screen in its loading state for
/// roughly 38 seconds and spends eleven requests on a document that
/// changes once a day. The resilience this data needs is the cached copy
/// above, not a burst of retries: with nothing cached and the source
/// unreachable, the honest answer is the error state and a retry the
/// reader chooses. CLAUDE.md §2 asks every provider to state its cadence
/// or decline one; this one declines.
Duration? _neverRetry(int retryCount, Object error) => null;

final sentimentProvider = FutureProvider.autoDispose<SentimentIndex>((
  ref,
) async {
  final api = ref.watch(sentimentApiProvider);
  final cache = ref.watch(sentimentCacheProvider);
  final now = ref.watch(clockProvider)().toUtc();

  final cached = await cache.read();
  if (cached != null && now.difference(cached.cachedAt) < SentimentCache.ttl) {
    return SentimentIndex.fromJson(cached.payload);
  }

  try {
    final payload = await api.fetchIndex();
    final index = SentimentIndex.fromJson(payload);
    // Cache only what parsed. `metadata.error` arrives with HTTP 200, so
    // storing the body before reading it would keep a failure on the
    // device and serve it back for the next hour.
    await cache.write(payload, now);
    return index;
  } on Object {
    if (cached != null) return SentimentIndex.fromJson(cached.payload);
    rethrow;
  }
}, retry: _neverRetry);
