import 'dart:math' show ln10, log;

import 'package:intl/intl.dart';

import '../fx/fx_rates.dart';

/// Amounts, in the currency the reader picked.
///
/// **The conversion and the symbol move together, and they move here.**
/// Before #32 every amount on screen was rendered in whatever its producer
/// published — `market.json` declares `usd`, the Binance pair quotes
/// `USDT` — because a symbol the reader picked over a number the producer
/// published is not a formatting choice, it is a wrong number. [MoneyDisplay]
/// is where the two now change at once: it holds the rate and the code it
/// resolved to, and a caller hands it an amount and the currency that
/// amount arrived in.
///
/// The *number* still follows the reader's locale — a German reader sees
/// `126.080,00 $`, an English one `$126,080.00`. Locale governs how digits
/// are grouped; the display governs what unit they are in.

/// Why the amounts on screen are in the currency they are in.
///
/// The four are what the screen has to tell apart, not decoration: three of
/// them render amounts and say different things about them, and the fourth
/// renders none at all.
enum MoneyDisplayState {
  /// The reader's currency is the one the data arrives in. Nothing is
  /// converted and no rate is involved, so no rate can be old.
  source,

  /// Amounts are converted, with a rate that may still be worth dating.
  converted,

  /// A conversion is wanted and the rates have not arrived yet. **Nothing
  /// is rendered in this state** — an amount shown now would either be the
  /// unconverted one under the reader's symbol, which is the wrong number,
  /// or the right number under a claim that it failed to arrive.
  pending,

  /// A conversion is wanted and cannot be made: the document is
  /// unreachable, unreadable, or quotes nothing for the chosen code.
  /// Amounts fall back to the currency they arrived in and the screen says
  /// so.
  unavailable,
}

/// Which currency amounts are rendered in, and the rate that gets them
/// there.
///
/// Built once per frame from the reader's setting and [FxRates], and then
/// asked per amount, because the currency an amount arrives in is a
/// property of that amount's producer rather than of the app.
///
/// **A symbol and a number can never disagree here.** Every path through
/// [format] takes the rate and the code from the same decision: where
/// there is a rate the amount is converted and carries the display code,
/// and where there is none it is left alone and carries its own. There is
/// no branch that applies one without the other.
class MoneyDisplay {
  const MoneyDisplay._({
    required this.currency,
    required this.state,
    required FxRates? rates,
  }) : _rates = rates;

  /// Resolves what the screen can show from what the reader asked for and
  /// what the CDN has said so far.
  ///
  /// [isLoading] separates "not yet" from "not at all"; both arrive here
  /// as an absent [rates], and they are not the same thing to a reader.
  factory MoneyDisplay.resolve({
    required String wanted,
    required FxRates? rates,
    required bool isLoading,
  }) {
    final target = wanted.toUpperCase();
    if (target == sourceCurrency) {
      return MoneyDisplay._(
        currency: sourceCurrency,
        state: MoneyDisplayState.source,
        rates: rates,
      );
    }
    if (rates != null && rates.rate(from: sourceCurrency, to: target) != null) {
      return MoneyDisplay._(
        currency: target,
        state: MoneyDisplayState.converted,
        rates: rates,
      );
    }
    // Both states below render amounts in the source currency, so that is
    // what [currency] reports and what the header pill reads — the pill
    // names the unit the figures are actually in, never the one the
    // setting asks for. The setting itself is untouched and takes effect
    // again as soon as a rate arrives.
    return MoneyDisplay._(
      currency: sourceCurrency,
      state: isLoading
          ? MoneyDisplayState.pending
          : MoneyDisplayState.unavailable,
      rates: null,
    );
  }

  /// The ISO 4217 code amounts are rendered in.
  final String currency;

  /// Why [currency] is the one it is.
  final MoneyDisplayState state;

  final FxRates? _rates;

  /// The rate behind the amounts, for the screen to date. `null` wherever
  /// no rate was used — including [MoneyDisplayState.source], where there
  /// was nothing to convert.
  FxRates? get rates => state == MoneyDisplayState.converted ? _rates : null;

