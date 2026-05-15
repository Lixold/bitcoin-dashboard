// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the exponential-backoff schedule used by
// [priceLiveProvider]. Only the pure schedule function is covered here;
// the StreamController + Timer plumbing is integration-level concern
// and is exercised by the existing widget_test smoke run.

import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextInterval', () {
    test('returns the base 60s interval when no failures have occurred', () {
      expect(nextInterval(0), const Duration(seconds: 60));
    });

    test('returns the base interval for negative input (defensive contract)', () {
      // The provider always increments by 1 on failure so negative values
      // are not produced in normal code. Still, we contract for safety.
      expect(nextInterval(-1), const Duration(seconds: 60));
    });

    test('doubles on each consecutive failure', () {
      // First failure waits one base interval; subsequent failures
      // wait base * 2^(n-1).
      expect(nextInterval(1), const Duration(seconds: 60));
      expect(nextInterval(2), const Duration(seconds: 120));
      expect(nextInterval(3), const Duration(seconds: 240));
    });

    test('caps at 5 minutes regardless of how long the outage lasts', () {
      // The audit calls out the 5-min ceiling explicitly — battery
      // budget on mobile is the constraint, not server pressure.
      expect(nextInterval(4), const Duration(minutes: 5));
      expect(nextInterval(10), const Duration(minutes: 5));
      expect(nextInterval(1000), const Duration(minutes: 5));
    });

    test('never produces a duration below the base interval', () {
      // Any failureStreak >= 1 must wait at least the base interval.
      for (var n = 0; n < 50; n++) {
        expect(
          nextInterval(n) >= const Duration(seconds: 60),
          isTrue,
          reason: 'failureStreak=$n produced ${nextInterval(n)}',
        );
      }
    });

    test('never produces a duration above the cap', () {
      // Symmetric upper-bound contract.
      for (var n = 0; n < 50; n++) {
        expect(
          nextInterval(n) <= const Duration(minutes: 5),
          isTrue,
          reason: 'failureStreak=$n produced ${nextInterval(n)}',
        );
      }
    });
  });
}
