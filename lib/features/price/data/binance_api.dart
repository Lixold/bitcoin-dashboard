import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_provider.dart';
import '../domain/price_tick.dart';

/// Thin wrapper around the public Binance REST endpoint we need.
/// Endpoint: `GET /api/v3/ticker/price?symbol=BTCUSDT` — no auth, no key.
class BinanceApi {
  BinanceApi(this._dio);

  static const String _base = 'https://api.binance.com';

  final Dio _dio;

  Future<PriceTick> tickerPrice({String symbol = 'BTCUSDT'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/api/v3/ticker/price',
      queryParameters: {'symbol': symbol},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty body from Binance ticker/price');
    }
    return PriceTick.fromBinanceTicker(data);
  }
}

final binanceApiProvider = Provider<BinanceApi>((ref) {
  return BinanceApi(ref.watch(dioProvider));
});
