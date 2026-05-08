/// One observation of a trading pair. Price comes in the quote currency
/// (USD for `BTCUSDT` on Binance); FX conversion happens in the UI layer.
class PriceTick {
  const PriceTick({
    required this.symbol,
    required this.price,
    required this.observedAt,
  });

  factory PriceTick.fromBinanceTicker(Map<String, dynamic> json) {
    return PriceTick(
      symbol: json['symbol'] as String,
      price: double.parse(json['price'] as String),
      observedAt: DateTime.now().toUtc(),
    );
  }

  final String symbol;
  final double price;
  final DateTime observedAt;
}
