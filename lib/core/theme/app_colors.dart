import 'package:flutter/material.dart';

/// Design-system colours (Claude Design — Bitcoin Dashboard DESIGN.md).
///
/// Source values are authored in OKLCh; the constants below are the
/// pre-converted sRGB representations used at runtime. Keep both columns
/// in sync when the design system changes.
class AppColors {
  AppColors._();

  // Brand --------------------------------------------------------------------

  /// Bitcoin Orange — primary accent, also the M3 seed colour.
  static const Color primary = Color(0xFFF7931A);

  // Dark palette (default) ---------------------------------------------------

  static const Color darkBackground = Color(
    0xFF1A1611,
  ); // oklch(0.135 0.008 80)
  static const Color darkSurface = Color(0xFF211D17); // oklch(0.165 0.008 80)
  static const Color darkSurfaceVariant = Color(
    0xFF2A251F,
  ); // oklch(0.205 0.010 80)
  static const Color darkOutline = Color(0xFF3A342C); // oklch(0.275 0.012 80)
  static const Color darkOnSurface = Color(0xFFF6F3EE); // oklch(0.965 0.005 80)
  static const Color darkOnSurfaceVariant = Color(
    0xFFB3AA9C,
  ); // oklch(0.7 0.01 80)
  static const Color darkOnPrimary = Color(0xFF3A2613); // oklch(0.2 0.05 55)

  // Light palette ------------------------------------------------------------

  static const Color lightBackground = Color(
    0xFFFDFAF5,
  ); // oklch(0.992 0.004 80)
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(
    0xFFF6F1EA,
  ); // oklch(0.972 0.006 80)
  static const Color lightOutline = Color(0xFFE6E1D8); // oklch(0.918 0.008 80)
  static const Color lightOnSurface = Color(
    0xFF221D17,
  ); // oklch(0.180 0.012 80)
  static const Color lightOnSurfaceVariant = Color(0xFF6E6759);
  static const Color lightOnPrimary = Color(0xFFFFFAF2); // oklch(0.99 0.01 55)

  // Semantic / signal --------------------------------------------------------

  static const Color positive = Color(0xFF3AA86F); // oklch(0.74 0.135 150)
  static const Color negative = Color(0xFFE85D3A); // oklch(0.70 0.180 25)
  static const Color neutral = Color(0xFF888070); // oklch(0.580 0.008 80)
  static const Color amber = Color(0xFFD8A13A); // oklch(0.82 0.15 85)

  // Dark error matches negative; light error is darker for AA contrast.
  static const Color darkError = negative;
  static const Color lightError = Color(0xFFBF3F29); // oklch(0.55 0.175 25)

  // Signal colours, light scheme ---------------------------------------------
  //
  // **The four signal colours above are tuned for the dark surface and do
  // not carry to the light one.** On `lightSurface` they measure 3.00 : 1
  // (positive), 2.31 : 1 (amber) and 3.91 : 1 (neutral) — all below the
  // 4.5 : 1 that AA asks of the 11–14 px mono labels they are used on.
  // [lightError] already existed for exactly this reason; these three
  // complete the set, following the same rule rather than inventing one.
  //
  // Values are the design system's own light-scheme corrections, converted
  // from OKLCh. Unlike the constants above they have no OKLCh twin in the
  // design system's CSS to drift from: they were authored as OKLCh there,
  // so the conversion reproduces what was approved rather than
  // re-deriving it.

  /// `oklch(0.55 0.115 150)` — 4.60 : 1 on [lightSurface].
  static const Color lightPositive = Color(0xFF37844C);

  /// `oklch(0.52 0.135 75)` — 5.61 : 1 on [lightSurface].
  static const Color lightWarning = Color(0xFF955A00);

  /// `oklch(0.46 0.010 80)` — 7.17 : 1 on [lightSurface].
  static const Color lightNeutral = Color(0xFF5B5752);

  // Brightness-aware signal accessors ----------------------------------------
  //
  // Signal colours are deliberately not in `ColorScheme`: M3 has no slot
  // that means "this reading is good" and overloading `tertiary` would
  // hide the meaning. Widgets therefore read them here, and these four
  // accessors are the only place the light/dark choice is made — a widget
  // that writes the conditional itself is the bug this prevents.

  static Color positiveFor(Brightness brightness) =>
      brightness == Brightness.dark ? positive : lightPositive;

  static Color negativeFor(Brightness brightness) =>
      brightness == Brightness.dark ? negative : lightError;

  static Color warningFor(Brightness brightness) =>
      brightness == Brightness.dark ? amber : lightWarning;

  static Color neutralFor(Brightness brightness) =>
      brightness == Brightness.dark ? neutral : lightNeutral;
}
