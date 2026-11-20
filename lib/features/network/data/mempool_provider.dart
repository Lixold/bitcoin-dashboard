import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mempool_snapshot.dart';
import 'mempool_api.dart';

/// How often the reading is replaced while the statement is on screen —
/// the 60 s ADR-0002 gives mempool and fees.
const Duration mempoolRefreshInterval = Duration(seconds: 60);

/// Retry policy: none. The cadence is [mempoolRefreshInterval] and nothing
/// else.
///
/// Riverpod 3's default would retry a failed fetch ten times with backoff
/// and hold the statement in its loading state for about 38 seconds
/// meanwhile. A failed reading here is answered by the error state and by
/// the next scheduled fetch a minute later, which already is a retry at
/// the cadence this data has; the reader can also ask for one at once.
/// ADR-0004 makes stating this the rule.
Duration? _neverRetry(int retryCount, Object error) => null;

/// The current mempool reading, replaced every [mempoolRefreshInterval].
///
/// **No cache, and no stale value — decision 2 of #112.** A fee estimate
/// that is minutes old is a wrong estimate, so this provider has no
/// on-device copy to fall back on. When a fetch fails the provider is in
/// error even if an earlier reading exists, and the screen renders the
/// error rather than the earlier reading. While a scheduled refresh is in
/// flight the reading it replaces is still at most one interval old,
/// which is the cadence, not staleness.
///
/// The timer is armed before the fetch, so a failed fetch is followed by
/// the next one on the same cadence and the statement recovers by itself
/// once mempool.space answers again. `autoDispose` cancels it when nothing
/// watches the statement.
final mempoolProvider = FutureProvider.autoDispose<MempoolSnapshot>((ref) {
  final api = ref.watch(mempoolApiProvider);
  final timer = Timer(mempoolRefreshInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return api.fetch();
}, retry: _neverRetry);
