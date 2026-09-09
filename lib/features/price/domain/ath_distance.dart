/// How the distance to the all-time high reads.
///
/// Four levels, not three. [atOrAbove] is not a decoration of [near]: the
/// published high is up to fifteen minutes old, so a live price can stand
/// above it, and every sentence the other three levels use — "the price
/// is n % below the high" — is then false. A level with no sentence of
/// its own would print that falsehood.
enum AthVerdict { atOrAbove, near, correction, deep }

/// The distance between the live price and the highest price ever
/// recorded, as a verdict the screen can state in words.
///
/// The two figures come from different places on purpose: the high from
/// the fifteen-minute CDN payload, the price from the live socket. That
/// is what makes [atOrAbove] reachable, and it is also why this class
/// takes both rather than reading either.
class AthDistance {
  const AthDistance({
    required this.percentBelow,
    required this.percentOfHigh,
    required this.verdict,
  });

  /// Threshold matrix from issue #30, as two named numbers.
  ///
  /// **Both bounds belong to the level above them.** A price exactly
  /// 10.0 % below the high is already a correction, one exactly 35.0 %
  /// below is already a deep one — the design writes the upper level as
  /// "from {threshold} %". [verdictFor] is tested on both boundaries.
  static const double nearThreshold = 10;
  static const double deepThreshold = 35;

  /// How far under the high the price stands, in percent. Zero when the
  /// price is at or above it — never negative, because "−2 % below the
  /// high" is a sentence no reader should have to invert.
  final double percentBelow;

  /// What the price is as a share of the high, in percent. The meter's
  /// fill: 100 % is the high, not a target.
  final double percentOfHigh;

  final AthVerdict verdict;

  /// Derives the distance, or returns `null` when either figure is
  /// missing or the high is not a usable reference.
  ///
  /// A high of zero or less is not a payload this app corrects for — it
  /// would make every percentage a division by nothing. The statement
  /// falls away instead, the same as for an absent field.
  static AthDistance? from({required double? high, required double? price}) {
    if (high == null || price == null || high <= 0) return null;

    final share = price / high * 100;
    final below = (100 - share).clamp(0.0, double.infinity);

    return AthDistance(
      percentBelow: below,
      percentOfHigh: share,
      verdict: verdictFor(percentBelow: below, isAtOrAbove: price >= high),
    );
  }

  /// Applies the threshold matrix.
  static AthVerdict verdictFor({
    required double percentBelow,
    required bool isAtOrAbove,
  }) {
    if (isAtOrAbove) return AthVerdict.atOrAbove;
    if (percentBelow >= deepThreshold) return AthVerdict.deep;
    if (percentBelow >= nearThreshold) return AthVerdict.correction;
    return AthVerdict.near;
  }
}
