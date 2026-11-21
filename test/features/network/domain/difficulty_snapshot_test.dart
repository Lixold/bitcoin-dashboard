import 'package:bitcoin_dashboard/features/network/domain/difficulty_direction.dart';
import 'package:bitcoin_dashboard/features/network/domain/difficulty_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

final DateTime _now = DateTime.utc(2026, 11, 21, 12, 29);

Map<String, dynamic> _captured() =>
    loadJsonFixture('mempool-space-difficulty-adjustment.json');

DifficultySnapshot _parse(Map<String, dynamic> json) =>
    DifficultySnapshot.fromJson(json, observedAt: _now);

void main() {
  group('the captured payload of 2026-11-21', () {
    test('reads the five consumed fields', () {
      final snapshot = _parse(_captured());

      expect(snapshot.changePercent, closeTo(10.2009, 0.0001));
      expect(snapshot.progressPercent, closeTo(57.4901, 0.0001));
      expect(snapshot.remainingBlocks, 857);
      expect(snapshot.observedAt, _now);
    });

    test('converts both millisecond fields to a Duration', () {
      final snapshot = _parse(_captured());

      // remainingTime 467,005,010 ms = 5 d 9 h 43 min 25.010 s.
      expect(snapshot.remaining, const Duration(milliseconds: 467005010));
      expect(snapshot.remaining.inDays, 5);
      expect(snapshot.remaining.inHours.remainder(24), 9);
      // timeAvg 544,930 ms = 9 min 4.93 s.
      expect(snapshot.averageBlockTime, const Duration(milliseconds: 544930));
      expect(snapshot.averageBlockTime.inMinutes, 9);
    });

    test('derives the mined blocks and the direction', () {
      final snapshot = _parse(_captured());

      expect(snapshot.blocksMined, 1159);
      expect(snapshot.direction.key, DifficultyDirection.harder);
    });

    test('passes the contract check of decision 5 of #46', () {
      final snapshot = _parse(_captured());
      final average = snapshot.averageBlockTime.inMilliseconds;
      final expected = snapshot.remainingBlocks * 600000;
      final ratio = snapshot.remaining.inMilliseconds / expected;

      expect(average, inInclusiveRange(60000, 6000000));
      expect(ratio, inInclusiveRange(1 / 3, 3));
    });
  });

  group('the millisecond boundary', () {
    test('reads milliseconds, not seconds', () {
      final json = _captured()
        ..['remainingTime'] = 1000
        ..['timeAvg'] = 600000;
      final snapshot = _parse(json);

      expect(snapshot.remaining, const Duration(seconds: 1));
      expect(snapshot.averageBlockTime, targetBlockTime);
    });

    test('drops sub-millisecond fractions instead of failing on them', () {
      final json = _captured()..['remainingTime'] = 1500.9;

      expect(_parse(json).remaining, const Duration(milliseconds: 1500));
    });

    test('a zero remaining time is a valid reading', () {
      final json = _captured()..['remainingTime'] = 0;

      expect(_parse(json).remaining, Duration.zero);
    });
  });

  group('the band reads the change as it is shown', () {
    DifficultySnapshot withChange(double change) =>
        _parse(_captured()..['difficultyChange'] = change);

    test('a change that shows as +0.0 % does not read harder', () {
      expect(withChange(0.04).shownChangePercent, 0);
      expect(withChange(0.04).direction.key, DifficultyDirection.easier);
    });

    test('a change that shows as +0.1 % reads harder', () {
      expect(withChange(0.05).shownChangePercent, closeTo(0.1, 1e-9));
      expect(withChange(0.05).direction.key, DifficultyDirection.harder);
    });

    test('a change that shows as −0.0 % reads easier', () {
      expect(withChange(-0.04).direction.key, DifficultyDirection.easier);
    });
  });

  group('rejects a reading it cannot back', () {
    for (final field in [
      'difficultyChange',
      'remainingTime',
      'progressPercent',
      'remainingBlocks',
      'timeAvg',
    ]) {
      test('without "$field"', () {
        final json = _captured()..remove(field);
        expect(() => _parse(json), throwsFormatException);
      });

      test('with "$field" as a string', () {
        final json = _captured()..[field] = '1';
        expect(() => _parse(json), throwsFormatException);
      });
    }

    test('with a negative time', () {
      expect(
        () => _parse(_captured()..['remainingTime'] = -1),
        throwsFormatException,
      );
      expect(
        () => _parse(_captured()..['timeAvg'] = -1),
        throwsFormatException,
      );
    });

    test('with a block count outside one period', () {
      expect(
        () => _parse(_captured()..['remainingBlocks'] = 2017),
        throwsFormatException,
      );
      expect(
        () => _parse(_captured()..['remainingBlocks'] = -1),
        throwsFormatException,
      );
      expect(
        () => _parse(_captured()..['remainingBlocks'] = 12.5),
        throwsFormatException,
      );
    });

    test('with a position outside 0–100', () {
      expect(
        () => _parse(_captured()..['progressPercent'] = 100.1),
        throwsFormatException,
      );
      expect(
        () => _parse(_captured()..['progressPercent'] = -0.1),
        throwsFormatException,
      );
    });
  });

  test('ignores the fields the statement does not read', () {
    final json = _captured()
      ..remove('estimatedRetargetDate')
      ..remove('nextRetargetHeight')
      ..remove('previousRetarget')
      ..remove('previousTime')
      ..remove('adjustedTimeAvg');

    expect(() => _parse(json), returnsNormally);
  });
}
