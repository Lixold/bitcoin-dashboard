import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/price_tick.dart';
import 'binance_api.dart';

/// Polling stream of the live BTC/USDT price with exponential backoff.
///
/// Normal cadence is one fetch every [_baseInterval] (60 s). After a fetch
/// fails the next attempt waits twice as long, doubling on each consecutive
/// failure up to [_maxInterval] (5 min). A single successful fetch resets
/// the backoff to the base interval.
///
/// Rationale: a sustained network outage on `Timer.periodic(60s)` would
/// fire 60 doomed requests per hour, draining battery on mobile and
/// adding noise to upstream logs. With backoff, a four-hour outage hits
/// Binance roughly 50× instead of 240×, and the first reachability
/// returns the cadence to normal on the very next tick.
///
/// The stream stays open while at least one widget is listening;
/// `ref.onDispose` cancels the pending timer and closes the controller
/// when no one watches anymore.

const Duration _baseInterval = Duration(seconds: 60);
const Duration _maxInterval = Duration(minutes: 5);

/// Compute the wait until the next tick given the current failure streak.
///
/// `failureStreak == 0` → base interval. `failureStreak == n > 0` →
/// `base × 2^(n-1)`, capped at [_maxInterval]. Visible by tests via the
/// `@visibleForTesting` annotation in a follow-up; kept internal here.
Duration _nextInterval(int failureStreak) {
  if (failureStreak <= 0) return _baseInterval;
  // 1 << (n-1) for n in [1, 30] is safe; we cap long before that.
  final multiplier = 1 << math.min(failureStreak - 1, 30);
  final candidate = _baseInterval * multiplier;
  return candidate > _maxInterval ? _maxInterval : candidate;
}

final priceLiveProvider = StreamProvider.autoDispose<PriceTick>((ref) {
  final api = ref.watch(binanceApiProvider);
  final controller = StreamController<PriceTick>();

  Timer? timer;
  var failureStreak = 0;

  Future<void> tick() async {
    try {
      final priceTick = await api.tickerPrice();
      if (controller.isClosed) return;
      controller.add(priceTick);
      failureStreak = 0;
    } catch (e, st) {
      if (controller.isClosed) return;
      controller.addError(e, st);
      failureStreak++;
    }
    if (controller.isClosed) return;
    // Schedule the next tick relative to *completion* of this one, not
    // a fixed wall-clock cadence. This avoids stacking overlapping
    // requests when an upstream call takes longer than the interval.
    timer = Timer(_nextInterval(failureStreak), tick);
  }

  // Fire-and-forget initial fetch.
  unawaited(tick());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
