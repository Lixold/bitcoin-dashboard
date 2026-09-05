import 'dart:io';

import 'package:bitcoin_dashboard/core/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// The About section states two facts the repository also states
/// elsewhere. Nothing in the app can read them back at runtime, so the
/// duplication is checked here instead of trusted.
void main() {
  test('the stated version is the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml declares no version');
    expect(
      AppInfo.version,
      match!.group(1),
      reason:
          'AppInfo.version and pubspec.yaml have drifted apart — the About '
          'section would state the wrong version',
    );
  });

  test('the stated licence is the licence in LICENSE', () {
    final licence = File('LICENSE').readAsStringSync();

    expect(
      licence,
      contains(AppInfo.licence),
      reason: 'LICENSE does not name ${AppInfo.licence}',
    );
  });
}
