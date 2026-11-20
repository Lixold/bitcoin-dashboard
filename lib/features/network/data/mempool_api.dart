import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_provider.dart';
import '../../../core/time/clock.dart';
import '../domain/mempool_snapshot.dart';

/// The two mempool.space endpoints the mempool statement reads.
///
/// No new host: mempool.space is already an outbound host in ADR-0002.
/// These two paths are listed under "Direct live calls" in ADR-0005.
///
/// Takes the clock rather than reading it, for the same reason
/// `BinanceApi` does: neither response carries a timestamp, so the moment
/// the reading records is the moment this call returned.
class MempoolApi {
  MempoolApi(this._dio, this._now);

  static const String host = 'https://mempool.space';
  static const String mempoolPath = '/api/mempool';
  static const String feesPath = '/api/v1/fees/recommended';

  final Dio _dio;
  final Clock _now;

  /// Both endpoints at once, parsed into one reading.
  ///
  /// Either failing fails the reading. The statement makes one claim out
  /// of both — the load and the fee in one sentence — and half of it from
  /// this minute next to half from an earlier one would be a claim no
  /// single moment supports.
  Future<MempoolSnapshot> fetch() async {
    final (mempool, fees) = await (
      _getJson(mempoolPath),
      _getJson(feesPath),
    ).wait;
    return MempoolSnapshot.fromJson(
      mempool: mempool,
      fees: fees,
      observedAt: _now(),
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _dio.get<Map<String, dynamic>>('$host$path');
    final data = response.data;
    if (data == null) {
      throw FormatException('Empty body from mempool.space $path');
    }
    return data;
  }
}

final mempoolApiProvider = Provider<MempoolApi>((ref) {
  return MempoolApi(ref.watch(dioProvider), ref.watch(clockProvider));
});
