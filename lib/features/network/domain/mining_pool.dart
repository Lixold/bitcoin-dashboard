/// One mining pool's share of the hashrate observed over the sample the
/// data source reports on.
///
/// **Three fields of the payload are deliberately not read here.** Each
/// pool entry also carries `blockCount`, every entry carries an `alert`
/// boolean, and the document carries a top-level `poolConcentrationAlert`.
/// The two flags encode the older single-pool-over-40-% rule from F04.4;
/// this slice derives its verdict client-side from the top-one and
/// top-three shares instead (issue #68), so consuming them would put two
/// disagreeing rules on the same screen. `blockCount` is simply not part
/// of the evidence this statement offers.
///
/// They are not forgotten fields. Wiring any of them up is a change to
/// what the statement claims, not a cleanup.
class MiningPool {
  const MiningPool({required this.name, required this.hashratePercent});

  /// Reads one entry of `miningPools[]`.
  ///
  /// `hashratePercent` arrives as a JSON number and is read through [num]
  /// rather than cast to [double]: a pool that happens to sit on a whole
  /// percent is serialised as `5`, not `5.0`, and a direct cast would
  /// throw on exactly those entries.
  factory MiningPool.fromJson(Map<String, dynamic> json) {
    return MiningPool(
      name: json['name'] as String,
      hashratePercent: (json['hashratePercent'] as num).toDouble(),
    );
  }

  /// Pool name as the data source spells it, e.g. `Foundry USA`.
  final String name;

  /// Share of the observed hashrate, in percent (`22.37` means 22.37 %).
  final double hashratePercent;
}
