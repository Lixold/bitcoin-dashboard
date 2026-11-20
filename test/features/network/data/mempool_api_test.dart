import 'dart:convert';
import 'dart:typed_data';

import 'package:bitcoin_dashboard/features/network/data/mempool_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// Answers each path with its body, or with a 503 when [failing] names
/// it, and records every URL asked for.
///
/// Replacing the adapter rather than faking [Dio] keeps the real request
/// path in the test, as `binance_api_test.dart` does.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.bodies, {this.failing = const {}});

  final Map<String, Map<String, dynamic>> bodies;
  final Set<String> failing;
  final List<Uri> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    final path = options.uri.path;
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (failing.contains(path)) {
      return ResponseBody.fromString('{}', 503, headers: headers);
    }
    return ResponseBody.fromString(
      jsonEncode(bodies[path]),
      200,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

final DateTime _now = DateTime.utc(2026, 11, 20, 13, 11);

Map<String, Map<String, dynamic>> _captured() => {
  MempoolApi.mempoolPath: loadJsonFixture('mempool-space-mempool.json'),
  MempoolApi.feesPath: loadJsonFixture('mempool-space-fees-recommended.json'),
};

MempoolApi _api(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(dio.close);
  return MempoolApi(dio, () => _now);
}

void main() {
  test('reads both endpoints on mempool.space and no other host', () async {
    final adapter = _FakeAdapter(_captured());

    await _api(adapter).fetch();

    expect(adapter.requested.map((uri) => uri.toString()), {
      'https://mempool.space/api/mempool',
      'https://mempool.space/api/v1/fees/recommended',
    });
  });

  test('combines them into one reading stamped with the fetch time', () async {
    final snapshot = await _api(_FakeAdapter(_captured())).fetch();

    expect(snapshot.count, 81456);
    expect(snapshot.hourFee, 4);
    expect(snapshot.observedAt, _now);
  });

  test('fails the reading when the fee endpoint fails', () async {
    final adapter = _FakeAdapter(_captured(), failing: {MempoolApi.feesPath});

    await expectLater(_api(adapter).fetch(), throwsA(anything));
  });

  test('fails the reading when the mempool endpoint fails', () async {
    final adapter = _FakeAdapter(
      _captured(),
      failing: {MempoolApi.mempoolPath},
    );

    await expectLater(_api(adapter).fetch(), throwsA(anything));
  });
}
