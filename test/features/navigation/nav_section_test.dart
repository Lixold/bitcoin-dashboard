import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavSection.isVisibleInPhase3', () {
    test('Kurs, Markt, Netzwerk, News are visible in Phase 3', () {
      expect(NavSection.kurs.isVisibleInPhase3, isTrue);
      expect(NavSection.markt.isVisibleInPhase3, isTrue);
      expect(NavSection.netzwerk.isVisibleInPhase3, isTrue);
      expect(NavSection.news.isVisibleInPhase3, isTrue);
    });

    test('Prognose and Miner are deferred (hidden) in Phase 3', () {
      expect(NavSection.prognose.isVisibleInPhase3, isFalse);
      expect(NavSection.miner.isVisibleInPhase3, isFalse);
    });
  });

  group('NavSection.visible()', () {
    test('returns exactly the four Phase-3 sections in declaration order', () {
      expect(
        NavSection.visible(),
        const <NavSection>[
          NavSection.kurs,
          NavSection.markt,
          NavSection.netzwerk,
          NavSection.news,
        ],
      );
    });

    test('count matches the design-system Phase-3 spec', () {
      expect(NavSection.visible(), hasLength(4));
      expect(NavSection.values, hasLength(6));
    });
  });

  group('NavSection asset paths', () {
    test('every section points to an asset under assets/icons/nav/', () {
      for (final section in NavSection.values) {
        expect(
          section.asset,
          startsWith('assets/icons/nav/'),
          reason: '${section.id} should live under assets/icons/nav/',
        );
        expect(section.asset, endsWith('.svg'));
      }
    });

    test('each section asset path uses its id', () {
      for (final section in NavSection.values) {
        expect(section.asset, contains('${section.id}.svg'));
      }
    });
  });
}
