import 'dart:typed_data';

import 'package:bitcoin_dashboard/core/http/dio_provider.dart';
import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:bitcoin_dashboard/features/price/data/binance_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [body] and keeps what was asked for, so the
/// endpoint can be asserted without opening a socket.
///
/// Replacing the adapter rather than faking [Dio] keeps the real request
/// path in the test: the URL dio assembles, the query it appends and the
/// JSON transform it applies are all still the app's own.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final String body;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A [BinanceApi] whose wire is [adapter] and whose clock answers [now].
BinanceApi _api(_FakeAdapter adapter, {required DateTime now}) {
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(dio.close);
  return BinanceApi(dio, () => now);
}

const String _body = '{"symbol":"BTCUSDT","price":"96442.50"}';

void main() {
  test('stamps the tick with the moment the fetch returned', () async {
    // The body carries no timestamp, so this is the only source for it.
    final frozen = DateTime.utc(2026, 5, 14, 14, 32);

    final tick = await _api(_FakeAdapter(_body), now: frozen).tickerPrice();

    expect(tick.observedAt, frozen);
  });

  test(
    'records the moment in UTC whatever kind the clock hands over',
    () async {
      // The production clock is DateTime.now(), which is local. Every tick
      // has to carry the same kind of instant regardless.
      final local = DateTime.utc(2026, 5, 14, 14, 32).toLocal();

      final tick = await _api(_FakeAdapter(_body), now: local).tickerPrice();

      expect(tick.observedAt.isUtc, isTrue);
      expect(tick.observedAt, DateTime.utc(2026, 5, 14, 14, 32));
    },
  );

  test('reads the symbol and the price out of the body', () async {
    final tick = await _api(
      _FakeAdapter(_body),
      now: DateTime.utc(2026, 5, 14),
    ).tickerPrice();

    expect(tick.symbol, 'BTCUSDT');
    expect(tick.price, 96442.50);
  });

  test('asks the endpoint ADR-0002 documents, and no other', () async {
    final adapter = _FakeAdapter(_body);

    await _api(adapter, now: DateTime.utc(2026, 5, 14)).tickerPrice();

    final request = adapter.lastRequest!;
    expect(request.method, 'GET');
    expect(request.uri.origin, 'https://api.binance.com');
    expect(request.uri.path, '/api/v3/ticker/price');
    expect(request.uri.queryParameters, {'symbol': 'BTCUSDT'});
  });

  test('a caller may ask for another pair', () async {
    final adapter = _FakeAdapter('{"symbol":"ETHUSDT","price":"3021.10"}');

    final tick = await _api(
      adapter,
      now: DateTime.utc(2026, 5, 14),
    ).tickerPrice(symbol: 'ETHUSDT');

    expect(adapter.lastRequest!.uri.queryParameters, {'symbol': 'ETHUSDT'});
    expect(tick.symbol, 'ETHUSDT');
  });

  test('an empty body is a FormatException, not a null price', () async {
    await expectLater(
      _api(_FakeAdapter(''), now: DateTime.utc(2026, 5, 14)).tickerPrice(),
      throwsA(isA<FormatException>()),
    );
  });

  test('the provider hands the API the app clock', () async {
    // Without this wiring the seam exists and nothing reaches it.
    final frozen = DateTime.utc(2026, 5, 14, 14, 32);
    final adapter = _FakeAdapter(_body);
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => frozen),
        dioProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          ref.onDispose(dio.close);
          return dio;
        }),
      ],
    );
    addTearDown(container.dispose);

    final tick = await container.read(binanceApiProvider).tickerPrice();

    expect(tick.observedAt, frozen);
  });
}
