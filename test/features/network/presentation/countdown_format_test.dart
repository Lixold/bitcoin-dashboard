import 'package:bitcoin_dashboard/features/network/presentation/countdown_format.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_de.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _dhm(int days, int hours, int minutes) =>
    Duration(days: days, hours: hours, minutes: minutes);

void main() {
  group('countdownParts', () {
    test('days and hours from one day out, truncated', () {
      expect(countdownParts(_dhm(5, 9, 50)), [
        (value: 5, unit: CountdownUnit.days),
        (value: 9, unit: CountdownUnit.hours),
      ]);
      expect(countdownParts(const Duration(days: 1)), [
        (value: 1, unit: CountdownUnit.days),
        (value: 0, unit: CountdownUnit.hours),
      ]);
    });

    test('hours and minutes below a day', () {
      expect(countdownParts(_dhm(0, 23, 59)), [
        (value: 23, unit: CountdownUnit.hours),
        (value: 59, unit: CountdownUnit.minutes),
      ]);
      expect(countdownParts(const Duration(hours: 1)), [
        (value: 1, unit: CountdownUnit.hours),
        (value: 0, unit: CountdownUnit.minutes),
      ]);
    });

    test('minutes alone below an hour, never seconds', () {
      expect(countdownParts(const Duration(minutes: 59, seconds: 59)), [
        (value: 59, unit: CountdownUnit.minutes),
      ]);
      expect(countdownParts(Duration.zero), [
        (value: 0, unit: CountdownUnit.minutes),
      ]);
    });

    test('a negative estimate counts as nothing left', () {
      expect(countdownParts(const Duration(minutes: -3)), [
        (value: 0, unit: CountdownUnit.minutes),
      ]);
    });
  });

  group('aboutRemaining', () {
    test('rounds to the nearest whole day from one day out', () {
      expect(aboutRemaining(_dhm(5, 9, 43)), (
        value: 5,
        unit: CountdownUnit.days,
      ));
      expect(aboutRemaining(_dhm(5, 12, 0)), (
        value: 6,
        unit: CountdownUnit.days,
      ));
      expect(aboutRemaining(const Duration(days: 1)), (
        value: 1,
        unit: CountdownUnit.days,
      ));
    });

    test('counts in the same unit as the countdown', () {
      // 23 h 59 min: the countdown shows hours, so the sentence does too.
      expect(aboutRemaining(_dhm(0, 23, 59)), (
        value: 24,
        unit: CountdownUnit.hours,
      ));
      expect(aboutRemaining(_dhm(0, 0, 59)), (
        value: 59,
        unit: CountdownUnit.minutes,
      ));
    });

    test('never says less than one', () {
      expect(aboutRemaining(Duration.zero), (
        value: 1,
        unit: CountdownUnit.minutes,
      ));
      expect(aboutRemaining(const Duration(seconds: 20)), (
        value: 1,
        unit: CountdownUnit.minutes,
      ));
    });
  });

  group('copy', () {
    final en = AppL10nEn();
    final de = AppL10nDe();

    test('labels count in both locales', () {
      expect(CountdownUnit.days.label(en, 1), 'day');
      expect(CountdownUnit.days.label(en, 5), 'days');
      expect(CountdownUnit.hours.label(de, 1), 'Stunde');
      expect(CountdownUnit.minutes.label(de, 0), 'Minuten');
    });

    test('the sentence phrase takes the German dative', () {
      expect(CountdownUnit.days.phrase(en, 5), '5 days');
      expect(CountdownUnit.days.phrase(en, 1), '1 day');
      expect(CountdownUnit.days.phrase(de, 5), '5 Tagen');
      expect(CountdownUnit.days.phrase(de, 1), '1 Tag');
      expect(CountdownUnit.hours.phrase(de, 3), '3 Stunden');
    });
  });
}
