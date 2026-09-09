import 'package:bitcoin_dashboard/features/price/domain/price_tick.dart';
import 'package:flutter_test/flutter_test.dart';

PriceTick _tick(String symbol) => PriceTick(
  symbol: symbol,
  price: 78679.4,
  observedAt: DateTime.utc(2026, 9, 9, 19),
);

void main() {
  group('quote currency', () {
    test('the dollar stablecoin reports as dollars', () {
      // `intl` has no symbol for USDT, so a reader would be shown the
      // letters in front of a price that is dollars in every way that
      // matters to them.
      expect(_tick('BTCUSDT').quoteCurrency, 'USD');
    });

    test('another quote currency comes through as itself', () {
      expect(_tick('BTCEUR').quoteCurrency, 'EUR');
    });

    test('an unrecognised pair reports its tail rather than guessing', () {
      expect(_tick('BTCXYZ').quoteCurrency, 'XYZ');
    });
  });
}
