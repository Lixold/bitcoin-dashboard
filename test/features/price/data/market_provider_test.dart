import 'package:bitcoin_dashboard/core/http/cdn_client.dart';
import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:bitcoin_dashboard/features/price/data/market_cache.dart';
import 'package:bitcoin_dashboard/features/price/data/market_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The moment every age in this file is measured from.
///
/// The provider compares a cached copy's age against the clock, so the
/// test fixes the clock rather than building its inputs relative to the
/// real one.
final DateTime _now = DateTime.utc(2026, 9, 9, 19);

Map<String, dynamic> _payload(String fetchedAt) => <String, dynamic>{
  'fetchedAt': fetchedAt,
  'currency': 'usd',
  'ath': 126080,
  'athDate': '2025-10-06T10:57:42.000Z',
  'btcDominance': 58.38,
  'marketCap': 1578083556466,
};

/// Stands in for the CDN. Counts calls so "did not touch the network"
/// can be asserted rather than assumed.
class _FakeCdn implements CdnClient {
  _FakeCdn({this.payload, this.failure});

  final Map<String, dynamic>? payload;
  final Object? failure;
  int calls = 0;
  String? lastPath;

  @override
  Future<Map<String, dynamic>> fetchJson(String path) async {
    calls++;
    lastPath = path;
    if (failure != null) throw failure!;
    return payload!;
  }
}

/// In-memory stand-in for the Hive-backed cache.
class _FakeCache implements MarketCache {
  _FakeCache([this.stored]);

  CachedPayload? stored;
  int writes = 0;

  @override
  Future<CachedPayload?> read() async => stored;

  @override
  Future<void> write(Map<String, dynamic> payload, DateTime now) async {
    writes++;
    stored = CachedPayload(cachedAt: now, payload: payload);
  }
}

Future<MarketSnapshot> _read(ProviderContainer container) {
  // The provider is `autoDispose`. Reading only its future leaves it
  // without a listener, so it is disposed while still loading and the
  // future never completes. Hold a subscription for the container's life.
  container.listen(marketProvider, (_, _) {}, onError: (_, _) {});
  return container.read(marketProvider.future);
}

ProviderContainer _container({
  required _FakeCdn cdn,
  required _FakeCache cache,
}) {
  final container = ProviderContainer(
    overrides: [
      cdnClientProvider.overrideWithValue(cdn),
      marketCacheProvider.overrideWithValue(cache),
      clockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('fetches from the CDN when nothing is cached, and stores it', () async {
    final cdn = _FakeCdn(payload: _payload('2026-09-09T18:30:59+00:00'));
    final cache = _FakeCache();

    final snapshot = await _read(_container(cdn: cdn, cache: cache));

    expect(snapshot.ath, 126080);
    expect(cdn.calls, 1);
    expect(cdn.lastPath, marketPath);
    expect(cache.writes, 1);
  });

  test('serves a cached copy inside the TTL without a request', () async {
    final cdn = _FakeCdn(payload: _payload('2026-09-09T18:30:59+00:00'));
    final cache = _FakeCache(
      CachedPayload(
        // Well inside the 15-minute TTL.
        cachedAt: _now.subtract(const Duration(minutes: 5)),
        payload: _payload('2026-09-09T18:15:58+00:00'),
      ),
    );

    final snapshot = await _read(_container(cdn: cdn, cache: cache));

    expect(cdn.calls, 0, reason: 'a fresh cache must not hit the network');
    expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 9, 18, 15, 58));
  });

  test('refetches once the cached copy is older than the TTL', () async {
    // Sixteen minutes: the producer has written again by now.
    final cdn = _FakeCdn(payload: _payload('2026-09-09T18:45:59+00:00'));
    final cache = _FakeCache(
      CachedPayload(
        cachedAt: _now.subtract(const Duration(minutes: 16)),
        payload: _payload('2026-09-09T18:15:58+00:00'),
      ),
    );

    final snapshot = await _read(_container(cdn: cdn, cache: cache));

    expect(cdn.calls, 1);
    expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 9, 18, 45, 59));
  });

  test(
    'falls back to the cached copy at any age when the fetch fails',
    () async {
      // This is what makes staleness a state of the screen rather than an
      // outage: the reader keeps the last published figures plus an age
      // hint.
      final cdn = _FakeCdn(failure: Exception('CDN unreachable'));
      final cache = _FakeCache(
        CachedPayload(
          cachedAt: _now.subtract(const Duration(days: 4)),
          payload: _payload('2026-09-05T18:15:58+00:00'),
        ),
      );

      final snapshot = await _read(_container(cdn: cdn, cache: cache));

      expect(cdn.calls, 1);
      expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 5, 18, 15, 58));
      expect(
        snapshot.freshnessAt(_now),
        PayloadFreshness.longStale,
        reason: 'four days old — the screen shows this with the alert glyph',
      );
    },
  );

  test(
    'surfaces the error only when there is nothing to fall back on',
    () async {
      final cdn = _FakeCdn(failure: Exception('CDN unreachable'));

      await expectLater(
        _read(_container(cdn: cdn, cache: _FakeCache())),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('does not cache a payload it could not parse', () async {
    final cdn = _FakeCdn(payload: const {'ath': 126080});
    final cache = _FakeCache();

    await expectLater(
      _read(_container(cdn: cdn, cache: cache)),
      throwsA(isA<FormatException>()),
    );
    expect(
      cache.writes,
      0,
      reason: 'caching an unreadable document would serve it back for 15 min',
    );
  });

  test('a payload missing one figure is data, not an error', () async {
    // The partial-empty state: the provider hands the screen a snapshot
    // whose share is absent, and the screen drops that one statement.
    final cdn = _FakeCdn(
      payload: const {
        'fetchedAt': '2026-09-09T18:30:59+00:00',
        'currency': 'usd',
        'ath': 126080,
      },
    );
    final cache = _FakeCache();

    final snapshot = await _read(_container(cdn: cdn, cache: cache));

    expect(snapshot.ath, 126080);
    expect(snapshot.btcDominance, isNull);
    expect(cache.writes, 1, reason: 'it parsed — it is worth keeping');
  });
}
