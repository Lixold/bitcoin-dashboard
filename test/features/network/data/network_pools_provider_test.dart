import 'package:bitcoin_dashboard/core/http/cdn_client.dart';
import 'package:bitcoin_dashboard/features/network/data/network_health_cache.dart';
import 'package:bitcoin_dashboard/features/network/data/network_pools_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _payload(String fetchedAt) => <String, dynamic>{
  '_meta': {'fetchedAt': fetchedAt},
  'miningPools': [
    {'name': 'Foundry USA', 'hashratePercent': 22.37},
    {'name': 'AntPool', 'hashratePercent': 18.42},
    {'name': 'F2Pool', 'hashratePercent': 17.11},
  ],
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
class _FakeCache implements NetworkHealthCache {
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

Future<NetworkHealthSnapshot> _read(ProviderContainer container) {
  // The provider is `autoDispose`. Reading only its future leaves it
  // without a listener, so it is disposed while still loading and the
  // future never completes. Hold a subscription for the container's life.
  container.listen(networkPoolsProvider, (_, _) {}, onError: (_, _) {});
  return container.read(networkPoolsProvider.future);
}

ProviderContainer _container({
  required _FakeCdn cdn,
  required _FakeCache cache,
}) {
  final container = ProviderContainer(
    overrides: [
      cdnClientProvider.overrideWithValue(cdn),
      networkHealthCacheProvider.overrideWithValue(cache),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'fetches from the CDN when nothing is cached, and stores the result',
    () async {
      final cdn = _FakeCdn(payload: _payload('2026-09-06T01:00:32+00:00'));
      final cache = _FakeCache();

      final snapshot = await _read(_container(cdn: cdn, cache: cache));

      expect(snapshot.pools.length, 3);
      expect(cdn.calls, 1);
      expect(cdn.lastPath, networkHealthPath);
      expect(cache.writes, 1);
    },
  );

  test('serves a cached copy inside the TTL without a request', () async {
    final cdn = _FakeCdn(payload: _payload('2026-09-06T01:00:32+00:00'));
    final cache = _FakeCache(
      CachedPayload(
        // Well inside the 60-minute TTL.
        cachedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        payload: _payload('2026-09-05T01:00:32+00:00'),
      ),
    );

    final snapshot = await _read(_container(cdn: cdn, cache: cache));

    expect(cdn.calls, 0, reason: 'a fresh cache must not hit the network');
    expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 5, 1, 0, 32));
  });

  test('refetches once the cached copy is older than the TTL', () async {
    final cdn = _FakeCdn(payload: _payload('2026-09-06T01:00:32+00:00'));
    final cache = _FakeCache(
      CachedPayload(
        cachedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 61)),
        payload: _payload('2026-09-05T01:00:32+00:00'),
      ),
    );

    final snapshot = await _read(_container(cdn: cdn, cache: cache));

    expect(cdn.calls, 1);
    expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 6, 1, 0, 32));
  });

  test(
    'falls back to the cached copy at any age when the fetch fails',
    () async {
      // This is what makes staleness a state of the screen rather than an
      // outage: the reader keeps the last known shares plus an age hint.
      final cdn = _FakeCdn(failure: Exception('CDN unreachable'));
      final cache = _FakeCache(
        CachedPayload(
          cachedAt: DateTime.now().toUtc().subtract(const Duration(days: 4)),
          payload: _payload('2026-09-02T01:00:32+00:00'),
        ),
      );

      final snapshot = await _read(_container(cdn: cdn, cache: cache));

      expect(cdn.calls, 1);
      expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 2, 1, 0, 32));
      expect(
        snapshot.isStaleAt(DateTime.utc(2026, 9, 6)),
        isTrue,
        reason: 'four days old — the screen shows this with an age hint',
      );
    },
  );

  test(
    'surfaces the error only when there is nothing cached to fall back on',
    () async {
      final cdn = _FakeCdn(failure: Exception('CDN unreachable'));

      await expectLater(
        _read(_container(cdn: cdn, cache: _FakeCache())),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('does not cache a payload it could not parse', () async {
    final cdn = _FakeCdn(payload: const {'miningPools': <dynamic>[]});
    final cache = _FakeCache();

    await expectLater(
      _read(_container(cdn: cdn, cache: cache)),
      throwsA(isA<FormatException>()),
    );
    expect(
      cache.writes,
      0,
      reason: 'caching an unreadable document would serve it back for an hour',
    );
  });
}
