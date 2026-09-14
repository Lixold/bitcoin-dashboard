import 'package:intl/intl.dart';

/// A whole count with the locale's thousands separator: `26,579` in
/// English, `26.579` in German.
///
/// **It stays in this statement rather than in `core/format/`.** That
/// directory holds money, percentages and thresholds — each of them
/// moved there once a second statement needed the identical figure, the
/// way `formatShare` did. The node count is the first and so far only
/// count in the app; moving it up front would put a shared definition in
/// a shared place for a single caller, and the next count may well want
/// a different rounding anyway.
String formatNodeCount(String locale, int count) =>
    NumberFormat.decimalPattern(locale).format(count);
