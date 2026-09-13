import '../widgets/statement.dart';

/// One band of a metric's scale: where it starts, what it is called, and
/// how a reading inside it should be taken.
///
/// **The tone belongs to the band, not to the widget that draws it.** It
/// is the band's meaning — "this reading is calm", "this one is extreme"
/// — and the screen only renders it. Leaving it out is what produced the
/// same three-part switch (tone, verdict word, badge word) in every
/// screen that states a threshold; #52 exists to end that.
///
/// [key] is an enum so the band can resolve its own localised label
/// through `AppL10n` — the convention is in CLAUDE.md §5. No band ever
/// carries display copy.
class Band<K extends Enum> {
  const Band(
    this.key, {
    required this.from,
    required this.tone,
    this.fromIsInclusive = true,
  });

  /// What this band is, as the metric's own enum value.
  final K key;

  /// Lower bound of the band. The upper bound is the next band's [from] —
  /// see [BandScale.upperBoundOf] — so a boundary is written once and two
  /// neighbouring bands can never disagree about where it lies.
  final double from;

  /// Whether a value landing exactly on [from] is already in this band.
  ///
  /// **Not a formality.** The existing threshold matrices are not
  /// symmetric: #30 writes its all-time-high levels as "from 10 %"
  /// (inclusive), #68 writes its top-one pool levels as "> 40 %"
  /// (exclusive) and its critical top-three line as "≥ 80 %" (inclusive)
  /// in the same matrix. A scale that could only express one of the two
  /// would move exactly one of those boundaries by a hair's breadth and
  /// silently reclassify the values sitting on it.
  final bool fromIsInclusive;

  /// How a reading inside this band should be taken.
  final StatementTone tone;

  /// Whether [value] has reached this band's lower bound.
  bool admits(double value) => fromIsInclusive ? value >= from : value > from;
}

/// The ordered set of bands a metric is read against — the declarative
/// form of what would otherwise be an `if` chain in a widget (#52).
///
/// ```dart
/// const scale = BandScale<SentimentBand>([
///   Band(SentimentBand.extremeFear, from: 0, tone: StatementTone.negative),
///   Band(SentimentBand.fear, from: 26, tone: StatementTone.warning),
///   // …
/// ]);
/// final band = scale.bandFor(61); // key, tone and bounds together
/// ```
///
/// **Ascending by [Band.from], and total.** The first band catches
/// everything below its own bound as well, so every finite value lands in
/// exactly one band and no caller has to handle "no band". The ordering
/// is an invariant this class documents rather than enforces — a const
/// constructor cannot walk its list — and the scale's own test asserts
/// it.
///
/// **The last band has no upper bound.** That is the honest shape: the
/// distance to the all-time high has no ceiling. Where a metric does have
/// one — the sentiment index runs 0–100 — the axis that draws it supplies
/// it, because a ceiling is a property of the scale being drawn, not of
/// the classification.
class BandScale<K extends Enum> {
  const BandScale(this.bands);

  /// The bands, lowest first.
  final List<Band<K>> bands;

  /// The band [value] falls into.
  ///
  /// Walks from the top so that the first band whose bound is reached
  /// wins, which is also why a value below the lowest bound comes back as
  /// the lowest band rather than as an error.
  Band<K> bandFor(double value) {
    for (var i = bands.length - 1; i > 0; i--) {
      if (bands[i].admits(value)) return bands[i];
    }
    return bands.first;
  }

  /// Where [band] ends: the next band's [Band.from], or `null` for the
  /// last band, which is unbounded.
  double? upperBoundOf(Band<K> band) {
    final next = bands.indexOf(band) + 1;
    return next > 0 && next < bands.length ? bands[next].from : null;
  }

  /// The interior boundaries, in ascending order — every band's lower
  /// bound except the first, which is where the scale starts rather than
  /// a line a reading crosses.
  ///
  /// This is what a meter marks with ticks and what a chart draws as
  /// dividing lines: the four numbers at which the verdict changes.
  List<double> get boundaries => [for (final band in bands.skip(1)) band.from];
}
