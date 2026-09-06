import 'mining_pool.dart';

/// How concentrated the mining hashrate is, as a verdict the screen can
/// state in words.
///
/// Three levels, not two: the difference between "one pool is getting
/// large" and "one pool could decide block order on its own" is the whole
/// point of the statement, and collapsing them would leave the reader
/// with a warning that never escalates.
enum ConcentrationVerdict { ok, warning, critical }

/// The concentration statement's subject: who the largest pool is, how
/// much the three largest hold together, and what that means.
///
/// Both figures are derived in the client from `miningPools[]` — see
/// [MiningPool] for the payload flags this deliberately ignores.
class PoolConcentration {
  const PoolConcentration({
    required this.pools,
    required this.topPoolName,
    required this.topPoolShare,
    required this.topThreeShare,
    required this.listedShare,
    required this.verdict,
  });

  /// Threshold matrix from issue #68, as five named numbers.
  ///
  /// **The comparisons are not symmetric and that is intentional.** Every
  /// bound is exclusive except the critical top-three line, which the
  /// issue writes as `Top 3 ≥ 80 %`. A pool set landing on exactly 80.0
  /// is therefore critical, while one landing on exactly 70.0, 40.0 or
  /// 50.0 is not yet at the next level. Do not "harmonise" these
  /// operators — [verdictFor] is tested on each of the four boundaries.
  static const double topOneWarningThreshold = 40;
  static const double topOneCriticalThreshold = 50;
  static const double topThreeWarningThreshold = 70;
  static const double topThreeCriticalThreshold = 80;

  /// Fewest pools from which the statement can be formed.
  ///
  /// Below this the top-three figure does not exist, and there is no
  /// substitute for it: summing whatever is present would answer a
  /// different question than the one the sentence asks. The screen
  /// renders its empty state instead.
  static const int minimumPools = 3;

  /// All pools the payload listed, sorted by share, largest first.
  final List<MiningPool> pools;

  /// Name of the largest pool — the statement names it, so it travels
  /// with its figure rather than being looked up again in the widget.
  final String topPoolName;

  /// Share of the largest pool, in percent.
  final double topPoolShare;

  /// Combined share of the three largest pools, in percent.
  final double topThreeShare;

  /// Combined share of *every* listed pool, in percent.
  ///
  /// This is what the list covers, not a total: the source's ten entries
  /// added up to 97.37 % on 2026-09-06 and the remainder is attributed to
  /// no pool at all. It exists so the screen can say what the list covers
  /// instead of letting the reader assume it sums to 100. The difference
  /// to 100 is **not** an "Others" pool and must never be rendered as
  /// one — there is no such entry in the payload and no source for it.
  final double listedShare;

  /// The verdict for [topPoolShare] and [topThreeShare].
  final ConcentrationVerdict verdict;

  /// Derives the statement from [pools], or returns `null` when fewer
  /// than [minimumPools] were listed.
  ///
  /// Sorts defensively. The payload arrives largest-first today, but that
  /// ordering is not part of the contract in ADR-0005, and a statement
  /// that names "the largest pool" must not depend on a producer's
  /// incidental sort order. Ties break by name so the same payload always
  /// produces the same statement.
  static PoolConcentration? from(List<MiningPool> pools) {
    if (pools.length < minimumPools) return null;

    final sorted = sortedByShare(pools);
    final topThreeShare = sorted
        .take(minimumPools)
        .fold<double>(0, (sum, pool) => sum + pool.hashratePercent);
    final listedShare = sorted.fold<double>(
      0,
      (sum, pool) => sum + pool.hashratePercent,
    );

    return PoolConcentration(
      pools: sorted,
      topPoolName: sorted.first.name,
      topPoolShare: sorted.first.hashratePercent,
      topThreeShare: topThreeShare,
      listedShare: listedShare,
      verdict: verdictFor(
        topOneShare: sorted.first.hashratePercent,
        topThreeShare: topThreeShare,
      ),
    );
  }

  /// [pools] ordered largest share first, ties broken by name.
  ///
  /// Public because the empty state needs it too: with fewer than
  /// [minimumPools] entries there is no [PoolConcentration] to ask, but
  /// the screen still names the largest pool it did receive. Sorting it a
  /// second time in the widget would be a second definition of "largest".
  static List<MiningPool> sortedByShare(List<MiningPool> pools) {
    return List.unmodifiable(
      // Typed literal on purpose: `List.unmodifiable` takes an untyped
      // `Iterable`, so an inferred literal would make the comparator's
      // arguments dynamic and its result unanalysable.
      <MiningPool>[...pools]..sort((a, b) {
        final byShare = b.hashratePercent.compareTo(a.hashratePercent);
        return byShare != 0 ? byShare : a.name.compareTo(b.name);
      }),
    );
  }

  /// Applies the threshold matrix.
  ///
  /// Critical is checked before warning: a set that trips both lines is
  /// the more serious of the two, and the matrix lists the critical rows
  /// last precisely because they override.
  static ConcentrationVerdict verdictFor({
    required double topOneShare,
    required double topThreeShare,
  }) {
    if (topOneShare > topOneCriticalThreshold ||
        topThreeShare >= topThreeCriticalThreshold) {
      return ConcentrationVerdict.critical;
    }
    if (topOneShare > topOneWarningThreshold ||
        topThreeShare > topThreeWarningThreshold) {
      return ConcentrationVerdict.warning;
    }
    return ConcentrationVerdict.ok;
  }
}
