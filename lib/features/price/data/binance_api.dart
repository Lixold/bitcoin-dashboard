import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_provider.dart';
import '../../../core/time/clock.dart';
import '../domain/price_tick.dart';

/// Thin wrapper around the public Binance REST endpoint we need.
/// Endpoint: `GET /api/v3/ticker/price?symbol=BTCUSDT` — no auth, no key.
///
/// Takes the clock rather than reading it: the response carries no
/// timestamp, so the moment a tick records is the moment this call
/// returned, and a test has to be able to say which moment that was.
class BinanceApi {
  BinanceApi(this._dio, this._now);

  static const String _base = 'https://api.binance.com';

  final Dio _dio;
  final Clock _now;

  Future<PriceTick> tickerPrice({String symbol = 'BTCUSDT'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/api/v3/ticker/price',
      queryParameters: {'symbol': symbol},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty body from Binance ticker/price');
    }
    return PriceTick.fromBinanceTicker(data, observedAt: _now());
  }
}

final binanceApiProvider = Provider<BinanceApi>((ref) {
  return BinanceApi(ref.watch(dioProvider), ref.watch(clockProvider));
});
