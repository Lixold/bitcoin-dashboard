import '../../../core/bands/band_scale.dart';
import 'difficulty_direction.dart';

/// Blocks between two difficulty adjustments.
const int blocksPerRetargetPeriod = 2016;

/// The block time the difficulty is tuned towards.
const Duration targetBlockTime = Duration(minutes: 10);

/// One reading of `GET /api/v1/difficulty-adjustment` on mempool.space
/// (#46, ADR-0005).
///
/// Consumes exactly the five fields the statement reads.
/// `estimatedRetargetDate`, `nextRetargetHeight`, `previousRetarget` and
/// `previousTime` arrive too and are ignored on purpose, as are the
/// `adjustedTimeAvg`, `timeOffset` and `expectedBlocks` the endpoint added
/// after the contract was written: a field the screen does not state is a
/// field whose shape the app should not depend on.
class DifficultySnapshot {
  const DifficultySnapshot({
    required this.changePercent,
    required this.remaining,
    required this.progressPercent,
    required this.remainingBlocks,
    required this.averageBlockTime,
    required this.observedAt,
  });

  /// Parses the endpoint's body.
  ///
  /// **The time units are mixed in this payload, and this is the one
  /// place they are converted.** `remainingTime` and `timeAvg` are
  /// milliseconds; `previousTime` in the same object is seconds. Both
  /// consumed fields become a [Duration] here, so nothing above the model
  /// ever handles a bare millisecond count (#46, "the trap the payload
  /// does not advertise").
  ///
  /// Throws [FormatException] when a field is missing, not a finite
  /// number, or outside what the field can mean — a negative time, a
  /// block count beyond one period, a position outside 0–100. A half-
  /// parsed reading would put a countdown on screen that nobody published,
  /// so the whole reading fails and the screen shows its error state.
  factory DifficultySnapshot.fromJson(
    Map<String, dynamic> json, {
    required DateTime observedAt,
  }) {
    final remainingBlocks = _number(json, 'remainingBlocks');
    if (remainingBlocks != remainingBlocks.roundToDouble() ||
        remainingBlocks < 0 ||
        remainingBlocks > blocksPerRetargetPeriod) {
      throw const FormatException(
        'mempool.space: "remainingBlocks" is not a block count in one period',
      );
    }
    final progress = _number(json, 'progressPercent');
    if (progress < 0 || progress > 100) {
      throw const FormatException(
        'mempool.space: "progressPercent" is not within 0–100',
      );
    }
    return DifficultySnapshot(
      changePercent: _number(json, 'difficultyChange').toDouble(),
      remaining: _milliseconds(json, 'remainingTime'),
      progressPercent: progress.toDouble(),
      remainingBlocks: remainingBlocks.toInt(),
      averageBlockTime: _milliseconds(json, 'timeAvg'),
      observedAt: observedAt,
    );
  }

  /// The expected change at the next adjustment, in percent, signed.
  final double changePercent;

  /// How long until the adjustment, as mempool.space estimates it.
  ///
  /// Taken from `remainingTime`, not from `estimatedRetargetDate` minus
  /// the device clock, which can be wrong (decision 3 of #46).
  final Duration remaining;

  /// How far through the current 2,016-block period the network is.
  final double progressPercent;

  /// Blocks left until the adjustment.
  final int remainingBlocks;

  /// The average block time in this period so far.
  final Duration averageBlockTime;

  /// When this app received the reading. The endpoint carries no
  /// timestamp of its own.
  final DateTime observedAt;

  /// Blocks of this period already mined — what the estimate rests on.
  int get blocksMined => blocksPerRetargetPeriod - remainingBlocks;

  /// The change as the reader sees it: rounded to one decimal.
  ///
  /// The band is read on this value, not on the raw float, so the verdict
  /// can never contradict the figure beside it: a raw +0.03 % shows as
  /// "0.0" and therefore reads "easier", not "harder" next to "+0.0 %".
  double get shownChangePercent => (changePercent * 10).round() / 10;

  /// Which way the difficulty is expected to go.
  Band<DifficultyDirection> get direction =>
      difficultyDirectionScale.bandFor(shownChangePercent);

  static num _number(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num || value.isNaN || value.isInfinite) {
      throw FormatException('mempool.space: "$field" is not a number');
    }
    return value;
  }

  /// A millisecond field as a [Duration]. Sub-millisecond fractions are
  /// dropped; the payload sends whole milliseconds today.
  static Duration _milliseconds(Map<String, dynamic> json, String field) {
    final value = _number(json, field);
    if (value < 0) {
      throw FormatException('mempool.space: "$field" is negative');
    }
    return Duration(milliseconds: value.floor());
  }
}
