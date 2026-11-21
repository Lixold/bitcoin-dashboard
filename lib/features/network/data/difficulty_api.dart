import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_provider.dart';
import '../../../core/time/clock.dart';
import '../domain/difficulty_snapshot.dart';

/// The one mempool.space endpoint the difficulty statement reads.
///
/// No new host: mempool.space is already an outbound host in ADR-0002,
/// and this path is listed under "Direct live calls" in ADR-0005.
///
/// Takes the clock rather than reading it, as `MempoolApi` does: the
/// response carries no timestamp, so the moment the reading records is the
/// moment this call returned.
class DifficultyApi {
  DifficultyApi(this._dio, this._now);

  static const String url =
      'https://mempool.space/api/v1/difficulty-adjustment';

  final Dio _dio;
  final Clock _now;

  Future<DifficultySnapshot> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(url);
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty body from mempool.space $url');
    }
    return DifficultySnapshot.fromJson(data, observedAt: _now());
  }
}

final difficultyApiProvider = Provider<DifficultyApi>((ref) {
  return DifficultyApi(ref.watch(dioProvider), ref.watch(clockProvider));
});
