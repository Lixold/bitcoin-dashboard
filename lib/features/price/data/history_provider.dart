import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/cdn_client.dart';
import '../../../core/time/clock.dart';
import '../domain/price_history.dart';
import '../domain/price_range.dart';
import 'history_cache.dart';

/// Which range the trend statement is currently talking about.
///
/// **It outlives a rebuild and a section change, and not a restart.**
/// Local widget state would reset every time the reader looks at the
/// network section and comes back, which is not what picking a range
/// means. Persisting it in the settings box would make it a preference
/// nobody asked for, in the store CLAUDE.md §1 keeps to what the app
/// actually needs. A session is the span over which the choice is still
/// the reader's; after a restart there is no expectation to honour.
///
/// The default is the month: long enough to have a shape, short enough
/// that the first thing a reader sees is about now rather than about last
/// autumn.
///
/// A [Notifier] rather than a `StateProvider`: Riverpod 3 keeps the
/// latter in its `legacy.dart` barrel, so reaching for it would mean a
/// legacy import in new code. This is the same thing said in the current
/// API — one value, set by one method.
class SelectedPriceRange extends Notifier<PriceRange> {
  @override
  PriceRange build() => PriceRange.oneMonth;

  void select(PriceRange range) => state = range;
}

final selectedPriceRangeProvider =
    NotifierProvider<SelectedPriceRange, PriceRange>(SelectedPriceRange.new);

/// The published price history for one range, behind the trend statement.
///
/// Reads `history-{range}.json` through [CdnClient], cached on device by
/// [HistoryCache]. Three outcomes, in order of preference:
///
///  1. a cached copy younger than [HistoryCache.ttl] — no request;
///  2. a fresh fetch, which replaces the cached copy;
///  3. the cached copy at any age, when the fetch fails.
///
/// Only when there is no cached copy at all does a failed fetch surface
/// as an error. That ordering is what makes staleness a state of the
/// screen rather than an outage: the reader keeps the last published
/// series and is told how old it is.
///
/// **One family, five documents, five cache entries.** The range is the
/// parameter rather than five providers, because the five differ in
/// exactly one thing — which file they read — and because a family is
/// what lets the screen keep the range it is showing in one place.
/// Riverpod disposes the ones nobody is watching; the cache is what
/// stops a switch back from costing a request.
///
/// The provider does not decide whether the series is stale, whether it
/// is long enough to carry a direction, or what that direction is. It
/// answers one question — what did the producer last publish for this
/// range — and hands the screen a series that may be short or empty. A
/// short series is a state the screen renders; only an unreadable payload
/// is an error.
///
/// Retry policy: none.
///
/// Riverpod 3 retries a failed provider by default — ten attempts with
/// exponential backoff, which would hold a *range switch* in its loading
/// state for roughly 38 seconds and spend eleven requests getting there.
/// On a control the reader taps, that is the difference between a screen
/// that answers and one that appears to have hung. The resilience this
/// data needs is the cached copy below, not a burst of retries.
Duration? _neverRetry(int retryCount, Object error) => null;

final historyProvider = FutureProvider.autoDispose
    .family<PriceHistory, PriceRange>((ref, range) async {
      final cdn = ref.watch(cdnClientProvider);
      final cache = ref.watch(historyCacheProvider);
      final now = ref.watch(clockProvider)().toUtc();

      final cached = await cache.read(range);
      if (cached != null &&
          now.difference(cached.cachedAt) < HistoryCache.ttl) {
        return PriceHistory.fromJson(cached.payload);
      }

      try {
        final payload = await cdn.fetchJson(range.path);
        final history = PriceHistory.fromJson(payload);
        // Cache only what parsed: storing a document the app cannot read
        // would serve the same failure back for the next quarter of an
        // hour.
        await cache.write(range, payload, now);
        return history;
      } on Object {
        if (cached != null) return PriceHistory.fromJson(cached.payload);
        rethrow;
      }
    }, retry: _neverRetry);
