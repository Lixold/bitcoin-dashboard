/// How Bitcoin's share of the crypto market reads.
enum DominanceVerdict { high, stable, low }

/// Bitcoin's share of the total crypto market capitalisation, as a
/// verdict the screen can state in words.
///
/// The market capitalisation the share is a share *of* is not part of
/// this class. It is evidence under the statement, never the statement:
/// on its own a total in the trillions answers no question the reader
/// asked.
class MarketDominance {
  const MarketDominance({required this.share, required this.verdict});

  /// Threshold matrix from issue #30, as two named numbers.
  ///
  /// **Both bounds belong to the level above them**, as in
  /// [AthDistance]: exactly 45.0 % is already stable, exactly 55.0 % is
  /// already high. [verdictFor] is tested on both boundaries.
  static const double lowThreshold = 45;
  static const double highThreshold = 55;

  /// Bitcoin's share, in percent.
  final double share;

  /// What the rest of the market holds, in percent — the second bar.
  ///
  /// Derived rather than read: the payload carries one share, and a
  /// remainder computed anywhere else would be a second definition of
  /// the same number.
  double get rest => (100 - share).clamp(0.0, 100.0);

  final DominanceVerdict verdict;

  /// Derives the statement, or returns `null` when the share is missing
  /// or outside the range a share can occupy.
  static MarketDominance? from(double? share) {
    if (share == null || share < 0 || share > 100) return null;
    return MarketDominance(share: share, verdict: verdictFor(share));
  }

  /// Applies the threshold matrix.
  static DominanceVerdict verdictFor(double share) {
    if (share >= highThreshold) return DominanceVerdict.high;
    if (share >= lowThreshold) return DominanceVerdict.stable;
    return DominanceVerdict.low;
  }
}
