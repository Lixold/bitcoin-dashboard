import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

/// A payload shaped like the live document of 2026-09-06, trimmed to the
/// two fields this slice reads plus the ones it deliberately ignores.
Map<String, dynamic> _payload({
  String fetchedAt = '2026-09-06T01:00:32+00:00',
}) {
  return <String, dynamic>{
    '_meta': {
      'fetchedAt': fetchedAt,
      'date': '2026-09-06',
      'sources': ['Bitnodes.io', 'Mempool.space'],
    },
    'fullNodes': {'count': 26748, 'percentChange24h': null, 'trend': 'unknown'},
    'miningPools': [
      {
        'name': 'Foundry USA',
        'hashratePercent': 22.37,
        'blockCount': 34,
        'alert': false,
      },
      {
        'name': 'AntPool',
        'hashratePercent': 18.42,
        'blockCount': 28,
        'alert': false,
      },
      {
        'name': 'F2Pool',
        'hashratePercent': 17.11,
        'blockCount': 26,
        'alert': false,
      },
    ],
    'poolConcentrationAlert': false,
    'aggregatedHealth': 'good',
  };
}

void main() {
  group('fromJson', () {
    test('reads _meta.fetchedAt as UTC and every listed pool', () {
      final snapshot = NetworkHealthSnapshot.fromJson(_payload());

      expect(snapshot.fetchedAt, DateTime.utc(2026, 9, 6, 1, 0, 32));
      expect(snapshot.fetchedAt.isUtc, isTrue);
      expect(snapshot.pools.length, 3);
      expect(snapshot.pools.first.name, 'Foundry USA');
      expect(snapshot.pools.first.hashratePercent, 22.37);
    });

    test('accepts a whole-percent share serialised as an int', () {
      final payload = _payload();
      (payload['miningPools'] as List<dynamic>)[0] = {
        'name': 'Foundry USA',
        'hashratePercent': 22,
        'blockCount': 34,
        'alert': false,
      };

      final snapshot = NetworkHealthSnapshot.fromJson(payload);
      expect(snapshot.pools.first.hashratePercent, 22.0);
    });

    test('rejects a payload without _meta.fetchedAt', () {
      final payload = _payload()..remove('_meta');
      expect(
        () => NetworkHealthSnapshot.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a payload without miningPools', () {
      final payload = _payload()..remove('miningPools');
      expect(
        () => NetworkHealthSnapshot.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('isStaleAt — the 26-hour cut', () {
    final snapshot = NetworkHealthSnapshot.fromJson(_payload());
    final fetchedAt = DateTime.utc(2026, 9, 6, 1, 0, 32);

    test('a payload from the last run is not stale', () {
      expect(
        snapshot.isStaleAt(fetchedAt.add(const Duration(hours: 3))),
        isFalse,
      );
    });

    test('one missed daily run is not yet stale at 24 hours', () {
      expect(
        snapshot.isStaleAt(fetchedAt.add(const Duration(hours: 24))),
        isFalse,
      );
    });

    test('exactly 26 hours is not stale — the bound is "older than"', () {
      expect(
        snapshot.isStaleAt(fetchedAt.add(const Duration(hours: 26))),
        isFalse,
      );
    });

    test('one second past 26 hours is stale', () {
      expect(
        snapshot.isStaleAt(
          fetchedAt.add(const Duration(hours: 26, seconds: 1)),
        ),
        isTrue,
      );
    });

    test('a local-time clock is compared on the same instant', () {
      // The screen passes `DateTime.now()`, which is local. The answer
      // must not depend on the device's offset.
      final localNow = fetchedAt.add(const Duration(hours: 30)).toLocal();
      expect(snapshot.isStaleAt(localNow), isTrue);
    });
  });
}
