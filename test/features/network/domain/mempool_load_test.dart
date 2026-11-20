import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/domain/mempool_load.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_de.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

MempoolLoad _bandFor(double blocks) => mempoolLoadScale.bandFor(blocks).key;

void main() {
  group('the three boundaries, from both sides', () {
    // Every lower bound is inclusive (#112), so each boundary is checked
    // on the value itself and just below it.
    test('9.99 is still calm, 10 is already normal', () {
      expect(_bandFor(9.99), MempoolLoad.calm);
      expect(_bandFor(10), MempoolLoad.normal);
    });

    test('29.99 is still normal, 30 is already busy', () {
      expect(_bandFor(29.99), MempoolLoad.normal);
      expect(_bandFor(30), MempoolLoad.busy);
    });

    test('44.99 is still busy, 45 is already congested', () {
      expect(_bandFor(44.99), MempoolLoad.busy);
      expect(_bandFor(45), MempoolLoad.congested);
    });

    test('an empty mempool is calm and a huge one congested', () {
      expect(_bandFor(0), MempoolLoad.calm);
      expect(_bandFor(500), MempoolLoad.congested);
    });

    test('the readings measured on 2026-11-20 are busy', () {
      // 34.9–35.8 MvB at every one of the ten live fetches.
      expect(_bandFor(34.93), MempoolLoad.busy);
      expect(_bandFor(35.82), MempoolLoad.busy);
    });
  });

  group('tone', () {
    test(
      'calm and normal are positive, busy a warning, congested negative',
      () {
        expect(mempoolLoadScale.bandFor(5).tone, StatementTone.positive);
        expect(mempoolLoadScale.bandFor(20).tone, StatementTone.positive);
        expect(mempoolLoadScale.bandFor(35).tone, StatementTone.warning);
        expect(mempoolLoadScale.bandFor(50).tone, StatementTone.negative);
      },
    );
  });

  group('the scale itself', () {
    test('covers all four bands, ascending', () {
      expect(
        mempoolLoadScale.bands.map((band) => band.key),
        MempoolLoad.values,
      );
      final bounds = mempoolLoadScale.bands.map((band) => band.from).toList();
      expect(bounds, [...bounds]..sort());
    });

    test('ticks at 10, 30 and 45 blocks', () {
      expect(mempoolLoadScale.boundaries, [10, 30, 45]);
    });

    test('every bound is inclusive', () {
      expect(
        mempoolLoadScale.bands.every((band) => band.fromIsInclusive),
        isTrue,
      );
    });

    test('the meter track reaches past the last boundary', () {
      expect(
        mempoolLoadMeterMax,
        greaterThan(mempoolLoadScale.boundaries.last),
      );
    });
  });

  group('copy', () {
    test('every band has its own verdict and sentence in both locales', () {
      for (final l10n in [AppL10nEn(), AppL10nDe()]) {
        final labels = MempoolLoad.values.map((b) => b.label(l10n)).toSet();
        final sentences = MempoolLoad.values
            .map((b) => b.insight(l10n, '5'))
            .toSet();
        expect(labels, hasLength(4));
        expect(sentences, hasLength(4));
        expect(sentences.every((s) => s.contains('5 sat/vB')), isTrue);
      }
    });

    test('reads the statement the issue specifies', () {
      expect(
        MempoolLoad.busy.insight(AppL10nEn(), '5'),
        'The mempool is busy: a transaction paying 5 sat/vB confirms in '
        'about an hour.',
      );
    });
  });
}
