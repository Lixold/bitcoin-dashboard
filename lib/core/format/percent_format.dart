import 'package:intl/intl.dart';

/// Percentages and the thresholds they are read against.
///
/// These two live here rather than with the network statement that wrote
/// them first, because both statements on the price screen need the
/// identical thing: a share at one decimal, and a threshold as the whole
/// number the issue writes it as. Two definitions of "a percentage in
/// this app" would drift the first time one of them gained a digit.
///
/// The formatters that *are* network copy — the two-decimal evidence
/// figure, the distance-to-threshold note — stay in
/// `features/network/presentation/share_format.dart`. Nothing outside
/// that statement asks for them.

/// A share, at one decimal.
///
/// The headline figures are read at a glance and compared against
/// thresholds written as whole numbers, so a second decimal adds noise
/// without adding meaning.
String formatPercent(String locale, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(value);

/// A threshold as it is written in an issue's matrix: a whole number.
String formatThreshold(String locale, double value) =>
    NumberFormat.decimalPattern(locale).format(value);
