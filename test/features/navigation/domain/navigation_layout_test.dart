import 'package:bitcoin_dashboard/core/theme/app_spacing.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/navigation_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationLayout.forWidth', () {
    test('the two thresholds are the layout breakpoints, not a third pair', () {
      // 640 / 1240 was the issue's proposal and is retired: navigation
      // changes shape where the layout already does.
      expect(AppSpacing.tabletBreakpoint, 768);
      expect(AppSpacing.wideLayoutBreakpoint, 1024);
    });

    test('a narrow window gets the bar', () {
      expect(NavigationLayout.forWidth(320), NavigationLayout.bar);
      expect(NavigationLayout.forWidth(390), NavigationLayout.bar);
    });

    test('the tablet breakpoint switches bar to rail, and one dp below does '
        'not', () {
      expect(
        NavigationLayout.forWidth(AppSpacing.tabletBreakpoint - 1),
        NavigationLayout.bar,
      );
      expect(
        NavigationLayout.forWidth(AppSpacing.tabletBreakpoint),
        NavigationLayout.rail,
      );
    });

    test('the wide breakpoint switches rail to drawer, and one dp below does '
        'not', () {
      expect(
        NavigationLayout.forWidth(AppSpacing.wideLayoutBreakpoint - 1),
        NavigationLayout.rail,
      );
      expect(
        NavigationLayout.forWidth(AppSpacing.wideLayoutBreakpoint),
        NavigationLayout.drawer,
      );
    });

    test('a very wide window stays a drawer', () {
      expect(NavigationLayout.forWidth(2560), NavigationLayout.drawer);
    });
  });
}
