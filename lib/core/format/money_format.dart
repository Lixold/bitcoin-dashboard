import 'package:intl/intl.dart';

/// Amounts, in the currency the data is quoted in.
///
/// **The currency comes from the source, never from the setting.** The
/// app cannot convert yet — that is #32 — so an amount rendered under the
/// symbol the reader picked would not be a formatting choice, it would be
/// a wrong number. Until the conversion exists, everything on screen says
/// what the producer published: `market.json` declares `usd`, the Binance
/// pair quotes `USDT`. When #32 lands it converts the value and the
/// symbol together, here, and every caller follows without being touched.
///
/// The *number* still follows the reader's locale — a German reader sees
/// `126.080,00 $`, an English one `$126,080.00`. Locale governs how
/// digits are grouped; the source governs what unit they are in.

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

/// The payload writes `usd`; `intl` keys its currency data on `USD`.
String _isoCode(String currency) => currency.toUpperCase();
