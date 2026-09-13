import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavSection.hasShippedSlice', () {
    test('Price, Market and Network have shipped their first slice', () {
      expect(NavSection.price.hasShippedSlice, isTrue);
      expect(NavSection.market.hasShippedSlice, isTrue);
      expect(NavSection.network.hasShippedSlice, isTrue);
    });

    test('News, Forecast and Miner have not shipped a slice', () {
      // The flag says a slice is merged, not that a screen file exists.
      // News is declared, localised and has a location; none of that puts
      // it in the navigation.
      expect(NavSection.news.hasShippedSlice, isFalse);
      expect(NavSection.forecast.hasShippedSlice, isFalse);
      expect(NavSection.miner.hasShippedSlice, isFalse);
    });
  });

  group('NavSection.visible()', () {
    test('returns exactly the shipped sections in declaration order', () {
      expect(NavSection.visible(), const <NavSection>[
        NavSection.price,
        NavSection.market,
        NavSection.network,
      ]);
    });

    test('three of the six declared sections have shipped', () {
      // Flipping a flag is how a section joins the navigation, so the two
      // counts are worth pinning: the shipped three, and the six the enum
      // declares whether they have shipped or not.
      expect(NavSection.visible(), hasLength(3));
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
