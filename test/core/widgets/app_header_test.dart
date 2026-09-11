import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/widgets/app_header.dart';
import 'package:bitcoin_dashboard/core/widgets/brand_icon.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// The gear, told apart by its glyph.
///
/// The header carries two glyphs since the currency pill became a control
/// — the gear and the pill's chevron — so "the icon in the header" is no
/// longer a description of one widget.
Finder _glyphInHeader(UiGlyph glyph) => find.descendant(
  of: find.byType(AppHeader),
  matching: find.byWidgetPredicate(
    (widget) => widget is BrandIcon && widget.glyph == glyph,
  ),
);

final Finder _gearIcon = _glyphInHeader(UiGlyph.settings);

BrandIcon _gear(WidgetTester tester) => tester.widget<BrandIcon>(_gearIcon);

void main() {
  setUpTestHive(clearBetweenTests: true);

  testWidgets('the header names the app, never the section', (tester) async {
    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppHeader),
        matching: find.text('Bitcoin Dashboard'),
      ),
      findsOneWidget,
    );
    // The section name belongs to the navigation, not to the header.
    expect(
      find.descendant(of: find.byType(AppHeader), matching: find.text('Price')),
      findsNothing,
    );
  });

  testWidgets('the gear opens settings and closes it again', (tester) async {
    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);

    // The gear is the way back out: on the settings screen it marks the
    // open screen, and tapping it returns to the section it was opened
    // from. Without that it would be a control that does nothing.
    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    expect(find.byType(PriceScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('the pill is on the section header and not on settings', (
    tester,
  ) async {
    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    // USD is the first-launch default in AppSettings.defaults().
    expect(find.text('USD / BTC'), findsOneWidget);

    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    // The currency is set on this screen, so the pill would be stating
    // what the row below it already says.
    expect(find.text('USD / BTC'), findsNothing);
  });

  testWidgets('the gear marks the settings screen while it is open', (
    tester,
  ) async {
    await pumpAppRoot(tester);
    await tester.pumpAndSettle();

    expect(_gear(tester).color, AppColors.lightOnSurfaceVariant);

    await tester.tap(_gearIcon);
    await tester.pumpAndSettle();

    expect(_gear(tester).color, AppColors.primary);
  });

  testWidgets('the header keeps its composition across the breakpoints', (
    tester,
  ) async {
    // A phone, a tablet and a desktop window: 768 and 1024 are where the
    // navigation changes shape (#65), and the header does not follow it.
    for (final size in const <Size>[
      TestView.phone,
      TestView.tablet,
      TestView.desktop,
    ]) {
      useView(tester, size);

      await pumpAppRoot(tester);
      await tester.pumpAndSettle();

      expect(
        _gearIcon,
        findsOneWidget,
        reason: 'gear at ${size.width.toInt()} px',
      );
      expect(
        find.text('USD / BTC'),
        findsOneWidget,
        reason: 'currency pill at ${size.width.toInt()} px',
      );
    }
  });
}
