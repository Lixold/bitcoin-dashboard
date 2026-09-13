import '../../../core/bands/band_scale.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The five bands the Fear & Greed index is read in.
///
/// The band is derived from the numeric value, never from the payload's
/// own `value_classification`: that field is upstream editorial copy, it
/// is English only, and alternative.me can reword it without warning. The
/// number is the contract, the band is ours, and the key below is what
/// resolves the localised word.
enum SentimentBand {
  extremeFear,
  fear,
  neutral,
  greed,
  extremeGreed;

  /// The band's own word — the verdict the screen states.
  String label(AppL10n l10n) => switch (this) {
    SentimentBand.extremeFear => l10n.marketSentimentBandExtremeFear,
    SentimentBand.fear => l10n.marketSentimentBandFear,
    SentimentBand.neutral => l10n.marketSentimentBandNeutral,
    SentimentBand.greed => l10n.marketSentimentBandGreed,
    SentimentBand.extremeGreed => l10n.marketSentimentBandExtremeGreed,
  };

  /// What being in this band says about the market — the first half of
  /// the insight sentence.
  ///
  /// A statement about the market's own pricing, never a suggestion to
  /// the reader: "the market is slightly overbought", not "consider
  /// selling". The separation is the one CLAUDE.md §1 and the MiCAR line
  /// require, and it is why the claim is a translated string per band
  /// rather than a sentence assembled in a widget.
  String claim(AppL10n l10n) => switch (this) {
    SentimentBand.extremeFear => l10n.marketSentimentClaimExtremeFear,
    SentimentBand.fear => l10n.marketSentimentClaimFear,
    SentimentBand.neutral => l10n.marketSentimentClaimNeutral,
    SentimentBand.greed => l10n.marketSentimentClaimGreed,
    SentimentBand.extremeGreed => l10n.marketSentimentClaimExtremeGreed,
  };
}

/// Where the five bands lie on the 0–100 scale, and how each one reads.
///
/// **The boundaries are measured, not quoted.** They come from the full
/// published history — 3143 daily values — rather than from the numbers
/// the API's own classification implies, and they are half-open: 26 is
/// already fear, 47 is already neutral, 55 is already greed, 76 is
/// already extreme greed.
///
/// **The tone is the deviation from the middle, not a direction.** Fear
/// and greed carry the same `warning`, both extremes the same `negative`,
/// and the calm middle is the `positive` one. Neither fear nor greed is a
/// buying signal, and a scale that made one of them green and the other
/// red would say so in colour while the words said otherwise.
const BandScale<SentimentBand> sentimentScale =
    BandScale<SentimentBand>(<Band<SentimentBand>>[
      Band(SentimentBand.extremeFear, from: 0, tone: StatementTone.negative),
      Band(SentimentBand.fear, from: 26, tone: StatementTone.warning),
      Band(SentimentBand.neutral, from: 47, tone: StatementTone.positive),
      Band(SentimentBand.greed, from: 55, tone: StatementTone.warning),
      Band(SentimentBand.extremeGreed, from: 76, tone: StatementTone.negative),
    ]);

/// Both ends of the scale the index is quoted on.
///
/// No value below 5 or above 95 has ever been published, but the index is
/// defined on 0–100 and the meter draws it whole: a bar that started at
/// the lowest value ever seen would make every reading look more extreme
/// than it is.
const double sentimentScaleMin = 0;
const double sentimentScaleMax = 100;
