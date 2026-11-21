import 'dart:convert';
import 'dart:typed_data';

import 'package:bitcoin_dashboard/features/network/data/difficulty_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// Answers every request with [body] and [status], and records every URL
/// asked for. Replacing the adapter rather than faking [Dio] keeps the
/// real request path in the test, as `mempool_api_test.dart` does.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body, {this.status = 200});

  final Object? body;
  final int status;
  final List<Uri> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final DateTime _now = DateTime.utc(2026, 11, 21, 12, 29);

DifficultyApi _api(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(dio.close);
  return DifficultyApi(dio, () => _now);
}

void main() {
  test('reads the one endpoint on mempool.space and no other host', () async {
    final adapter = _FakeAdapter(
      loadJsonFixture('mempool-space-difficulty-adjustment.json'),
    );

    await _api(adapter).fetch();

    expect(adapter.requested.map((uri) => uri.toString()), [
      'https://mempool.space/api/v1/difficulty-adjustment',
    ]);
  });

  test('parses the reading and stamps it with the fetch time', () async {
    final snapshot = await _api(
      _FakeAdapter(loadJsonFixture('mempool-space-difficulty-adjustment.json')),
    ).fetch();

    expect(snapshot.remainingBlocks, 857);
    expect(snapshot.observedAt, _now);
  });

  test('fails the reading on an error status', () async {
    await expectLater(
      _api(_FakeAdapter(const <String, dynamic>{}, status: 503)).fetch(),
      throwsA(isA<DioException>()),
    );
  });

  test('fails the reading on an empty body', () async {
    await expectLater(_api(_FakeAdapter(null)).fetch(), throwsFormatException);
  });
}
