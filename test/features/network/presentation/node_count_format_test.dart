import 'package:bitcoin_dashboard/features/network/presentation/node_count_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatNodeCount', () {
    test('groups thousands the way the locale writes them', () {
      expect(formatNodeCount('en', 26579), '26,579');
      expect(formatNodeCount('de', 26579), '26.579');
    });

    test('leaves a figure below the grouping point alone', () {
      expect(formatNodeCount('en', 812), '812');
      expect(formatNodeCount('de', 812), '812');
    });

    test('groups again past a million', () {
      // Not a reading this source produces today, but the separator must
      // not be a single hard-coded one.
      expect(formatNodeCount('en', 1234567), '1,234,567');
      expect(formatNodeCount('de', 1234567), '1.234.567');
    });

    test('a count of zero is a figure, not an absence', () {
      // `NodeCount.from` decides whether the statement can be formed;
      // this one only prints what it is given.
      expect(formatNodeCount('en', 0), '0');
    });
  });
}
