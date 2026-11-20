import '../../../core/bands/band_scale.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';

/// How much is waiting in the mempool, read in blocks' worth (#112).
///
/// The key resolves its own words through `AppL10n` — the verdict, the
/// insight sentence — so no screen assembles them (CLAUDE.md §5).
enum MempoolLoad {
  calm,
  normal,
  busy,
  congested;

  /// The band's one-word verdict.
  String label(AppL10n l10n) => switch (this) {
    MempoolLoad.calm => l10n.mempoolLoadCalm,
    MempoolLoad.normal => l10n.mempoolLoadNormal,
    MempoolLoad.busy => l10n.mempoolLoadBusy,
    MempoolLoad.congested => l10n.mempoolLoadCongested,
  };

  /// The statement's sentence: the load, then what an hour costs.
  ///
  /// One whole sentence per band rather than the band word dropped into a
  /// shared frame. German declines and capitalises differently from
  /// English, and a frame with a hole for the adjective would put that
  /// grammar in a widget.
  String insight(AppL10n l10n, String hourFee) => switch (this) {
    MempoolLoad.calm => l10n.mempoolInsightCalm(hourFee),
    MempoolLoad.normal => l10n.mempoolInsightNormal(hourFee),
    MempoolLoad.busy => l10n.mempoolInsightBusy(hourFee),
    MempoolLoad.congested => l10n.mempoolInsightCongested(hourFee),
  };
}

/// Virtual bytes one block holds, near enough: the unit "blocks' worth"
/// is counted in.
///
/// A block's limit is four million weight units, which is one million
/// virtual bytes. Real blocks land a little under it, so the figure is a
/// count of how many full blocks the queue would take to clear if nothing
/// new arrived — not a promise of when it will.
const double vbytesPerBlock = 1000000;

/// The four bands, in blocks' worth waiting. Every lower bound is
/// inclusive: 10 is already normal, 30 already busy, 45 already
/// congested.
///
/// **The boundaries follow the measured distribution, not the clock.**
/// They were proposed in #112 against twelve months of mempool.space
/// statistics (1,096 samples: p10 16, median 36, p90 45, maximum 58) and
/// approved with the design. Over those twelve months the bands hold 4,
/// 33, 54 and 8 % of the samples.
///
/// Bands anchored in time — one block, an hour, a day — were measured
/// first and rejected: 98–100 % of all samples fall into the same one,
/// because almost all of the waiting volume pays the lowest fee tier and
/// sits there for days. That is also why the load is a statement about
/// the size of the queue, and the fee sentence beside it says what it
/// costs to get ahead of it.
///
/// Tone: a calm and a normal queue are both fine, a busy one is a
/// warning, a congested one is negative — decision 3 of #112.
const BandScale<MempoolLoad> mempoolLoadScale =
    BandScale<MempoolLoad>(<Band<MempoolLoad>>[
      Band(MempoolLoad.calm, from: 0, tone: StatementTone.positive),
      Band(MempoolLoad.normal, from: 10, tone: StatementTone.positive),
      Band(MempoolLoad.busy, from: 30, tone: StatementTone.warning),
      Band(MempoolLoad.congested, from: 45, tone: StatementTone.negative),
    ]);

/// Where the load meter's track ends, in blocks' worth.
///
/// A third above the congested line and just above the twelve-month
/// maximum of 58, so every reading of the last year lands on the track and
/// the last band keeps a visible width. A reading past it fills the track
/// and is labelled by its own figure, which is never clamped.
const double mempoolLoadMeterMax = 60;
