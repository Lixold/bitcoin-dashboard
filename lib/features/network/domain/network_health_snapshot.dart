import 'mining_pool.dart';

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

/// The part of `network-health.json` this slice reads: when the producer
/// gathered the data, and the pool shares it found.
///
/// `fullNodes` and `aggregatedHealth` are in the payload and belong to
/// #34; they are not parsed here.
class NetworkHealthSnapshot {
  const NetworkHealthSnapshot({required this.fetchedAt, required this.pools});

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

    return NetworkHealthSnapshot(
      // The producer writes an explicit `+00:00` offset, so the parse
      // already yields UTC. `toUtc()` makes that independent of the
      // serialisation: an offset the producer changes must not silently
      // shift every age this screen reports.
      fetchedAt: DateTime.parse(fetchedAt).toUtc(),
      pools: List.unmodifiable(
        pools.map((pool) => MiningPool.fromJson(pool as Map<String, dynamic>)),
      ),
    );
  }

  /// `_meta.fetchedAt` — when the producer read its sources, not when the
  /// app fetched the file.
  final DateTime fetchedAt;

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
