import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:bitcoin_dashboard/features/network/domain/difficulty_direction.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_de.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the boundary at 0 %', () {
    test('a change above zero makes mining harder', () {
      expect(
        difficultyDirectionScale.bandFor(0.01).key,
        DifficultyDirection.harder,
      );
      expect(
        difficultyDirectionScale.bandFor(10.2).key,
        DifficultyDirection.harder,
      );
    });

    test('an exact zero falls on the easier side', () {
      expect(
        difficultyDirectionScale.bandFor(0).key,
        DifficultyDirection.easier,
      );
    });

    test('a change below zero makes mining easier', () {
      expect(
        difficultyDirectionScale.bandFor(-0.01).key,
        DifficultyDirection.easier,
      );
      expect(
        difficultyDirectionScale.bandFor(-9.1).key,
        DifficultyDirection.easier,
      );
    });
  });

  test('both directions are neutral: neither is good or bad in itself', () {
    for (final band in difficultyDirectionScale.bands) {
      expect(band.tone, StatementTone.neutral, reason: band.key.name);
    }
  });

  test('declares exactly one band per direction, lowest first', () {
    expect(difficultyDirectionScale.bands.map((band) => band.key), [
      DifficultyDirection.easier,
      DifficultyDirection.harder,
    ]);
    expect(difficultyDirectionScale.boundaries, [0]);
  });

  group('copy', () {
    final en = AppL10nEn();
    final de = AppL10nDe();

    test('each direction names itself in both locales', () {
      expect(DifficultyDirection.harder.label(en), 'Harder');
      expect(DifficultyDirection.easier.label(en), 'Easier');
      expect(DifficultyDirection.harder.label(de), 'Schwerer');
      expect(DifficultyDirection.easier.label(de), 'Leichter');
    });

    test('the sentence says when, which way and by how much', () {
      expect(
        DifficultyDirection.harder.insight(en, '5 days', '10.2'),
        'In about 5 days the difficulty will probably rise by 10.2 %, '
        'which makes mining harder.',
      );
      expect(
        DifficultyDirection.easier.insight(en, '3 hours', '4.0'),
        'In about 3 hours the difficulty will probably fall by 4.0 %, '
        'which makes mining easier.',
      );
      expect(
        DifficultyDirection.harder.insight(de, '5 Tagen', '10,2'),
        'In etwa 5 Tagen steigt die Difficulty voraussichtlich um 10,2 %, '
        'das macht Mining schwerer.',
      );
    });

    test('the reason ties the direction to the ten-minute target', () {
      expect(DifficultyDirection.harder.reason(en), contains('faster'));
      expect(DifficultyDirection.easier.reason(en), contains('slower'));
    });
  });
}
