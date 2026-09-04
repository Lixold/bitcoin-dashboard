import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Asset hygiene, next to the bundling check in `brand_icon_test.dart`:
/// both ask whether a file in `assets/` is fit to ship, not whether a
/// widget behaves.
///
/// Claude Design signs a C2PA manifest into every file it saves, so a
/// pulled glyph arrives with roughly 14 KB of base64 that renders nothing,
/// ships in the bundle on all five platforms, and changes on every export.
/// The boundary this enforces is stated once, in CLAUDE.md §9.

/// What the failure has to tell the next session, because guessing here
/// costs an hour and an SVG optimiser breaks the normalised comparison.
const String _howToFix =
    'Remove the <metadata> element and the xmlns:c2pa attribute on <svg>, '
    'and nothing else. Do not run an SVG optimiser: it rewrites the '
    'serialisation and breaks the normalised comparison against the design '
    'system (CLAUDE.md §9). The manifest is re-signed on every save in '
    'Claude Design, so this is a step of every pull, not a one-off.';

final RegExp _c2paNamespace = RegExp(r'xmlns:c2pa\b');
final RegExp _metadataElement = RegExp(r'<metadata[\s>/]');

void main() {
  test('no bundled asset carries generator metadata', () {
    final assets = Directory('assets');
    expect(
      assets.existsSync(),
      isTrue,
      reason: 'assets/ not found — `flutter test` runs from the package root',
    );

    final files = assets.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    // A scan that reads nothing passes for the wrong reason.
    expect(files, isNotEmpty, reason: 'assets/ holds no files to check');

    final offenders = <String>[];
    for (final file in files) {
      // Byte-level, via latin1, so a binary asset is scanned too instead
      // of throwing on a UTF-8 decode.
      final source = latin1.decode(file.readAsBytesSync());
      final found = <String>[
        if (_c2paNamespace.hasMatch(source)) 'xmlns:c2pa',
        if (_metadataElement.hasMatch(source)) '<metadata>',
      ];
      if (found.isNotEmpty) {
        offenders.add('${file.path} carries ${found.join(' and ')}');
      }
    }

    expect(offenders, isEmpty, reason: _howToFix);
  });
}
