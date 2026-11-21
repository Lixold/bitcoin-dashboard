import '../../../core/bands/band_scale.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Which way the next difficulty adjustment is expected to go (#46).
///
/// Two levels and no magnitude: "slightly" or "sharply" would be a
/// threshold nobody has decided (decision 1 of #46). The key resolves its
/// own words through `AppL10n` — verdict, sentence, reason — so no screen
/// assembles them (CLAUDE.md §5).
enum DifficultyDirection {
  easier,
  harder;

  /// The one-word verdict: what the change does to mining.
  String label(AppL10n l10n) => switch (this) {
    DifficultyDirection.easier => l10n.difficultyDirectionEasier,
    DifficultyDirection.harder => l10n.difficultyDirectionHarder,
  };

  /// The statement's sentence: when, which way, by how much, and what it
  /// means for mining.
  ///
  /// [remaining] is the already-worded time ("5 days"), [change] the
  /// size of the change without its sign — the sentence says the
  /// direction in words. One whole sentence per direction rather than a
  /// shared frame with the verb dropped in, so each locale keeps its own
  /// word order.
  String insight(AppL10n l10n, String remaining, String change) =>
      switch (this) {
        DifficultyDirection.easier => l10n.difficultyInsightEasier(
          remaining,
          change,
        ),
        DifficultyDirection.harder => l10n.difficultyInsightHarder(
          remaining,
          change,
        ),
      };

  /// Why the difficulty moves this way: the block time against the
  /// ten-minute target. Read beside the average block time in the
  /// evidence slot.
  ///
  /// Keyed to the direction, not computed from the block time a second
  /// time: mempool.space derives `difficultyChange` from the same blocks,
  /// and two verdicts from two derivations could disagree at the edge.
  String reason(AppL10n l10n) => switch (this) {
    DifficultyDirection.easier => l10n.difficultyReasonEasier,
    DifficultyDirection.harder => l10n.difficultyReasonHarder,
  };
}

/// The two directions, read on `difficultyChange` in percent.
///
/// The boundary is 0 and **exclusive for "harder"**: a change above zero
/// makes mining harder, anything at or below zero reads as easier. An
/// exact 0 is a float that practically never arrives; it falls on the
/// "easier" side because "harder" is a claim that needs a rise behind it.
///
/// Both tones are neutral (decision 2 of #46). A rising difficulty means
/// more hashrate and harder mining for every miner; a falling one the
/// opposite. Neither is good or bad in itself, so the statement says
/// which and does not colour it.
const BandScale<DifficultyDirection> difficultyDirectionScale =
    BandScale<DifficultyDirection>(<Band<DifficultyDirection>>[
      Band(DifficultyDirection.easier, from: 0, tone: StatementTone.neutral),
      Band(
        DifficultyDirection.harder,
        from: 0,
        fromIsInclusive: false,
        tone: StatementTone.neutral,
      ),
    ]);
