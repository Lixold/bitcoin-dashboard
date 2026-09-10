import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// A payload as it was last stored, with the moment the app stored it.
///
/// [cachedAt] is the app's own fetch time and answers "may I skip the
/// network call". It is not the producer's `fetchedAt`, which answers "is
/// what I am showing still current" — the two ages are independent and
/// are never substituted for one another.
class CachedPayload {
  const CachedPayload({required this.cachedAt, required this.payload});

  final DateTime cachedAt;
  final Map<String, dynamic> payload;
}

/// On-device copy of one document the CDN publishes.
///
/// Two jobs, both of them offline-first:
///
///  * inside [ttl] the cached copy is served without touching the network;
///  * when a fetch fails, the cached copy is served at any age, so a
///    reader on a train sees yesterday's figures with an age hint rather
///    than an error.
///
/// Nothing personal is written here — the files are the same
/// world-readable documents the CDN serves everyone.
///
/// **[key] and [ttl] are per document, the box is not.** Every cached
/// document shares one Hive box and is told apart by its key, so adding
/// the next CDN-backed slice costs a constructor call rather than another
/// box to open, migrate and close. The TTL belongs to the document
/// because it follows that document's producer: `network-health.json` is
/// written once a day, `market.json` every fifteen minutes, and a single
/// number for both would either waste requests on the one or serve the
/// other stale.
class CdnCache {
  const CdnCache({required this.key, required this.ttl});

  /// Hive box for cached CDN documents. Versioned in the name so a
  /// payload change can retire the old copies by opening a new box.
  static const String boxName = 'cdn_cache_v1';

  /// Entry name inside [boxName]. One per published document.
  final String key;

  /// How long a stored copy is reused before the CDN is asked again.
  ///
  /// It is not the staleness threshold. That one asks whether the
  /// *producer* is still current and lives with the document's snapshot;
  /// this one only asks whether the app may skip a request.
  final Duration ttl;

  /// The stored copy, or `null` when there is none or it cannot be read.
  ///
  /// A corrupt or half-written entry is treated as absent rather than
  /// raised: the caller's remedy for both is the same — fetch — and a
  /// cache must not be able to break the screen it exists to protect.
  Future<CachedPayload?> read() async {
    final raw = (await _box()).get(key);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      return CachedPayload(
        cachedAt: DateTime.parse(envelope['cachedAt'] as String).toUtc(),
        payload: envelope['payload'] as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  /// Replaces the stored copy with [payload], stamped [now].
  ///
  /// Written as one envelope rather than two keys so a cached document
  /// can never end up carrying another document's timestamp.
  Future<void> write(Map<String, dynamic> payload, DateTime now) async {
    final envelope = jsonEncode({
      'cachedAt': now.toUtc().toIso8601String(),
      'payload': payload,
    });
    await (await _box()).put(key, envelope);
  }

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }
}
