import 'package:intl/intl.dart';

/// Percentages in the statement: one decimal.
///
/// The two headline figures are read at a glance and compared against
/// thresholds written as whole numbers, so a second decimal adds noise
/// without adding meaning.
String formatShare(String locale, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(value);

/// Percentages in the evidence: two decimals, as the payload carries them.
///
/// The evidence is where a reader checks the claim, so the rows and the
/// coverage figure underneath them have to add up. Rounding to one
/// decimal here would print ten shares that visibly do not sum to the
/// total printed below them.
String formatShareExact(String locale, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    ).format(value);

/// [formatShareExact] with the unit, for the figure at the end of a row.
String formatShareDetailed(String locale, double value) =>
    '${formatShareExact(locale, value)} %';

/// Whole percentage points, for the distance-to-threshold note.
String formatPoints(String locale, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(value);

/// A threshold as it is written in the issue's matrix: a whole number.
String formatThreshold(String locale, double value) =>
    NumberFormat.decimalPattern(locale).format(value);
