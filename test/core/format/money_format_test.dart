import 'package:bitcoin_dashboard/core/format/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// The space German puts before a currency symbol is a non-breaking one.
///
/// Written out rather than typed, because the two are indistinguishable
/// in a diff and only one of them keeps `126.080,00` and `$` on the same
/// line.
const String nbsp = ' ';

void main() {
  group('the number follows the reader, the unit follows the source', () {
    test('the same amount groups differently in each locale', () {
      expect(formatMoney('en', 126080, 'usd'), r'$126,080.00');
      expect(formatMoney('de', 126080, 'usd'), '126.080,00$nbsp\$');
    });

    test('a German reader still sees dollars, because the data is dollars', () {
      // The setting cannot move this symbol until #32 converts the value
      // underneath it.
      expect(formatMoney('de', 78679.4, 'usd'), '78.679,40$nbsp\$');
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
}
