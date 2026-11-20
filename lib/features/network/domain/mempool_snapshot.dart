import '../../../core/bands/band_scale.dart';
import 'mempool_load.dart';

/// One reading of the mempool and the fee estimates beside it, taken from
/// two mempool.space endpoints in the same fetch (#112, ADR-0005).
///
/// Consumes exactly the five fields the statement reads. `total_fee`,
/// `fee_histogram`, `halfHourFee` and `minimumFee` arrive too and are
/// ignored on purpose: a field the screen does not state is a field whose
/// shape the app should not depend on.
class MempoolSnapshot {
  const MempoolSnapshot({
    required this.count,
    required this.vsize,
    required this.fastestFee,
    required this.hourFee,
    required this.economyFee,
    required this.observedAt,
  });

  /// Parses `GET /api/mempool` and `GET /api/v1/fees/recommended`.
  ///
  /// Throws [FormatException] when a field is missing, not a number, or
  /// negative. A half-parsed reading would put a fee estimate on screen
  /// that nobody published, so the whole reading fails and the screen
  /// shows its error state instead.
  ///
  /// Fees are read as numbers, not integers. The endpoint returns whole
  /// sat/vB today, but sub-satoshi fee rates are valid and mempool.space
  /// already reports them in its histogram; a parser that insisted on
  /// `int` would turn the first fractional estimate into an outage.
  factory MempoolSnapshot.fromJson({
    required Map<String, dynamic> mempool,
    required Map<String, dynamic> fees,
    required DateTime observedAt,
  }) {
    return MempoolSnapshot(
      count: _number(mempool, 'count').toInt(),
      vsize: _number(mempool, 'vsize').toDouble(),
      fastestFee: _number(fees, 'fastestFee').toDouble(),
      hourFee: _number(fees, 'hourFee').toDouble(),
      economyFee: _number(fees, 'economyFee').toDouble(),
      observedAt: observedAt,
    );
  }

  /// Transactions waiting.
  final int count;

  /// Their combined size, in virtual bytes.
  final double vsize;

  /// sat/vB for the next block.
  final double fastestFee;

  /// sat/vB for confirmation within about an hour — the figure the
  /// sentence names.
  final double hourFee;

  /// sat/vB with no time promise: what a transaction pays to be mined
  /// eventually, when the queue thins out.
  final double economyFee;

  /// When this app received the reading. Neither endpoint carries a
  /// timestamp of its own.
  final DateTime observedAt;

  /// The queue in blocks' worth — what the load band is read on.
  double get blocksWorth => vsize / vbytesPerBlock;

  /// The band the queue is in.
  Band<MempoolLoad> get load => mempoolLoadScale.bandFor(blocksWorth);

  static num _number(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num || value.isNaN || value.isInfinite || value < 0) {
      throw FormatException('mempool.space: "$field" is not a number ≥ 0');
    }
    return value;
  }
}