  /// Whether the rates are still on their way.
  ///
  /// The screen renders no amount while this is true; see
  /// [MoneyDisplayState.pending].
  bool get isPending => state == MoneyDisplayState.pending;

  /// One amount, converted where a rate says so, with its currency symbol.
  ///
  /// [from] is the ISO 4217 code the amount was published in, in any case.
  String format(String locale, double amount, {required String from}) =>
      formatMoney(
        locale,
        displayedAmount(amount, from: from),
        displayedCurrency(from),
      );

  /// [format] in short form, for figures too large to read digit by digit.
  String formatCompact(String locale, double amount, {required String from}) =>
      formatMoneyCompact(
        locale,
        displayedAmount(amount, from: from),
        displayedCurrency(from),
      );

  /// The amount as the reader sees it: converted where a rate says so,
  /// unchanged where none does.
  ///
  /// The screen needs the figure as well as the string — the sats line
  /// divides by it.
  double displayedAmount(double amount, {required String from}) =>
      amount * (_rateFrom(from) ?? 1);

  /// The currency [displayedAmount] came out in.
  String displayedCurrency(String from) =>
      _rateFrom(from) == null ? from.toUpperCase() : currency;

  /// The factor from [from] into [currency], or `null` when there is none.
  double? _rateFrom(String from) {
    if (from.toUpperCase() == currency) return 1;
    return _rates?.rate(from: from, to: currency);
  }
}

/// One amount, with its currency symbol.
///
/// [currency] is an ISO 4217 code as the payload writes it, in any case.
/// `intl` owns the code-to-symbol mapping, so an unknown code renders as
/// the code itself rather than as a guessed symbol.
String formatMoney(String locale, double amount, String currency) =>
    NumberFormat.simpleCurrency(
      locale: locale,
      name: _isoCode(currency),
      decimalDigits: 2,
    ).format(amount);

/// One amount in short form, for figures too large to read digit by
/// digit — a market capitalisation in the trillions.
///
/// **The short form is a false friend and `intl` is the one that knows
/// it.** The English *trillion* is 10¹², the German *Billion* is too, but
/// the German *Billiarde* is 10¹⁵ where English says *quadrillion*, and
/// English *billion* is the German *Milliarde*. Writing the suffix by
/// hand would be right in one locale and wrong in the other; the same
/// figure here renders as `$1.58T` and as `1,58 Bio. $`.
String formatMoneyCompact(String locale, double amount, String currency) =>
    NumberFormat.compactSimpleCurrency(
      locale: locale,
      name: _isoCode(currency),
    ).format(amount);

/// The symbol `intl` sets an amount in [currency] with — `€`, `$`, `₩`.
///
/// The sats line names the unit on its own rather than in front of a
/// figure, which is the one place in the app that needs the symbol apart
/// from an amount.
String currencySymbol(String locale, String currency) =>
    NumberFormat.simpleCurrency(
      locale: locale,
      name: _isoCode(currency),
    ).currencySymbol;

/// How many satoshis one unit of the reader's currency buys.
///
/// **Whole sats, until whole sats would say zero.** A sat is the smallest
/// unit there is, so a fraction of one is not a figure anybody counts —
/// but the strong-currency assumption behind that breaks on the weak ones
/// the ECB quotes. One euro is some 1,400 sats and one dollar some 1,300;
/// one Indonesian rupiah is 0.07, and `1 Rp = 0 sats` is not a rounding,
/// it is a false statement about the world. Below one sat the figure keeps
/// two significant digits, which is enough to stay true and few enough
/// that it still reads as a unit price.
String formatSats(String locale, double sats) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: _satsDecimals(sats),
    ).format(sats);

int _satsDecimals(double sats) {
  if (!sats.isFinite || sats >= 1 || sats <= 0) return 0;
  // log10 of 0.072 is −1.14, so the first significant digit sits in the
  // second place after the point and the second in the third.
  return (1 - (log(sats) / ln10).floor()).clamp(2, 8);
}

/// The payload writes `usd`; `intl` keys its currency data on `USD`.
String _isoCode(String currency) => currency.toUpperCase();
