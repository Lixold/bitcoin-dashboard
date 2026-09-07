/// Spacing scale — base unit 8 px. Mirrors `--s-1` … `--s-7` in the
/// design system CSS (4, 8, 12, 16, 24, 32, 48).
class AppSpacing {
  AppSpacing._();

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;

  static const double radius = 12;
  static const double cardRadius = 12;
  static const double pillRadius = 32;

  /// Horizontal page margin: 16 px on phones, 32 px from 768 px upward.
  static const double screenMarginMobile = 16;
  static const double screenMarginTablet = 32;

  /// Clearance every screen leaves below its last piece of content — the
  /// design system's `--nav-clearance`.
  ///
  /// It does not vary with the navigation's shape. The bar sits below the
  /// body and the rail and drawer beside it, so none of the three eats
  /// into this space; making the number depend on the width would move
  /// the foot of the page every time the window crosses a breakpoint,
  /// which is the reflow noise the single set of thresholds exists to
  /// avoid.
  static const double screenFootClearance = 80;

  /// Layout switches. These two widths are the app's only breakpoints —
  /// the gutter grows at [tabletBreakpoint], the layout goes two-column
  /// at [wideLayoutBreakpoint], and the navigation changes shape at both
  /// (`NavigationLayout`).
  ///
  /// **Nothing else gets its own numbers.** Issue #65 proposed 640 and
  /// 1240 for the navigation; two more thresholds would have meant four
  /// reflows across a window drag instead of two, for no gain the design
  /// system could name. It answered on these numbers and retired 640 /
  /// 1240 — a component that wants a different width has to argue with
  /// the layout, not add a third pair.
  static const double wideLayoutBreakpoint = 1024;
  static const double tabletBreakpoint = 768;
}
