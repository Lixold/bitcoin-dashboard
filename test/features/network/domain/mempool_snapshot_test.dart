import 'package:bitcoin_dashboard/features/network/domain/mempool_load.dart';
import 'package:bitcoin_dashboard/features/network/domain/mempool_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

final DateTime _observedAt = DateTime.utc(2026, 11, 20, 13, 11);

/// The two endpoints as mempool.space served them on 2026-11-20.
Map<String, dynamic> _mempool() =>
    loadJsonFixture('mempool-space-mempool.json');
Map<String, dynamic> _fees() =>
    loadJsonFixture('mempool-space-fees-recommended.json');

MempoolSnapshot _parse({
  Map<String, dynamic>? mempool,
  Map<String, dynamic>? fees,
}) => MempoolSnapshot.fromJson(
  mempool: mempool ?? _mempool(),
  fees: fees ?? _fees(),
  observedAt: _observedAt,
);

void main() {
  group('parses the captured payloads', () {
    test('reads the five fields the statement consumes', () {
      final snapshot = _parse();

      expect(snapshot.count, 81456);
      expect(snapshot.vsize, 36061905);
      expect(snapshot.fastestFee, 6);
      expect(snapshot.hourFee, 4);
      expect(snapshot.economyFee, 2);
      expect(snapshot.observedAt, _observedAt);
    });

    test('counts the queue in blocks of one million vB', () {
      final snapshot = _parse();

      expect(snapshot.blocksWorth, closeTo(36.06, 0.01));
      expect(snapshot.load.key, MempoolLoad.busy);
    });

    test('ignores the fields it does not state', () {
      // total_fee, fee_histogram, halfHourFee and minimumFee may change
      // shape without the statement noticing.
      final mempool = _mempool()
        ..remove('total_fee')
        ..remove('fee_histogram');
      final fees = _fees()
        ..remove('halfHourFee')
        ..remove('minimumFee');

      expect(_parse(mempool: mempool, fees: fees).count, 81456);
    });
  });

  group('fees as numbers, not integers', () {
    test('keeps a sub-satoshi estimate', () {
      final fees = _fees()..['economyFee'] = 0.5;

      expect(_parse(fees: fees).economyFee, 0.5);
    });
  });

  group('refuses a reading it cannot back', () {
    for (final field in ['count', 'vsize']) {
      test('mempool without "$field"', () {
        expect(
          () => _parse(mempool: _mempool()..remove(field)),
          throwsFormatException,
        );
      });
    }

    for (final field in ['fastestFee', 'hourFee', 'economyFee']) {
      test('fees without "$field"', () {
        expect(
          () => _parse(fees: _fees()..remove(field)),
          throwsFormatException,
        );
      });
    }

    test('a fee sent as a string', () {
      expect(
        () => _parse(fees: _fees()..['hourFee'] = '4'),
        throwsFormatException,
      );
    });

    test('a negative size', () {
      expect(
        () => _parse(mempool: _mempool()..['vsize'] = -1),
        throwsFormatException,
      );
    });
  });
}
