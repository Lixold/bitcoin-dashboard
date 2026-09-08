import 'dart:convert';
import 'dart:io';

/// Reads one document from `test/support/fixtures/`.
///
/// The files there are captures of what the CDN actually served — values
/// untouched, reformatted only so a diff is readable — so a test reads the
/// document the app reads rather than a hand-written approximation of it.
/// A capture carries the moment it was taken in `_meta.fetchedAt`, which
/// only stays meaningful next to a frozen clock: see `pumpApp(now:)`.
///
/// **Nothing here validates a fixture against the payload contract.** That
/// is issue #42, and this directory is the place it will point at — it
/// adds the schema check, this loader stays as it is.
///
/// The path is relative because `flutter test` runs from the package root.
Map<String, dynamic> loadJsonFixture(String name) {
  final file = File('test/support/fixtures/$name');
  if (!file.existsSync()) {
    throw StateError('No fixture at ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
