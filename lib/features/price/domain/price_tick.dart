/// One observation of a trading pair. Price comes in the quote currency
/// (USD for `BTCUSDT` on Binance); FX conversion happens in the UI layer.
class PriceTick {
  const PriceTick({
    required this.symbol,
    required this.price,
    required this.observedAt,
  });

  /// Reads a Binance `ticker/price` body, stamped with [observedAt].
  ///
  /// **The moment is a parameter because it is not in the payload.**
  /// Binance answers with a symbol and a price and says nothing about
  /// when; "when" is whenever this app happened to ask. Reading the clock
  /// here would put that decision in a domain factory, where no test can
  /// reach it — the caller passes `clockProvider`'s answer instead.
  ///
  /// Normalised to UTC on the way in, so every [PriceTick] carries the
  /// same kind of instant no matter which clock produced it.
  factory PriceTick.fromBinanceTicker(
    Map<String, dynamic> json, {
    required DateTime observedAt,
  }) {
    return PriceTick(
      symbol: json['symbol'] as String,
      price: double.parse(json['price'] as String),
      observedAt: observedAt.toUtc(),
    );
  }

  final String symbol;
  final double price;

  /// When the app received this observation, in UTC.
  final DateTime observedAt;
}
