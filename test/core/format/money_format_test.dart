import 'package:bitcoin_dashboard/core/format/money_format.dart';
import 'package:bitcoin_dashboard/core/fx/fx_rates.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// The space German puts before a currency symbol is a non-breaking one.
///
/// Written out rather than typed, because the two are indistinguishable
/// in a diff and only one of them keeps `126.080,00` and `$` on the same
/// line.
const String nbsp = ' ';

/// The live price the design sets its examples from.
const double _price = 78679.4;

/// The rates as the CDN published them on 10 September 2026.
FxRates _published() => FxRates.fromJson(loadJsonFixture('fx-rates.json'));

FxRates _quoting(Map<String, dynamic> usd) =>
    FxRates.fromJson(<String, dynamic>{
      '_meta': <String, dynamic>{'fetchedAt': '2026-09-10T16:15:46+00:00'},
      'USD': usd,
    });

void main() {
  group('the number follows the reader, the unit follows the source', () {
    test('the same amount groups differently in each locale', () {
      expect(formatMoney('en', 126080, 'usd'), r'$126,080.00');
      expect(formatMoney('de', 126080, 'usd'), '126.080,00$nbsp\$');
    });

    test('this formatter renders, it does not convert', () {
      // It is the last step, below the conversion: hand it dollars and it
      // sets dollars, whatever the reader picked. Deciding the unit is
      // `MoneyDisplay`'s job, and it hands the result down to here.
      expect(formatMoney('de', _price, 'usd'), '78.679,40$nbsp\$');
    });

    test('the payload writes the code in lower case', () {
      expect(
        formatMoney('en', 126080, 'usd'),
        formatMoney('en', 126080, 'USD'),
      );
    });

    test('an unknown code renders as itself, not as a guessed symbol', () {
      expect(formatMoney('en', 126080, 'zzz'), startsWith('ZZZ'));
    });
  });

  group('the short form is a false friend', () {
    test('10^12 is a trillion in English and a Billion in German', () {
      // The bug this test exists to prevent: a hand-written suffix table
      // that is right in one locale and off by a factor of 1000 in the
      // other.
      expect(formatMoneyCompact('en', 1578083556466, 'usd'), r'$1.58T');
      expect(
        formatMoneyCompact('de', 1578083556466, 'usd'),
        '1,58${nbsp}Bio.$nbsp\$',
      );
    });

    test('10^9 is a billion in English and a Milliarde in German', () {
      expect(formatMoneyCompact('en', 34469991545, 'usd'), r'$34.5B');
      expect(
        formatMoneyCompact('de', 34469991545, 'usd'),
        '34,5${nbsp}Mrd.$nbsp\$',
      );
    });

    test('the short form keeps three significant digits, not two decimals', () {
      // 1.58 trillion carries two decimals, 34.5 billion carries one:
      // both are three significant digits. A caller that needs a fixed
      // number of decimals wants `formatMoney`, not this.
      expect(formatMoneyCompact('en', 1578083556466, 'usd'), r'$1.58T');
      expect(formatMoneyCompact('en', 34469991545, 'usd'), r'$34.5B');
      expect(formatMoneyCompact('en', 126080, 'usd'), r'$126K');
    });
  });

  group('what the reader picked decides the unit', () {
    test('the source currency converts nothing and dates nothing', () {
      final display = MoneyDisplay.resolve(
        wanted: 'USD',
        rates: _published(),
        isLoading: false,
      );

      expect(display.state, MoneyDisplayState.source);
      expect(display.currency, 'USD');
      expect(display.format('en', _price, from: 'usd'), r'$78,679.40');
      expect(
        display.rates,
        isNull,
        reason: 'no rate was used, so the screen has no rate to date',
      );
    });

    test('a quoted currency converts the value and the symbol together', () {
      final display = MoneyDisplay.resolve(
        wanted: 'EUR',
        rates: _published(),
        isLoading: false,
      );

      expect(display.state, MoneyDisplayState.converted);
      expect(display.currency, 'EUR');
      expect(
        display.displayedAmount(_price, from: 'usd'),
        closeTo(_price * 0.86088154, 0.000001),
      );
      expect(display.format('de', _price, from: 'usd'), '67.733,64$nbsp€');
      expect(display.rates, isNotNull);
    });

    test('the compact form converts too', () {
      final display = MoneyDisplay.resolve(
        wanted: 'EUR',
        rates: _published(),
        isLoading: false,
      );

      expect(
        display.formatCompact('de', 1578083556466, from: 'usd'),
        '1,36${nbsp}Bio.$nbsp€',
      );
    });

    test('rates still in flight are not a failed conversion', () {
      final display = MoneyDisplay.resolve(
        wanted: 'EUR',
        rates: null,
        isLoading: true,
      );

      expect(display.state, MoneyDisplayState.pending);
      expect(display.isPending, isTrue);
    });

    test('rates that never arrived fall back to the source currency', () {
      final display = MoneyDisplay.resolve(
        wanted: 'EUR',
        rates: null,
        isLoading: false,
      );

      expect(display.state, MoneyDisplayState.unavailable);
      expect(display.isPending, isFalse);
      expect(
        display.currency,
        sourceCurrency,
        reason: 'the pill names the unit the figures are in, not the setting',
      );
      expect(display.format('de', _price, from: 'usd'), '78.679,40$nbsp\$');
    });

    test(
      'a currency the document does not quote is unavailable, not wrong',
      () {
        final display = MoneyDisplay.resolve(
          wanted: 'CHF',
          rates: _quoting(const <String, dynamic>{'EUR': 0.86, 'USD': 1}),
          isLoading: false,
        );

        expect(display.state, MoneyDisplayState.unavailable);
        expect(display.format('en', _price, from: 'usd'), r'$78,679.40');
      },
    );

    test('an empty document is the same to the reader as a missing one', () {
      final display = MoneyDisplay.resolve(
        wanted: 'EUR',
        rates: _quoting(const <String, dynamic>{}),
        isLoading: false,
      );

      expect(display.state, MoneyDisplayState.unavailable);
    });

    test('the symbol never disagrees with the number', () {
      // The rule the whole class exists for. In every state, the code that
      // comes out of `displayedCurrency` is the code the amount from
      // `displayedAmount` is actually in.
      final states = <MoneyDisplay>[
        MoneyDisplay.resolve(
          wanted: 'USD',
          rates: _published(),
          isLoading: false,
        ),
        MoneyDisplay.resolve(
          wanted: 'EUR',
          rates: _published(),
          isLoading: false,
        ),
        MoneyDisplay.resolve(wanted: 'EUR', rates: null, isLoading: false),
        MoneyDisplay.resolve(wanted: 'EUR', rates: null, isLoading: true),
      ];

      for (final display in states) {
        final code = display.displayedCurrency('usd');
        final amount = display.displayedAmount(_price, from: 'usd');
        expect(
          display.format('en', _price, from: 'usd'),
          formatMoney('en', amount, code),
          reason: 'state ${display.state}',
        );
      }
    });

    test('an amount in a currency it cannot convert keeps its own', () {
      // Nothing publishes in euros today. If something starts to, the
      // amount is rendered in euros rather than multiplied by a dollar
      // rate — one row of the matrix is all the model keeps.
      final display = MoneyDisplay.resolve(
        wanted: 'EUR',
        rates: _quoting(const <String, dynamic>{'EUR': 0.86, 'USD': 1}),
        isLoading: false,
      );

      expect(display.displayedCurrency('gbp'), 'GBP');
      expect(display.displayedAmount(100, from: 'gbp'), 100);
      expect(display.format('en', 100, from: 'gbp'), '£100.00');
    });
  });

  group('the unit named on its own', () {
    test('the symbol comes from intl, in the reader locale', () {
      expect(currencySymbol('en', 'usd'), r'$');
      expect(currencySymbol('de', 'eur'), '€');
      expect(currencySymbol('en', 'krw'), '₩');
    });
  });

  group('how many sats one unit buys', () {
    test('whole sats, grouped by the reader locale', () {
      expect(formatSats('de', 100000000 / _price), '1.271');
      expect(formatSats('en', 100000000 / _price), '1,271');
    });

    test('a weak currency says a fraction rather than zero', () {
      // One rupiah buys 0.07 sats. `1 Rp = 0 sats` would not be a
      // rounding, it would be a false statement about the world.
      final rates = _published();
      final idr = _price * rates.rate(from: 'usd', to: 'IDR')!;
      final sats = 100000000 / idr;

      expect(sats, lessThan(1));
      expect(formatSats('de', sats), '0,072');
    });

    test('just under one sat keeps two significant digits', () {
      final rates = _published();
      final krw = _price * rates.rate(from: 'usd', to: 'KRW')!;

      expect(formatSats('de', 100000000 / krw), '0,95');
    });

    test('the fraction never collapses to nothing', () {
      // Two significant digits at any magnitude the ECB list can produce.
      expect(formatSats('en', 0.0045), '0.0045');
      expect(formatSats('en', 0.00031), '0.00031');
    });
  });
}
