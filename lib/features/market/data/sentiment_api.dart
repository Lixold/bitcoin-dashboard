import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_provider.dart';
import '../domain/sentiment_index.dart';

/// Thin wrapper around the one public alternative.me endpoint we need.
/// Endpoint: `GET /fng/?limit=30` — no auth, no key, no cookie
/// (ADR-0002).
///
/// It hands the payload back unparsed. The provider caches exactly what
/// it received and parses separately, so a document that reaches the
/// cache is one the app could read — and the parse rules stay in
/// [SentimentIndex] where they can be tested without a wire.
///
/// Unlike `BinanceApi` this takes no clock: every entry in this payload
/// carries the day it belongs to, so nothing here has to be stamped with
/// the moment the fetch returned.
class SentimentApi {
  SentimentApi(this._dio);

  static const String _base = 'https://api.alternative.me';

  final Dio _dio;

  /// The last [SentimentIndex.windowDays] days, newest first as the
  /// source serves them.
  Future<Map<String, dynamic>> fetchIndex() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/fng/',
      queryParameters: {'limit': '${SentimentIndex.windowDays}'},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty body from alternative.me fng');
    }
    return data;
  }
}

final sentimentApiProvider = Provider<SentimentApi>((ref) {
  return SentimentApi(ref.watch(dioProvider));
});
