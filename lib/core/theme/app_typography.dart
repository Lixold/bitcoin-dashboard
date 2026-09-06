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
  /// Every entry resolves on a machine nobody prepared for it. A face
  /// that only appears once a font pack is installed is not in this list,
  /// however good it looks: it would show the maintainer one rendering
  /// and users another, which is the gap this chain exists to close.
  ///
  /// * `Cambria` — Windows, lining figures.
  /// * `Noto Serif` — Android and most Linux desktops, lining figures.
  /// * `Times New Roman` — lining figures. It leads on Apple platforms
  ///   because it is the first entry macOS and iOS resolve at all, and
  ///   because it is the only serif they ship whose digits share one
  ///   height.
  /// * `Georgia` — the one old-style face here. Its digits vary in height
  ///   by 18.7 per 100 em (the 6 rises to 71 while the 5 stops at 52),
  ///   against 1.4 for Times New Roman, so a 64 px price visibly wobbles
  ///   as it ticks. That measurement is the whole reason it sits behind
  ///   every lining-figure face; it is not a ranking by looks and must
  ///   not be tidied forward.
  static const List<String> displayStack = <String>[
    'Cambria',
    'Noto Serif',
    'Times New Roman',
    'Georgia',
    'serif',
  ];

  /// Monospace chain for labels, units, deltas and metadata.
  ///
  /// Same rule as [displayStack]: nothing here depends on a font pack
  /// somebody installed by hand.
  ///
  /// * `Cascadia Mono` — in-box on Windows 11, absent on stock Windows 10.
  /// * `Roboto Mono` — Android and many Linux desktops.
  /// * `Menlo` — leads on Apple platforms; lining figures, spread 1.6 per
  ///   100 em.
  /// * `Consolas` — catches stock Windows 10, where Cascadia Mono is not
  ///   installed.
  static const List<String> monoStack = <String>[
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

  // Display — serif stack: the price hero, card metrics, section titles
  // and model names.
  //
  // No display style declares a `height`. The resolved face differs per
  // platform and a line height pinned near 1.0 clips the taller metrics
  // (Georgia needs ~1.14 em, Times New Roman ~1.15 em), so these styles
  // take the face's own metrics, which reserve roughly ten per cent.

  /// Smallest hero size, at viewports of 480 px and below.
  static const double heroMinFontSize = 48;

  /// Largest hero size, at viewports of 800 px and above.
  static const double heroMaxFontSize = 80;

  /// Share of the viewport width the hero takes between those bounds —
  /// the design system's `10vw`.
  static const double heroWidthFactor = 0.1;

  /// The price hero size for a viewport [width] — the design system's
  /// `clamp(48px, 10vw, 80px)`.
  ///
  /// **The hero scales; it is not one number.** A fixed 64 px is wrong at
  /// both ends of the range the app ships on: it crowds the line on a
  /// 390 px phone and reads as an ordinary heading on a 1200 px desktop
  /// frame, where the design system asks for 80. `TextStyle` has no
  /// `clamp()`, so the size is computed here from the window width and
  /// applied with `copyWith` where the price renders. Uses the window,
  /// not a `LayoutBuilder` box, because `vw` is a viewport unit and the
  /// hero should answer to the window the user drags.
  static double heroFontSize(double width) =>
      (width * heroWidthFactor).clamp(heroMinFontSize, heroMaxFontSize);

  /// The price hero — one per screen.
  ///
  /// [fontSize] here is the mid-scale value (`10vw` at a 640 px window)
  /// and exists so the style is complete on its own: it also backs
  /// `textTheme.displayLarge`, and a style without a size silently
  /// renders at 14. It is not the hero size. Anything that renders the
  /// price passes [heroFontSize] through `copyWith`.
  ///
  /// [letterSpacing] stays absolute rather than scaling with the size;
  /// across 48–80 px it moves between -0.010 em and -0.006 em, which is
  /// below the threshold where the tracking reads as different.
  static const TextStyle displayHero = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 64,
    letterSpacing: -0.5,
  );

  /// Card metrics, headlines, composite figures.
  static const TextStyle displayLarge = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 32,
  );

  /// Section titles.
  static const TextStyle displayMedium = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 24,
    letterSpacing: -0.1,
  );

  /// Model names — the label a valuation model carries next to its figure.
  static const TextStyle displaySmall = TextStyle(
    fontFamilyFallback: displayStack,
    fontWeight: FontWeight.w500,
    fontSize: 18,
  );

  // Body — platform sans; declares no family on purpose.
  //
  // **The sizes are the repository's, not the mockups'.** The design
  // system asked for 15 px prose; 15 is a web value carried over from the
  // OpenDesign mockups, and 16 is the platform default for body text on
  // all five targets this app ships to. So the design system moved to
  // 16 / 14 and these numbers stayed — the same lesson as the font
  // stacks: a value that was right in the mockups is not automatically
  // right in the product.
  //
  // What the 15 actually stood for was the rhythm, and that is what
  // [bodyLarge] takes over: 16 x 1.5 = 24 = `AppSpacing.s5`, so a wrapped
  // paragraph steps on the spacing grid instead of drifting off it. That
  // is the one number this decision moved.
  //
  // [bodyMedium] and [bodySmall] keep their 1.45 and land on 20.3 and
  // 18.85 — off the grid on purpose. The rhythm is only visible where
  // text wraps, and those two carry single-line descriptions and notes.
  // Bending 14 onto 20 would be a fraction invented for a line that never
  // has a second line to align with.
  //
  // The prose role is therefore still untried: every call site today is
  // one line. The first real paragraph is the insight sentence in #68,
  // and that is where 24 gets looked at rather than calculated.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
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
