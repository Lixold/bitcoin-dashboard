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

  /// Layout switches.
  static const double wideLayoutBreakpoint = 1024;
  static const double tabletBreakpoint = 768;
}
