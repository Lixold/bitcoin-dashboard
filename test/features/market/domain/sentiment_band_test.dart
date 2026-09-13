import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_band.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_de.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

SentimentBand _bandFor(num value) =>
    sentimentScale.bandFor(value.toDouble()).key;

void main() {
  group('the four boundaries, from both sides', () {
    // The four numbers the meter ticks and the sparkline draws. Each one
    // is checked on the value itself and on the value below it, because
    // the bands are half-open and a matrix that only gets tested in the
    // middle of its bands is a matrix nobody has tested.
    test('25 is still extreme fear, 26 is already fear', () {
      expect(_bandFor(25), SentimentBand.extremeFear);
      expect(_bandFor(26), SentimentBand.fear);
    });

    test('46 is still fear, 47 is already neutral', () {
      expect(_bandFor(46), SentimentBand.fear);
      expect(_bandFor(47), SentimentBand.neutral);
    });

    test('54 is still neutral, 55 is already greed', () {
      expect(_bandFor(54), SentimentBand.neutral);
      expect(_bandFor(55), SentimentBand.greed);
    });

    test('75 is still greed, 76 is already extreme greed', () {
      expect(_bandFor(75), SentimentBand.greed);
      expect(_bandFor(76), SentimentBand.extremeGreed);
    });

    test('both ends of the scale land in the outer bands', () {
      expect(_bandFor(sentimentScaleMin), SentimentBand.extremeFear);
      expect(_bandFor(sentimentScaleMax), SentimentBand.extremeGreed);
    });
  });

  group('tone', () {
    test('is the deviation from the middle, not a direction', () {
      // Fear and greed read alike, and so do both extremes: neither is a
      // buying signal, and the colour must not say otherwise.
      expect(sentimentScale.bandFor(30).tone, StatementTone.warning);
      expect(sentimentScale.bandFor(70).tone, StatementTone.warning);
      expect(sentimentScale.bandFor(10).tone, StatementTone.negative);
      expect(sentimentScale.bandFor(90).tone, StatementTone.negative);
    });

    test('the calm middle is the positive one', () {
      expect(sentimentScale.bandFor(50).tone, StatementTone.positive);
    });
  });

  group('the scale itself', () {
    test('covers all five bands, ascending', () {
      expect(
        sentimentScale.bands.map((band) => band.key),
        SentimentBand.values,
      );
      for (var i = 1; i < sentimentScale.bands.length; i++) {
        expect(
          sentimentScale.bands[i].from,
          greaterThan(sentimentScale.bands[i - 1].from),
          reason: 'band $i starts below its predecessor',
        );
      }
    });

    test('its boundaries are the four the design ticks', () {
      expect(sentimentScale.boundaries, [26, 47, 55, 76]);
    });
  });

  group('every band carries copy in both locales', () {
    for (final l10n in <AppL10n>[AppL10nEn(), AppL10nDe()]) {
      test('${l10n.localeName}: five distinct words and five claims', () {
        final labels = SentimentBand.values.map((b) => b.label(l10n)).toSet();
        final claims = SentimentBand.values.map((b) => b.claim(l10n)).toSet();

        expect(labels, hasLength(SentimentBand.values.length));
        expect(claims, hasLength(SentimentBand.values.length));
        expect(labels.any((label) => label.isEmpty), isFalse);
        expect(claims.any((claim) => claim.isEmpty), isFalse);
      });
    }
  });
}
