/// Satoshis in one bitcoin.
///
/// The Bitcoin protocol's own unit, not a display choice: amounts are
/// counted in satoshis everywhere below the user interface, and a hundred
/// million of them are one bitcoin by definition.
const int satsPerBitcoin = 100000000;

/// How many satoshis one unit of the currency buys, at [pricePerBitcoin]
/// quoted in that currency.
///
/// **The price read the other way round.** A price says what a bitcoin
/// costs; this says what the reader's own unit buys, which is the question
/// somebody holding euros rather than bitcoin actually has.
///
/// `null` for a price that cannot carry the question — the division is
/// only meaningful for a finite price above zero, and the line is left out
/// rather than shown as a figure nothing stands behind.
double? satsPerUnit(double pricePerBitcoin) {
  if (!pricePerBitcoin.isFinite || pricePerBitcoin <= 0) return null;
  return satsPerBitcoin / pricePerBitcoin;
}
