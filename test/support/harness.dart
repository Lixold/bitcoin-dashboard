/// The shared widget-test harness.
///
/// One import for everything a screen test needs: [pumpApp] and its two
/// siblings for the tree, [setUpTestHive] for the boxes a screen reads,
/// [TestView] and [useView] for the window, [asyncLoading]/[asyncError]/
/// [asyncData] for the three states, and [loadJsonFixture] for a captured
/// payload.
///
/// Documented in CLAUDE.md §7, including which tests deliberately do not
/// use it.
library;

export 'app_harness.dart';
export 'fixtures.dart';
export 'provider_states.dart';
export 'test_hive.dart';
export 'test_views.dart';
