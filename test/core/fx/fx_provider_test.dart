import 'package:bitcoin_dashboard/core/fx/fx_cache.dart';
import 'package:bitcoin_dashboard/core/fx/fx_provider.dart';
import 'package:bitcoin_dashboard/core/fx/fx_rates.dart';
import 'package:bitcoin_dashboard/core/http/cdn_client.dart';
import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The moment every age in this file is measured from.
///
/// The provider compares a cached copy's age against the clock, so the
/// test fixes the clock rather than building its inputs relative to the
/// real one.
final DateTime _now = DateTime.utc(2026, 9, 10, 20);

Map<String, dynamic> _payload(String fetchedAt, {double eur = 0.86088154}) =>
    <String, dynamic>{
      '_meta': <String, dynamic>{
        'fetchedAt': fetchedAt,
        'date': '2026-09-10',
        'source': 'ECB',
        'currencies': const <String>['EUR', 'USD'],
      },
      'USD': <String, dynamic>{'EUR': eur, 'USD': 1},
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
class _FakeCache implements FxCache {
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

Future<FxRates> _read(ProviderContainer container) {
  // The provider is `autoDispose`. Reading only its future leaves it
  // without a listener, so it is disposed while still loading and the
  // future never completes. Hold a subscription for the container's life.
  container.listen(fxRatesProvider, (_, _) {}, onError: (_, _) {});
  return container.read(fxRatesProvider.future);
}

ProviderContainer _container({
  required _FakeCdn cdn,
  required _FakeCache cache,
}) {
  final container = ProviderContainer(
    overrides: [
      cdnClientProvider.overrideWithValue(cdn),
      fxCacheProvider.overrideWithValue(cache),
      clockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('fetches from the CDN when nothing is cached, and stores it', () async {
    final cdn = _FakeCdn(payload: _payload('2026-09-10T16:15:46+00:00'));
    final cache = _FakeCache();

    final rates = await _read(_container(cdn: cdn, cache: cache));

    expect(rates.rate(from: 'usd', to: 'EUR'), 0.86088154);
    expect(cdn.calls, 1);
    expect(cdn.lastPath, fxRatesPath);
    expect(cache.writes, 1);
  });

  test('serves a cached copy inside the TTL without a request', () async {
    final cdn = _FakeCdn(payload: _payload('2026-09-10T16:15:46+00:00'));
    final cache = _FakeCache(
      CachedPayload(
        // Well inside the three-hour TTL.
        cachedAt: _now.subtract(const Duration(hours: 1)),
        payload: _payload('2026-09-09T16:15:31+00:00', eur: 0.855),
      ),
    );

    final rates = await _read(_container(cdn: cdn, cache: cache));

    expect(cdn.calls, 0, reason: 'a fresh cache must not hit the network');
    expect(rates.rate(from: 'usd', to: 'EUR'), 0.855);
  });

  test('refetches once the cached copy is older than the TTL', () async {
    // The ECB publishes at 16:15 UTC. A copy taken shortly before that
    // would carry yesterday's rate all of today if the TTL followed the
    // producer's daily cadence; three hours is what bounds the miss.
    final cdn = _FakeCdn(payload: _payload('2026-09-10T16:15:46+00:00'));
    final cache = _FakeCache(
      CachedPayload(
        cachedAt: _now.subtract(const Duration(hours: 3, minutes: 1)),
        payload: _payload('2026-09-09T16:15:31+00:00', eur: 0.855),
      ),
    );

    final rates = await _read(_container(cdn: cdn, cache: cache));

    expect(cdn.calls, 1);
    expect(rates.fetchedAt, DateTime.utc(2026, 9, 10, 16, 15, 46));
  });

  test(
    'falls back to the cached copy at any age when the fetch fails',
    () async {
      // This is what makes an old rate a state of the screen rather than an
      // outage: the reader keeps the last published rate plus an age hint.
      final cdn = _FakeCdn(failure: Exception('CDN unreachable'));
      final cache = _FakeCache(
        CachedPayload(
          cachedAt: _now.subtract(const Duration(days: 6)),
          payload: _payload('2026-09-04T16:15:12+00:00', eur: 0.849),
        ),
      );

      final rates = await _read(_container(cdn: cdn, cache: cache));

      expect(cdn.calls, 1);
      expect(rates.rate(from: 'usd', to: 'EUR'), 0.849);
      expect(
        rates.isStaleAt(_now),
        isTrue,
        reason: 'six days old — the screen says so and keeps the amounts',
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
    final cdn = _FakeCdn(
      payload: const <String, dynamic>{
        'USD': <String, dynamic>{'EUR': 0.86},
      },
    );
    final cache = _FakeCache();

    await expectLater(
      _read(_container(cdn: cdn, cache: cache)),
      throwsA(isA<FormatException>()),
    );
    expect(
      cache.writes,
      0,
      reason: 'caching an unreadable document would serve it back for 3 h',
    );
  });

  test('a document quoting nothing is data, not an error', () async {
    // The screen's remedy is the source-currency fallback, which it can
    // only reach if the provider hands it a document to look at.
    final cdn = _FakeCdn(
      payload: const <String, dynamic>{
        '_meta': <String, dynamic>{'fetchedAt': '2026-09-10T16:15:46+00:00'},
      },
    );
    final cache = _FakeCache();

    final rates = await _read(_container(cdn: cdn, cache: cache));

    expect(rates.isEmpty, isTrue);
    expect(cache.writes, 1, reason: 'it parsed — it is worth keeping');
  });
}
