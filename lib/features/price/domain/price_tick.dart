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

  /// The currency [price] is quoted in, as an ISO 4217 code.
  ///
  /// Derived from the pair rather than stored: Binance names the pair and
  /// says nothing about currencies, so the quote currency is whatever the
  /// symbol's tail says it is. `USDT` reports as `USD` — it is a dollar
  /// stablecoin, and `intl` has no symbol for the token itself, so a
  /// reader would be shown the letters `USDT` in front of a price that is
  /// dollars in every way that matters to them.
  ///
  /// An unrecognised pair reports its tail unchanged. That renders as the
  /// code rather than a symbol, which is the honest outcome: better a
  /// price labelled with letters nobody expected than one labelled with
  /// the wrong symbol.
  String get quoteCurrency => quoteCurrencyOf(symbol);

  /// [quoteCurrency] for a pair the app has not observed yet.
  ///
  /// The screen has to name a currency before the first tick arrives —
  /// the pill sits in the header from the first frame — and the pair the
  /// app asks for is known at that point even though its price is not.
  static String quoteCurrencyOf(String symbol) {
    const base = 'BTC';
    final quote = symbol.startsWith(base)
        ? symbol.substring(base.length)
        : symbol;
    return quote == 'USDT' ? 'USD' : quote;
  }

  /// When the app received this observation, in UTC.
  final DateTime observedAt;
}
