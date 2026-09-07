import '../../../core/theme/app_spacing.dart';

/// Which shape the navigation takes at a given window width.
///
/// Pure logic on purpose: the two thresholds are the one thing about the
/// adaptive navigation worth testing without a widget tree, and the shell
/// stays a composition of widgets rather than a place where a breakpoint
/// is decided.
enum NavigationLayout {
  /// Bottom `NavigationBar` — the phone expression.
  bar,

  /// Left `NavigationRail` — tablets and small desktop windows.
  rail,

  /// Left `NavigationDrawer` — wide desktop windows.
  drawer;

  /// The expression for a window [width] in logical pixels.
  ///
  /// The thresholds are [AppSpacing.tabletBreakpoint] and
  /// [AppSpacing.wideLayoutBreakpoint] — the widths at which the layout
  /// already changes. Issue #65 proposed 640 and 1240 instead; adopting
  /// them would have given the window four reflow points instead of two.
  /// The design system settled it on the layout's numbers, so navigation
  /// and layout move together.
  ///
  /// The bound is inclusive on the wider side: a window of exactly 768 is
  /// a rail, exactly 1024 a drawer.
  static NavigationLayout forWidth(double width) {
    if (width >= AppSpacing.wideLayoutBreakpoint) {
      return NavigationLayout.drawer;
    }
    if (width >= AppSpacing.tabletBreakpoint) {
      return NavigationLayout.rail;
    }
    return NavigationLayout.bar;
  }
}
