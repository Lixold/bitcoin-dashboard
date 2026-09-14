import 'mining_pool.dart';
import 'node_count.dart';

/// Age at which a `network-health.json` payload counts as stale.
///
/// `cron-network-stats` writes once a day at 01:00 UTC, so 26 hours is
/// one certainly-missed run plus two hours of slack for a late job — long
/// enough that a punctual producer never trips it, short enough that a
/// silently dead worker shows up within a day.
///
/// **Stale is a state of the data, not a failure of the fetch.** Values
/// past this age stay on screen with an age hint; they are never replaced
/// by the error state.
///
/// This is the single place the number is written down. It is deliberately
/// not a global constant: the 45-minute threshold from #30 belongs to the
/// 15-minute payloads, and #52 replaces both by deriving the threshold
/// from each producer's cadence.
const Duration stalePayloadAge = Duration(hours: 26);

/// `network-health.json` as the two statements on the network screen
/// read it: when the producer gathered the data, which sources it named,
/// how many full nodes it counted, and the pool shares it found.
///
/// One document, one fetch, one staleness threshold — which is why the
/// age hint, the error and the loading state belong to the section
/// rather than to either statement.
class NetworkHealthSnapshot {
  const NetworkHealthSnapshot({
    required this.fetchedAt,
    required this.sources,
    required this.fullNodes,
    required this.aggregatedHealth,
    required this.pools,
  });

  /// Reads the document published at `data/network-health.json`.
  factory NetworkHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final meta = json['_meta'] as Map<String, dynamic>?;
    final fetchedAt = meta?['fetchedAt'] as String?;
    if (fetchedAt == null) {
      throw const FormatException(
        'network-health.json is missing _meta.fetchedAt',
      );
    }

    final pools = json['miningPools'] as List<dynamic>?;
    if (pools == null) {
      throw const FormatException('network-health.json is missing miningPools');
    }

    final nodes = json['fullNodes'] as Map<String, dynamic>?;

    return NetworkHealthSnapshot(
      // The producer writes an explicit `+00:00` offset, so the parse
      // already yields UTC. `toUtc()` makes that independent of the
      // serialisation: an offset the producer changes must not silently
      // shift every age this screen reports.
      fetchedAt: DateTime.parse(fetchedAt).toUtc(),
      sources: List.unmodifiable(
        (meta?['sources'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>(),
      ),
      // The producer writes the object even when it has nothing to put
      // in it, so a missing one is a payload this app has never seen —
      // treated as "no count", not as a broken document.
      fullNodes: nodes == null ? null : NodeCount.from(nodes),
      aggregatedHealth: json['aggregatedHealth'] as String?,
      pools: List.unmodifiable(
        pools.map((pool) => MiningPool.fromJson(pool as Map<String, dynamic>)),
      ),
    );
  }

  /// `_meta.fetchedAt` — when the producer read its sources, not when the
  /// app fetched the file.
  final DateTime fetchedAt;

  /// `_meta.sources` — the names the producer read, in payload order.
  ///
  /// This is the evidence the node statement offers: who says so. The
  /// names travel as the producer spells them; the app neither maps them
  /// to URLs nor translates them.
  final List<String> sources;

  /// `fullNodes`, or `null` when the producer had no count — see
  /// `NodeCount.from`.
  final NodeCount? fullNodes;

  /// `aggregatedHealth` — the producer's verdict over both dimensions.
  ///
  /// **Held, never rendered.** `good / warning / critical` would be a
  /// third judgement next to two statements that already make their own,
  /// and the worker judges pool concentration on a different matrix than
  /// this app does (it warns from 30 %, `PoolConcentration` from 40 %),
  /// so the two would disagree in public from 30 % upwards.
  ///
  /// It is not the trigger for the missing-comparison hint either, and
  /// that is measured rather than assumed: `aggregateHealth()` returns
  /// `unknown` as soon as **either** dimension is missing, so a failed
  /// pool source with an intact node count reads `unknown` while the
  /// 24 h comparison is present — and a missing node comparison next to
  /// a pool share over its line reads `warning`, not `unknown`. The
  /// coupling fails in both directions; the hint hangs on
  /// `NodeCount.hasChange`.
  final String? aggregatedHealth;

  /// `miningPools[]` in payload order. Sorting happens where the
  /// statement is derived, in `PoolConcentration.from`.
  final List<MiningPool> pools;

  /// Whether the payload is older than [stalePayloadAge] at [now].
  ///
  /// "Older than" is strict: a payload of exactly 26 hours is not yet
  /// stale. Takes [now] rather than reading the clock so the boundary is
  /// testable and so the screen can re-evaluate it on a rebuild.
  bool isStaleAt(DateTime now) =>
      now.toUtc().difference(fetchedAt) > stalePayloadAge;
}
