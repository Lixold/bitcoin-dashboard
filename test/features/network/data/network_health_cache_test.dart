import 'dart:io';

import 'package:bitcoin_dashboard/features/network/data/network_health_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late NetworkHealthCache cache;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_cdn_cache_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(NetworkHealthCache.boxName);
    cache = NetworkHealthCache();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('an empty cache reads as null rather than throwing', () async {
    expect(await cache.read(), isNull);
  });

  test('stores a payload with the time the app fetched it', () async {
    final now = DateTime.utc(2026, 9, 6, 12);
    await cache.write(const {
      '_meta': {'fetchedAt': '2026-09-06T01:00:32+00:00'},
      'miningPools': <dynamic>[],
    }, now);

    final cached = await cache.read();
    expect(cached, isNotNull);
    expect(cached!.cachedAt, now);
    // The producer's timestamp survives untouched inside the envelope —
    // the two ages answer different questions and must not be conflated.
    expect(
      (cached.payload['_meta'] as Map<String, dynamic>)['fetchedAt'],
      '2026-09-06T01:00:32+00:00',
    );
  });

  test('a second write replaces the first', () async {
    await cache.write(const {'generation': 1}, DateTime.utc(2026, 9, 6, 10));
    await cache.write(const {'generation': 2}, DateTime.utc(2026, 9, 6, 11));

    final cached = await cache.read();
    expect(cached!.payload['generation'], 2);
    expect(cached.cachedAt, DateTime.utc(2026, 9, 6, 11));
  });

  test('a corrupt entry reads as absent, not as an error', () async {
    // A cache is there to protect the screen; it must never be the thing
    // that breaks it. The caller's remedy for "missing" and "unreadable"
    // is the same fetch either way.
    await Hive.box<String>(
      NetworkHealthCache.boxName,
    ).put('network-health', 'not json at all');

    expect(await cache.read(), isNull);
  });

  test('an envelope without a timestamp reads as absent', () async {
    await Hive.box<String>(
      NetworkHealthCache.boxName,
    ).put('network-health', '{"payload":{"miningPools":[]}}');

    expect(await cache.read(), isNull);
  });

  test('stores UTC even when the caller passes a local timestamp', () async {
    final localNow = DateTime.utc(2026, 9, 6, 12).toLocal();
    await cache.write(const {'generation': 1}, localNow);

    final cached = await cache.read();
    expect(cached!.cachedAt.isUtc, isTrue);
    expect(cached.cachedAt, DateTime.utc(2026, 9, 6, 12));
  });
}
