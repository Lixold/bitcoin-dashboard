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
}
