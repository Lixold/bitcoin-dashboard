import 'dart:convert';
import 'dart:typed_data';

import 'package:bitcoin_dashboard/core/http/dio_provider.dart';
import 'package:bitcoin_dashboard/features/market/data/sentiment_api.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_index.dart';
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

SentimentApi _api(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(dio.close);
  return SentimentApi(dio);
}

const String _body =
    '{"name":"Fear and Greed Index",'
    '"data":[{"value":"61","value_classification":"Greed",'
    '"timestamp":"1789257600","time_until_update":"19536"}],'
    '"metadata":{"error":null}}';

void main() {
  test('asks the endpoint ADR-0002 documents, and no other', () async {
    final adapter = _FakeAdapter(_body);

    await _api(adapter).fetchIndex();

    final request = adapter.lastRequest!;
    expect(request.method, 'GET');
    expect(request.uri.origin, 'https://api.alternative.me');
    expect(request.uri.path, '/fng/');
    expect(request.uri.queryParameters, {
      'limit': '${SentimentIndex.windowDays}',
    });
    // No key, no cookie, no identifying header beyond the user agent the
    // app sets for every host (CLAUDE.md §1).
    expect(request.headers.containsKey('authorization'), isFalse);
  });

  test('hands the payload back unparsed', () async {
    // The provider caches what it received and parses separately, so a
    // document that reaches the cache is one the app could read.
    final payload = await _api(_FakeAdapter(_body)).fetchIndex();

    expect(payload, jsonDecode(_body));
  });

  test('an empty body is a FormatException, not a null payload', () async {
    await expectLater(
      _api(_FakeAdapter('')).fetchIndex(),
      throwsA(isA<FormatException>()),
    );
  });

  test('the provider builds the API on the app dio', () async {
    final adapter = _FakeAdapter(_body);
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          ref.onDispose(dio.close);
          return dio;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sentimentApiProvider).fetchIndex();

    expect(adapter.lastRequest!.uri.host, 'api.alternative.me');
  });
}
