import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/difficulty_snapshot.dart';
import 'difficulty_api.dart';

/// How often the reading is replaced while the statement is on screen —
/// the 5 min ADR-0002 gives hashrate, difficulty and block info.
const Duration difficultyRefreshInterval = Duration(minutes: 5);

/// Retry policy: none. The cadence is [difficultyRefreshInterval] and
/// nothing else.
///
/// Riverpod 3's default would retry a failed fetch ten times with backoff
/// and hold the statement in its loading state for about 38 seconds
/// meanwhile. A failed reading is answered by the error state and by the
/// next scheduled fetch, and the reader can ask for one at once.
/// ADR-0004 makes stating this the rule.
Duration? _neverRetry(int retryCount, Object error) => null;

/// The current difficulty-adjustment reading, replaced every
/// [difficultyRefreshInterval].
///
/// **No cache, and no stale value — decision 4 of #46.** A countdown that
/// is minutes old is a wrong countdown, so this provider has no on-device
/// copy to fall back on. When a fetch fails the provider is in error even
/// if an earlier reading exists, and the screen renders the error.
///
/// The timer is armed before the fetch, so a failed fetch is followed by
/// the next one on the same cadence and the statement recovers by itself.
/// `autoDispose` cancels it when nothing watches the statement.
final difficultyProvider = FutureProvider.autoDispose<DifficultySnapshot>((
  ref,
) {
  final api = ref.watch(difficultyApiProvider);
  final timer = Timer(difficultyRefreshInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return api.fetch();
}, retry: _neverRetry);
