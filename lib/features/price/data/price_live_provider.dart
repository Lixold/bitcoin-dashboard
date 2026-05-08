import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/price_tick.dart';
import 'binance_api.dart';

/// 60-second polling stream of the live BTC/USDT price.
///
/// One immediate fetch on subscribe, then a tick every minute. The stream
/// stays open while at least one widget is listening; `ref.onDispose`
/// cancels the timer when no one watches anymore.
final priceLiveProvider = StreamProvider.autoDispose<PriceTick>((ref) {
  final api = ref.watch(binanceApiProvider);
  final controller = StreamController<PriceTick>();

  Future<void> fetch() async {
    try {
      controller.add(await api.tickerPrice());
    } catch (e, st) {
      controller.addError(e, st);
    }
  }

  // Fire-and-forget initial fetch.
  unawaited(fetch());
  final timer = Timer.periodic(const Duration(seconds: 60), (_) => fetch());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
