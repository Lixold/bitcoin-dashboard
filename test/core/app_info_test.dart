import 'dart:io';

import 'package:bitcoin_dashboard/core/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// The About section states two facts the repository also states
/// elsewhere. Nothing in the app can read them back at runtime, so the
/// duplication is checked here instead of trusted.
///
/// Since #81 the section also opens three of its rows, which adds a
/// second kind of drift to guard: a row that prints one address and hands
/// another to the browser. The tests below hold the printed string and
/// the launched [Uri] together.
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

  group('every address the About group opens', () {
    final urls = <String, Uri>{
      'repository': AppInfo.repositoryUrl,
      'new issue': AppInfo.newIssueUrl,
      'licence': AppInfo.licenceUrl,
    };

    test('is absolute and reaches GitHub over https', () {
      urls.forEach((name, url) {
        expect(url.isAbsolute, isTrue, reason: '$name has no scheme');
        expect(url.scheme, 'https', reason: name);
        expect(url.host, 'github.com', reason: name);
      });
    });

    test('is the address its row prints', () {
      expect(AppInfo.repositoryUrl.toString(), endsWith(AppInfo.repository));
      expect(AppInfo.newIssueUrl.toString(), endsWith(AppInfo.newIssue));
    });
  });

  test('the licence row opens the licence this build ships under', () {
    // Not opensource.org: the row states the SPDX identifier, and the
    // file behind it is what adds the holder and the year the identifier
    // leaves out.
    expect(AppInfo.licenceUrl.path, endsWith('/LICENSE'));
    expect(
      AppInfo.licenceUrl.toString(),
      startsWith('https://${AppInfo.repository}/'),
      reason: 'the licence of this repository, not a copy somewhere else',
    );
  });
}
