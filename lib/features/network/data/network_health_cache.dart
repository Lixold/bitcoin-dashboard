import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A payload as it was last stored, with the moment the app stored it.
///
/// [cachedAt] is the app's own fetch time and answers "may I skip the
/// network call". It is not the producer's `_meta.fetchedAt`, which
/// answers "is what I am showing still current" — the two ages are
/// independent and are never substituted for one another.
class CachedPayload {
  const CachedPayload({required this.cachedAt, required this.payload});

  final DateTime cachedAt;
  final Map<String, dynamic> payload;
}

/// On-device copy of the last `network-health.json` the app fetched.
///
/// Two jobs, both of them offline-first:
///
///  * inside [ttl] the cached copy is served without touching the network;
///  * when a fetch fails, the cached copy is served at any age, so a
///    reader on a train sees yesterday's shares with an age hint rather
///    than an error.
///
/// Nothing personal is written here — the file is the same world-readable
/// document the CDN serves everyone.
class NetworkHealthCache {
  NetworkHealthCache();

  /// Hive box for cached CDN documents. Versioned in the name so a
  /// payload change can retire the old copies by opening a new box.
  static const String boxName = 'cdn_cache_v1';

  static const String _key = 'network-health';

  /// How long a stored copy is reused before the CDN is asked again.
  ///
  /// The producer writes once a day and the CDN answers with
  /// `max-age=86400`; a shorter cycle would spend battery to receive the
  /// identical document. It is not the staleness threshold — that one
  /// lives with the snapshot and is six times longer.
  static const Duration ttl = Duration(minutes: 60);

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  /// The stored copy, or `null` when there is none or it cannot be read.
  ///
  /// A corrupt or half-written entry is treated as absent rather than
  /// raised: the caller's remedy for both is the same — fetch — and a
  /// cache must not be able to break the screen it exists to protect.
  Future<CachedPayload?> read() async {
    final raw = (await _box()).get(_key);
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
    await (await _box()).put(_key, envelope);
  }
}

final networkHealthCacheProvider = Provider<NetworkHealthCache>((ref) {
  return NetworkHealthCache();
});
