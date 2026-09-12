import 'package:bitcoin_dashboard/core/fx/fx_rates.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// The moment every age in this file is measured from. The captured
/// document was published on 10 September 2026 at 16:15 UTC.
final DateTime _now = DateTime.utc(2026, 9, 10, 20);

Map<String, dynamic> _payload({
  String fetchedAt = '2026-09-10T16:15:46+00:00',
  Object? currencies = const <String>['EUR', 'USD', 'JPY'],
  Map<String, dynamic>? usd = const <String, dynamic>{
    'EUR': 0.86088154,
    'USD': 1,
    'JPY': 154.17,
  },
}) => <String, dynamic>{
  '_meta': <String, dynamic>{
    'fetchedAt': fetchedAt,
    'date': '2026-09-10',
    'source': 'ECB',
    'currencies': ?currencies,
  },
  'USD': ?usd,
};

void main() {
  group('reading the published document', () {
    test('parses the capture the CDN actually served', () {
      final rates = FxRates.fromJson(loadJsonFixture('fx-rates.json'));

      expect(rates.fetchedAt, DateTime.utc(2026, 9, 10, 16, 15, 46));
      expect(rates.currencies, hasLength(30));
      expect(rates.currencies.first, 'AUD');
      expect(rates.currencies.last, 'ZAR');
      expect(rates.rate(from: 'usd', to: 'EUR'), 0.86088154);
    });

    test('keeps the source row and drops the other twenty-nine', () {
      final rates = FxRates.fromJson(loadJsonFixture('fx-rates.json'));

      // The document is a full 30 x 30 matrix and the fixture keeps all of
      // it, because a fixture is a capture. The model reads one row.
      expect(rates.fromSource, hasLength(30));
      expect(
        rates.rate(from: 'EUR', to: 'USD'),
        isNull,
        reason: 'the EUR row is in the payload but not in the model',
      );
    });

    test('reads the integer identity rate as a rate, not as a gap', () {
      // The matrix writes `"USD": 1` — an int where every other value is a
      // fraction. A `double` cast would throw on it.
      final rates = FxRates.fromJson(loadJsonFixture('fx-rates.json'));

      expect(rates.rate(from: 'usd', to: 'USD'), 1);
    });

    test('a document without fetchedAt is unreadable', () {
      // Nothing on screen could say how old the rate is, and a rate whose
      // age is unknown is worse than an absent one.
      expect(
        () => FxRates.fromJson(const <String, dynamic>{
          '_meta': <String, dynamic>{'source': 'ECB'},
          'USD': <String, dynamic>{'EUR': 0.86},
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => FxRates.fromJson(const <String, dynamic>{
          'USD': <String, dynamic>{'EUR': 0.86},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('a document quoting nothing parses and reports itself empty', () {
      // It is a state the screen renders — amounts in the source currency
      // — not an error it raises.
      final rates = FxRates.fromJson(_payload(usd: null));

      expect(rates.isEmpty, isTrue);
      expect(rates.currencies, isEmpty);
      expect(rates.rate(from: 'usd', to: 'EUR'), isNull);
    });

    test('drops a quote that could not carry a rate', () {
      final rates = FxRates.fromJson(
        _payload(
          usd: const <String, dynamic>{'EUR': 0.86, 'JPY': 0, 'GBP': null},
        ),
      );

      expect(rates.rate(from: 'usd', to: 'EUR'), 0.86);
      expect(rates.rate(from: 'usd', to: 'JPY'), isNull);
      expect(rates.rate(from: 'usd', to: 'GBP'), isNull);
    });
  });

  group('the currencies the picker may offer', () {
    test('follows the order the producer lists them in', () {
      final rates = FxRates.fromJson(
        _payload(currencies: const <String>['JPY', 'EUR', 'USD']),
      );

      expect(rates.currencies, ['JPY', 'EUR', 'USD']);
    });

    test('offers nothing the source row cannot reach', () {
      // A code the meta announces without a rate behind it would be an
      // option the picker cannot honour.
      final rates = FxRates.fromJson(
        _payload(
          currencies: const <String>['EUR', 'CHF', 'USD'],
          usd: const <String, dynamic>{'EUR': 0.86, 'USD': 1},
        ),
      );

      expect(rates.currencies, ['EUR', 'USD']);
    });

    test('falls back to the row when the meta has no usable list', () {
      final rates = FxRates.fromJson(
        _payload(
          currencies: null,
          usd: const <String, dynamic>{'JPY': 154.17, 'EUR': 0.86},
        ),
      );

      expect(rates.currencies, [
        'EUR',
        'JPY',
      ], reason: 'sorted to be scannable');
    });
  });

  group('the age of the rate', () {
    test('is measured from the producer stamp', () {
      final rates = FxRates.fromJson(_payload());

      expect(
        rates.ageAt(_now),
        const Duration(hours: 3, minutes: 44, seconds: 14),
      );
    });

    test('exactly four days has not yet earned the hint', () {
      // The bound is strict, as it is on MarketSnapshot. A Friday rate read
      // on the Tuesday after a long weekend is still the normal case.
      final rates = FxRates.fromJson(_payload());
      final fourDays = rates.fetchedAt.add(fxStaleAge);

      expect(rates.isStaleAt(fourDays), isFalse);
      expect(rates.isStaleAt(fourDays.add(const Duration(seconds: 1))), isTrue);
    });

    test('a weekend does not make a rate old', () {
      // 11 September 2026 is a Friday: the rate published that afternoon is
      // the current one all through the weekend and into Monday.
      final rates = FxRates.fromJson(
        _payload(fetchedAt: '2026-09-11T16:15:46+00:00'),
      );

      expect(rates.isStaleAt(DateTime.utc(2026, 9, 13, 12)), isFalse);
      expect(rates.isStaleAt(DateTime.utc(2026, 9, 14, 9)), isFalse);
    });
  });

  group('whether the rate is from today', () {
    test('is true for any hour of the publication day', () {
      final rates = FxRates.fromJson(_payload());

      expect(rates.isFromDayOf(DateTime.utc(2026, 9, 10, 16, 15, 46)), isTrue);
      expect(rates.isFromDayOf(DateTime.utc(2026, 9, 10, 23, 59, 59)), isTrue);
    });

    test('is false the moment the UTC day turns over', () {
      // Asked in UTC on both sides, so the answer does not depend on the
      // machine the suite runs on.
      final rates = FxRates.fromJson(_payload());

      expect(rates.isFromDayOf(DateTime.utc(2026, 9, 11)), isFalse);
      expect(rates.isFromDayOf(DateTime.utc(2026, 9, 9, 23, 59)), isFalse);
    });
  });
}
