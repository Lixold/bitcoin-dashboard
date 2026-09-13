import 'package:bitcoin_dashboard/features/market/domain/sentiment_band.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The last day of every generated window — a Sunday, UTC midnight, like
/// the source stamps its entries.
final DateTime _lastDay = DateTime.utc(2026, 9, 13);

/// A payload shaped like alternative.me's: newest entry first, every
/// field a string, `time_until_update` on the first element only.
///
/// [values] are given oldest first, the way the window reads, and are
/// reversed here so the test input has the source's own order rather than
/// a convenient one.
Map<String, dynamic> _payload(List<int> values, {Object? error}) {
  final entries = <Map<String, dynamic>>[];
  for (var i = 0; i < values.length; i++) {
    final day = _lastDay.subtract(Duration(days: values.length - 1 - i));
    entries.add(<String, dynamic>{
      'value': '${values[i]}',
      'value_classification': 'Greed',
      'timestamp': '${day.millisecondsSinceEpoch ~/ 1000}',
    });
  }
  final newestFirst = entries.reversed.toList();
  newestFirst.first['time_until_update'] = '19536';
  return <String, dynamic>{
    'name': 'Fear and Greed Index',
    'data': newestFirst,
    'metadata': <String, dynamic>{'error': error},
  };
}

/// A window of [length] days all sitting on [value].
List<int> _flat(int value, int length) => List<int>.filled(length, value);

void main() {
  group('the window alternative.me served on 2026-09-13', () {
    final index = SentimentIndex.fromJson(
      loadJsonFixture('sentiment-fng.json'),
    );

    test('reads all thirty days, oldest first', () {
      // The source serves newest first. Everything below counts back from
      // the end of the list, so the order is not a detail.
      expect(index.points, hasLength(SentimentIndex.windowDays));
      expect(index.points.first.value, 34);
      expect(index.points.first.at, DateTime.utc(2026, 8, 15));
      expect(index.latest.value, 61);
      expect(index.latest.at, DateTime.utc(2026, 9, 13));
    });

    test('the stamp is the value\'s own calendar day, in UTC', () {
      // Formatted in local time this would read 12 September everywhere
      // west of Greenwich.
      expect(index.latest.at.isUtc, isTrue);
      expect(index.latest.at.hour, 0);
    });

    test('states the band, the mean and the range', () {
      expect(index.band.key, SentimentBand.greed);
      expect(index.mean, closeTo(62.8, 0.001));
      expect(index.lowest, 31);
      expect(index.highest, 74);
    });

    test('the greed run has held for 25 days, since 20 August', () {
      expect(index.runLength, 25);
      expect(index.runStart, DateTime.utc(2026, 8, 20));
      expect(index.insight, SentimentInsight.switched);
    });
  });

  group('parsing', () {
    test('every numeric field arrives as a string and is read as a number', () {
      final index = SentimentIndex.fromJson(_payload([40, 50, 60]));

      expect(index.latest.value, 60);
      expect(index.points.first.at, _lastDay.subtract(const Duration(days: 2)));
    });

    test('metadata.error is a failure even though the status was 200', () {
      expect(
        () => SentimentIndex.fromJson(
          _payload([40, 50, 60], error: 'API limit reached'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an entry that cannot be read costs a point, not the window', () {
      final payload = _payload([40, 50, 60]);
      (payload['data'] as List<dynamic>)[1] = <String, dynamic>{
        'value': 'n/a',
        'timestamp': 'n/a',
      };

      final index = SentimentIndex.fromJson(payload);

      expect(index.points, hasLength(2));
      expect(index.latest.value, 60);
    });

    test('a value off the 0–100 scale is dropped', () {
      final payload = _payload([40, 50, 60]);
      (payload['data'] as List<dynamic>)[0] = <String, dynamic>{
        'value': '140',
        'timestamp': '${_lastDay.millisecondsSinceEpoch ~/ 1000}',
      };

      final index = SentimentIndex.fromJson(payload);

      expect(index.points.map((point) => point.value), [40, 50]);
    });

    test('a payload with nothing readable left is an error', () {
      // There is no empty state on this screen: a window with no value in
      // it states nothing.
      expect(
        () => SentimentIndex.fromJson(<String, dynamic>{
          'data': <dynamic>[],
          'metadata': <String, dynamic>{'error': null},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('a body without a data array is an error', () {
      expect(
        () => SentimentIndex.fromJson(<String, dynamic>{'name': 'Fear'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the current run', () {
    test('is the run the reader stands in, not the first switch', () {
      // Fear, then greed, then fear again: two changes in the window and
      // one current run, which is the last three days.
      final index = SentimentIndex.fromJson(
        _payload([30, 30, 60, 60, 60, 60, 30, 30, 30]),
      );

      expect(index.band.key, SentimentBand.fear);
      expect(index.runLength, 3);
      expect(index.runStart, _lastDay.subtract(const Duration(days: 2)));
      expect(index.insight, SentimentInsight.switched);
    });

    test('a whole window in one band names no date', () {
      final index = SentimentIndex.fromJson(
        _payload(_flat(60, SentimentIndex.windowDays)),
      );

      expect(index.runLength, SentimentIndex.windowDays);
      expect(index.insight, SentimentInsight.steady);
    });

    test('a run shorter than three days is not dated', () {
      // "Inside the Greed band without interruption since 12 September"
      // claims a continuity that two days do not have.
      final index = SentimentIndex.fromJson(_payload([30, 30, 30, 60, 60]));

      expect(index.runLength, 2);
      expect(index.insight, SentimentInsight.short);
    });

    test('a single day in a new band is not dated either', () {
      final index = SentimentIndex.fromJson(_payload([30, 30, 30, 30, 60]));

      expect(index.runLength, 1);
      expect(index.runStart, _lastDay);
      expect(index.insight, SentimentInsight.short);
    });

    test('a full window in one band that is short of thirty days is dated', () {
      // The steady sentence names all thirty values. A window the source
      // served short takes the dated sentence rather than miscounting.
      final index = SentimentIndex.fromJson(_payload(_flat(60, 12)));

      expect(index.runLength, 12);
      expect(index.insight, SentimentInsight.switched);
      expect(index.runStart, index.points.first.at);
    });
  });

  group('figures', () {
    test('the mean is not rounded here — the screen rounds it', () {
      final index = SentimentIndex.fromJson(_payload([61, 62, 63, 64]));

      expect(index.mean, 62.5);
    });

    test('the range is the window\'s own low and high', () {
      final index = SentimentIndex.fromJson(_payload([31, 74, 50]));

      expect(index.lowest, 31);
      expect(index.highest, 74);
    });

    test('a one-day window still states everything', () {
      final index = SentimentIndex.fromJson(_payload([61]));

      expect(index.mean, 61);
      expect(index.lowest, 61);
      expect(index.highest, 61);
      expect(index.runLength, 1);
      expect(index.insight, SentimentInsight.short);
    });
  });
}
