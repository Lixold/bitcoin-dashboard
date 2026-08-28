import 'package:flutter/material.dart';

/// Typography tokens — three families, three roles:
///
///   * **display** (Newsreader)        — BTC price, large headlines
///   * **body**    (system sans)       — UI text
///   * **mono**    (IBM Plex Mono)     — numbers, labels, captions
///
/// Fonts are not bundled as assets yet; the names below fall back to the
/// platform's nearest match. Bundling can happen in a follow-up.
class AppTypography {
  AppTypography._();

  static const String displayFamily = 'Newsreader';
  static const String monoFamily = 'IBM Plex Mono';

  static const List<String> displayFallback = <String>[
    'Georgia',
    'Times New Roman',
    'serif',
  ];
  static const List<String> monoFallback = <String>[
    'Menlo',
    'Courier New',
    'monospace',
  ];

  // Display — Newsreader, used for the BTC price hero.
  static const TextStyle displayHero = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontWeight: FontWeight.w500,
    fontSize: 64,
    height: 1,
    letterSpacing: -0.5,
  );

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontWeight: FontWeight.w500,
    fontSize: 32,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: displayFallback,
    fontWeight: FontWeight.w500,
    fontSize: 20,
    height: 1.2,
    letterSpacing: -0.1,
  );

  // Body — system sans (Inter/SF Pro/Roboto fallback).
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

  // Mono — IBM Plex Mono, used for all numbers/labels.
  static const TextStyle monoValue = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 1.2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle monoCaption = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 1.1, // ≈ 0.1em uppercase tracking
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle monoLabel = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 1.3,
    letterSpacing: 0.5,
  );
}
