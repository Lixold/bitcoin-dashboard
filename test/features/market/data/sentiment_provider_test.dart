import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:bitcoin_dashboard/features/market/data/sentiment_api.dart';
import 'package:bitcoin_dashboard/features/market/data/sentiment_cache.dart';
import 'package:bitcoin_dashboard/features/market/data/sentiment_provider.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The moment every age in this file is measured from.
///
/// The provider compares a cached copy's age against the clock, so the
/// test fixes the clock rather than building its inputs relative to the
/// real one.
final DateTime _now = DateTime.utc(2026, 9, 13, 12);

/// A payload in the source's own shape: newest first, every field a
/// string, `time_until_update` on the first element only.
Map<String, dynamic> _payload({int latest = 61}) => <String, dynamic>{
  'name': 'Fear and Greed Index',
  'data': <Map<String, dynamic>>[
    {
      'value': '$latest',
      'value_classification': 'Greed',
      'timestamp':
          '${DateTime.utc(2026, 9, 13).millisecondsSinceEpoch ~/ 1000}',
      'time_until_update': '19536',
    },
    {
      'value': '63',
      'value_classification': 'Greed',
      'timestamp':
          '${DateTime.utc(2026, 9, 12).millisecondsSinceEpoch ~/ 1000}',
    },
  ],
  'metadata': <String, dynamic>{'error': null},
};

/// Stands in for alternative.me. Counts calls so "did not touch the
/// network" can be asserted rather than assumed.
class _FakeApi implements SentimentApi {
  _FakeApi({this.payload, this.failure});

  final Map<String, dynamic>? payload;
  final Object? failure;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetchIndex() async {
    calls++;
    if (failure != null) throw failure!;
    return payload!;
  }
}

/// In-memory stand-in for the Hive-backed cache.
class _FakeCache implements SentimentCache {
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

Future<SentimentIndex> _read(ProviderContainer container) {
  // The provider is `autoDispose`. Reading only its future leaves it
  // without a listener, so it is disposed while still loading and the
  // future never completes. Hold a subscription for the container's life.
  container.listen(sentimentProvider, (_, _) {}, onError: (_, _) {});
  return container.read(sentimentProvider.future);
}

ProviderContainer _container({
  required _FakeApi api,
  required _FakeCache cache,
}) {
  final container = ProviderContainer(
    overrides: [
      sentimentApiProvider.overrideWithValue(api),
      sentimentCacheProvider.overrideWithValue(cache),
      clockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('fetches when nothing is cached, and stores what parsed', () async {
    final api = _FakeApi(payload: _payload());
    final cache = _FakeCache();

    final index = await _read(_container(api: api, cache: cache));

    expect(index.latest.value, 61);
    expect(api.calls, 1);
    expect(cache.writes, 1);
    expect(cache.stored!.cachedAt, _now);
  });

  test('serves a copy inside the TTL without asking the source', () async {
    final cache = _FakeCache(
      CachedPayload(
        cachedAt: _now.subtract(const Duration(minutes: 59)),
        payload: _payload(latest: 44),
      ),
    );
    final api = _FakeApi(payload: _payload());

    final index = await _read(_container(api: api, cache: cache));

    expect(index.latest.value, 44);
    expect(api.calls, 0);
  });

  test('asks again once the TTL has run out', () async {
    final cache = _FakeCache(
      CachedPayload(
        cachedAt: _now.subtract(SentimentCache.ttl),
        payload: _payload(latest: 44),
      ),
    );
    final api = _FakeApi(payload: _payload());

    final index = await _read(_container(api: api, cache: cache));

    expect(api.calls, 1);
    expect(index.latest.value, 61);
  });

  test('serves the cached copy at any age when the fetch fails', () async {
    // A value published once a day is worth showing the day after: it
    // carries its own date, and the screen states which day it reads.
    final cache = _FakeCache(
      CachedPayload(
        cachedAt: _now.subtract(const Duration(days: 9)),
        payload: _payload(latest: 44),
      ),
    );
    final api = _FakeApi(failure: Exception('offline'));

    final index = await _read(_container(api: api, cache: cache));

    expect(index.latest.value, 44);
    expect(api.calls, 1);
    expect(cache.writes, 0);
  });

  test('with no cache and no fetch the screen gets the error', () async {
    final api = _FakeApi(failure: Exception('offline'));

    await expectLater(
      _read(_container(api: api, cache: _FakeCache())),
      throwsA(isA<Exception>()),
    );
  });

  test('metadata.error on HTTP 200 is not cached', () async {
    // The source's own failure channel arrives with a 200. Storing it
    // would serve the failure back for the next hour.
    final api = _FakeApi(
      payload: <String, dynamic>{
        'data': <dynamic>[],
        'metadata': <String, dynamic>{'error': 'API limit reached'},
      },
    );
    final cache = _FakeCache();

    await expectLater(
      _read(_container(api: api, cache: cache)),
      throwsA(isA<FormatException>()),
    );
    expect(cache.writes, 0);
  });

  test('declines every retry', () async {
    // Riverpod 3 would otherwise spend eleven requests over 38 seconds
    // before the reader is allowed to see the error state.
    final api = _FakeApi(failure: Exception('offline'));
    final container = _container(api: api, cache: _FakeCache());

    await expectLater(_read(container), throwsA(isA<Exception>()));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(api.calls, 1);
  });
}
