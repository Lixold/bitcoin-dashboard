import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Singleton dio instance for all outbound HTTP. Per ADR-002/005 the app
/// talks directly to public APIs (Binance, mempool.space, alternative.me)
/// and to the static CDN — no auth headers, no cookies.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        // Identifies us in upstream logs without leaking PII.
        'User-Agent': 'BitcoinDashboard/0.1 (+https://bitcoin-dashboard.app)',
      },
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
