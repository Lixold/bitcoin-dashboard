/// Facts about the build that the About section states.
///
/// These are identifiers, not copy: they read the same in every locale, so
/// they live here rather than in the ARB files. The sentences around them
/// are localised.
///
/// [version] duplicates `pubspec.yaml`. Flutter cannot read the manifest
/// back at runtime without a plugin, and a plugin for one string is not
/// worth the dependency — `test/core/app_info_test.dart` fails when the
/// two drift apart.
class AppInfo {
  AppInfo._();

  /// Marketing version, without the build number.
  static const String version = '0.1.0';

  /// SPDX identifier of the licence in `LICENSE`.
  static const String licence = 'MIT';

  /// The public sources this build actually reads.
  ///
  /// One entry, because one is what the app fetches today. The README and
  /// [ADR-0002](docs/adr/0002-data-sources-and-apis.md) list every source
  /// the product will use; naming those here would tell the user about
  /// requests this binary never makes. Extend it in the slice that adds
  /// the source, not before.
  static const String dataSources = 'Binance Public API';

  static const String repository = 'github.com/Lixold/bitcoin-dashboard';

  static const String newIssue =
      'github.com/Lixold/bitcoin-dashboard/issues/new';

  /// The addresses above in the absolute form the platform browser needs.
  ///
  /// Derived from the string the row prints rather than written out a
  /// second time: a row that shows one address and opens another is a lie
  /// no compiler catches, and `test/core/app_info_test.dart` holds the
  /// two ends together. The scheme is added here and not in the widget —
  /// assembling a URL next to a tap handler is how the two drift apart.
  static Uri get repositoryUrl => _https(repository);

  static Uri get newIssueUrl => _https(newIssue);

  /// Where [licence] can be read in full.
  ///
  /// The `LICENSE` file in this repository, not a generic SPDX page: the
  /// file names the copyright holder and the year, which is exactly what
  /// the three letters on the row leave out. It also keeps the About
  /// group pointing at one address that this build is actually published
  /// from.
  static Uri get licenceUrl => _https('$repository/blob/main/LICENSE');

  static Uri _https(String address) => Uri.parse('https://$address');
}
