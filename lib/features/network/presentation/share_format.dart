import 'package:intl/intl.dart';

import '../../../core/format/percent_format.dart';

export '../../../core/format/percent_format.dart' show formatThreshold;

/// Percentages in the statement: one decimal.
///
/// The shared [formatPercent] under its name in this statement. Both
/// price statements need the same figure, so the definition moved to
/// `core/format/` and this stayed as the name the network screen reads
/// with.
String formatShare(String locale, double value) => formatPercent(locale, value);

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
