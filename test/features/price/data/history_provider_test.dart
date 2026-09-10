import 'package:bitcoin_dashboard/core/http/cdn_client.dart';
import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:bitcoin_dashboard/features/price/data/history_cache.dart';
import 'package:bitcoin_dashboard/features/price/data/history_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_history.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_range.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The moment every age in this file is measured from.
final DateTime _now = DateTime.utc(2026, 9, 10, 20);

Map<String, dynamic> _payload(String range, String fetchedAt) =>
    <String, dynamic>{
      'range': range,
      'currency': 'usd',
      'fetchedAt': fetchedAt,
      'timestamps': <Object?>[1788983400000, 1788983700000],
      'prices': <Object?>[78310.95, 78213.21],
    };

/// Stands in for the CDN. Records every path so "asked for the range it
/// was given" can be asserted rather than assumed.
class _FakeCdn implements CdnClient {
  _FakeCdn({this.payload, this.failure});

  final Map<String, dynamic>? payload;
  final Object? failure;
  final List<String> paths = <String>[];

  int get calls => paths.length;

  @override
  Future<Map<String, dynamic>> fetchJson(String path) async {
    paths.add(path);
    if (failure != null) throw failure!;
    return payload!;
  }
}

/// In-memory stand-in for the Hive-backed cache, keyed the same way the
/// real one is.
class _FakeCache implements HistoryCache {
  _FakeCache([Map<PriceRange, CachedPayload>? stored])
    : stored = stored ?? <PriceRange, CachedPayload>{};

  final Map<PriceRange, CachedPayload> stored;
  final List<PriceRange> writes = <PriceRange>[];

  @override
  Future<CachedPayload?> read(PriceRange range) async => stored[range];

  @override
  Future<void> write(
    PriceRange range,
    Map<String, dynamic> payload,
    DateTime now,
  ) async {
    writes.add(range);
    stored[range] = CachedPayload(cachedAt: now, payload: payload);
  }
}

Future<PriceHistory> _read(ProviderContainer container, PriceRange range) {
  // The provider is `autoDispose`. Reading only its future leaves it
  // without a listener, so it is disposed while still loading and the
  // future never completes.
  container.listen(historyProvider(range), (_, _) {}, onError: (_, _) {});
  return container.read(historyProvider(range).future);
}

