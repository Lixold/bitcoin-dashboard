import 'package:bitcoin_dashboard/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Window sizes shared by the widget tests.
///
/// The widths are named after what the app does at them rather than
/// written as bare numbers. Both breakpoints are inclusive on the wider
/// side (`NavigationLayout.forWidth`): exactly
/// [AppSpacing.tabletBreakpoint] is already the rail and exactly
/// [AppSpacing.wideLayoutBreakpoint] is already the drawer, so [phone]
/// sits below the first and [tablet] between the two.
///
/// A test that asserts *where* a breakpoint lies still writes the number
/// itself — there the number is the claim, not the scenery.
///
/// Height is part of a size. The default 800×600 test view clips anything
/// taller, and `find` does not reach what is not laid out, so a screen
/// that scrolls needs one of the `tall` variants or its assertions fail on
/// content that is present and simply below the fold.
class TestView {
  TestView._();

  /// Below [AppSpacing.tabletBreakpoint] — the bottom bar.
  static const Size phone = Size(390, 900);

  /// Between the two breakpoints — the rail.
  static const Size tablet = Size(900, 1000);

  /// At or above [AppSpacing.wideLayoutBreakpoint] — the drawer.
  static const Size desktop = Size(1200, 1000);

  /// [phone] with room for a full screen below the fold.
  static const Size tallPhone = Size(390, 3000);

  /// [tablet] with room for a full screen below the fold.
  static const Size tallTablet = Size(900, 2600);

  /// [desktop] with room for a full screen below the fold.
  static const Size tallDesktop = Size(1280, 2000);
}

/// Renders into a [size] window at one device pixel per logical pixel, and
/// puts the view back when the test ends.
void useView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
