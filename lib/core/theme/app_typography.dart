import 'package:flutter/material.dart';

/// Typography tokens — three roles on platform font stacks:
///
///   * **display** (serif stack)  — BTC price, card metrics, headlines
///   * **body**    (platform sans) — UI text
///   * **mono**    (mono stack)    — labels, units, deltas, metadata
///
/// No font files are bundled. Each role names a fallback chain of faces
/// that are already installed on the target platforms, so the theme
/// documents what actually renders instead of a family that never ships.
///
/// **The chains are ordered by figure quality, not by preference.** A
/// price hero is a column of digits that changes every few seconds, so a
/// face with lining, evenly-spaced figures beats a nicer text face with
/// old-style figures. Do not alphabetise these lists and do not promote
/// a face because it looks better in running text.
class AppTypography {
  AppTypography._();

  /// Serif chain for figures and headlines.
  ///
  /// * `New York` — Apple, lining figures. Ships inside macOS/iOS only as
  ///   the hidden system face `.New York`, which cannot be requested by
  ///   family name; it resolves solely where Apple's downloadable New
  ///   York pack is installed. Kept because that costs nothing when it is
  ///   absent, but it is not what a stock Mac renders.
  /// * `Cambria` — Windows, lining figures.
  /// * `Noto Serif` — Android and most Linux desktops, lining figures.
  /// * `Times New Roman` — lining figures; the face a stock Mac lands on.
  /// * `Georgia` — old-style figures that make a 64 px hero wobble, so it
  ///   sits behind every lining-figure face and ahead of generic `serif`.
  static const List<String> displayStack = <String>[
    'New York',
    'Cambria',
    'Noto Serif',
    'Times New Roman',
    'Georgia',
    'serif',
  ];

  /// Monospace chain for labels, units, deltas and metadata.
  ///
  /// * `SF Mono` — like New York, in-box on macOS only as the hidden
  ///   `.SF NS Mono`; resolves where Apple's SF Mono pack is installed.
  /// * `Cascadia Mono` — in-box on Windows 11, absent on stock Windows 10.
  /// * `Roboto Mono` — Android and many Linux desktops.
  /// * `Menlo` — the face a stock Mac lands on.
  /// * `Consolas` — the face a stock Windows 10 lands on.
  static const List<String> monoStack = <String>[
    'SF Mono',
    'Cascadia Mono',
    'Roboto Mono',
    'Menlo',
    'Consolas',
    'monospace',
  ];

  /// Figures that update in place need both features: [liningFigures] so
  /// the digits sit on one baseline at one height, [tabularFigures] so a
  /// changing value does not reflow the line.
  static const List<FontFeature> figureFeatures = <FontFeature>[
    FontFeature.liningFigures(),
    FontFeature.tabularFigures(),
  ];

  // Display — serif stack, used for the BTC price hero and card metrics.
  //
  // Figure styles declare no `height`. The resolved face differs per
  // platform and a line height pinned near 1.0 clips the taller metrics
  // (Georgia needs ~1.14 em, Times New Roman ~1.15 em), so these styles
  // take the face's own metrics, which reserve roughly ten per cent.

  static const TextStyle displayHero = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 64,
    letterSpacing: -0.5,
  );

  static const TextStyle displayLarge = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 32,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 20,
    height: 1.2,
    letterSpacing: -0.1,
  );

  // Body — platform sans; declares no family on purpose.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  // Mono — mono stack: labels, units, deltas, metadata.

  /// Units and deltas that sit next to a figure. Metrics themselves use
  /// the display role, not this one.
  static const TextStyle monoValue = TextStyle(
    fontFamilyFallback: monoStack,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    fontFeatures: figureFeatures,
  );

  static const TextStyle monoCaption = TextStyle(
    fontFamilyFallback: monoStack,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 1.1, // ≈ 0.1em uppercase tracking
    fontFeatures: figureFeatures,
  );

  static const TextStyle monoLabel = TextStyle(
    fontFamilyFallback: monoStack,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 1.3,
    letterSpacing: 0.5,
  );
}