ProviderContainer _container({
  required _FakeCdn cdn,
  required _FakeCache cache,
}) {
  final container = ProviderContainer(
    overrides: [
      cdnClientProvider.overrideWithValue(cdn),
      historyCacheProvider.overrideWithValue(cache),
      clockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('asks for the document belonging to the range it was given', () async {
    for (final range in PriceRange.values) {
      final cdn = _FakeCdn(
        payload: _payload(range.key, '2026-09-10T19:45:39+00:00'),
      );

      await _read(_container(cdn: cdn, cache: _FakeCache()), range);

      expect(cdn.paths.single, 'data/history-${range.key}.json');
    }
  });

  test('the paths it asks for are upper case', () {
    // `history-1d.json` is a 404. The file names are case-sensitive, so
    // this is a contract, not a style.
    for (final range in PriceRange.values) {
      expect(range.path, matches(RegExp(r'^data/history-\d[DWMY]\.json$')));
    }
  });

  test('fetches when nothing is cached, and stores what it parsed', () async {
    final cdn = _FakeCdn(payload: _payload('1M', '2026-09-10T19:45:39+00:00'));
    final cache = _FakeCache();

    final history = await _read(
      _container(cdn: cdn, cache: cache),
      PriceRange.oneMonth,
    );

    expect(history.points, hasLength(2));
    expect(cdn.calls, 1);
    expect(cache.writes, [PriceRange.oneMonth]);
  });

  test('serves a cached copy inside the TTL without a request', () async {
    final cdn = _FakeCdn(payload: _payload('1M', '2026-09-10T19:45:39+00:00'));
    final cache = _FakeCache({
      PriceRange.oneMonth: CachedPayload(
        cachedAt: _now.subtract(const Duration(minutes: 5)),
        payload: _payload('1M', '2026-09-10T19:30:39+00:00'),
      ),
    });

    final history = await _read(
      _container(cdn: cdn, cache: cache),
      PriceRange.oneMonth,
    );

    expect(cdn.calls, 0, reason: 'a fresh cache must not hit the network');
    expect(history.fetchedAt, DateTime.utc(2026, 9, 10, 19, 30, 39));
  });

  test('one range does not serve another range its series', () async {
    // The whole point of the cache key: five documents in one box.
    final cdn = _FakeCdn(payload: _payload('1W', '2026-09-10T19:45:39+00:00'));
    final cache = _FakeCache({
      PriceRange.oneMonth: CachedPayload(
        cachedAt: _now.subtract(const Duration(minutes: 5)),
        payload: _payload('1M', '2026-09-10T19:30:39+00:00'),
      ),
    });

    await _read(_container(cdn: cdn, cache: cache), PriceRange.oneWeek);

    expect(cdn.paths.single, 'data/history-1W.json');
  });

  test('refetches once the cached copy is older than the TTL', () async {
    final cdn = _FakeCdn(payload: _payload('1M', '2026-09-10T19:45:39+00:00'));
    final cache = _FakeCache({
      PriceRange.oneMonth: CachedPayload(
        // Sixteen minutes: the producer has written again by now.
        cachedAt: _now.subtract(const Duration(minutes: 16)),
        payload: _payload('1M', '2026-09-10T19:15:39+00:00'),
      ),
    });

    final history = await _read(
      _container(cdn: cdn, cache: cache),
      PriceRange.oneMonth,
    );

    expect(cdn.calls, 1);
    expect(history.fetchedAt, DateTime.utc(2026, 9, 10, 19, 45, 39));
  });

  test(
    'falls back to the cached copy at any age when the fetch fails',
    () async {
      final cdn = _FakeCdn(failure: Exception('CDN unreachable'));
      final cache = _FakeCache({
        PriceRange.oneYear: CachedPayload(
          cachedAt: _now.subtract(const Duration(days: 4)),
          payload: _payload('1Y', '2026-09-06T19:45:39+00:00'),
        ),
      });

      final history = await _read(
        _container(cdn: cdn, cache: cache),
        PriceRange.oneYear,
      );

      expect(cdn.calls, 1);
      expect(
        history.freshnessAt(_now),
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
        _read(_container(cdn: cdn, cache: _FakeCache()), PriceRange.oneDay),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('does not cache a payload it could not parse', () async {
    final cdn = _FakeCdn(
      payload: const <String, dynamic>{
        'range': '1M',
        'timestamps': <Object?>[1, 2],
        'prices': <Object?>[1.0, 2.0],
      },
    );
    final cache = _FakeCache();

    await expectLater(
      _read(_container(cdn: cdn, cache: cache), PriceRange.oneMonth),
      throwsA(isA<FormatException>()),
    );
    expect(
      cache.writes,
      isEmpty,
      reason: 'caching an unreadable document would serve it back for 15 min',
    );
  });

  test('an empty series is data, not an error', () async {
    final cdn = _FakeCdn(
      payload: const <String, dynamic>{
        'range': '1M',
        'currency': 'usd',
        'fetchedAt': '2026-09-10T19:45:39+00:00',
        'timestamps': <Object?>[],
        'prices': <Object?>[],
      },
    );
    final cache = _FakeCache();

    final history = await _read(
      _container(cdn: cdn, cache: cache),
      PriceRange.oneMonth,
    );

    expect(history.points, isEmpty);
    expect(
      cache.writes,
      hasLength(1),
      reason: 'it parsed — it is worth keeping',
    );
  });

  test('the selected range starts on the month', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(selectedPriceRangeProvider), PriceRange.oneMonth);
  });
}
