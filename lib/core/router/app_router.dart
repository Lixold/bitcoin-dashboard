import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/navigation/domain/nav_section.dart';
import '../../features/navigation/presentation/app_shell.dart';
import '../../features/market/presentation/market_screen.dart';
import '../../features/network/presentation/network_screen.dart';
import '../../features/price/presentation/price_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Location of the section the shipped app opens on.
///
/// For widgets that need the way home without a router in hand — the header
/// gear, when settings was opened by deep link and there is nothing to pop.
/// The router derives its own home from the section list it was built with,
/// which is the same list here and a test's list in a test.
String get homeLocation => NavSection.visible().first.location;

/// Settings sits outside the shell: it covers the whole screen, navigation
/// included, and is not one of the sections.
///
/// The gear in `AppHeader` pushes this location, so settings opens on top of
/// the section the user was in and closing it returns there. The navigation
/// still does not list it: it is a task, not a destination.
const String settingsLocation = '/settings';

/// Builds the app's routing table.
///
/// **One branch per section with a shipped slice.** [sections] is that list
/// — [NavSection.visible] in the app — and it is the only list in play: the
/// branches are built from it in order, and [AppShell] is handed the same
/// list for its destinations, so a destination index *is* a branch index.
/// A section that has not shipped gets no route at all, because a route
/// would make surface that renders nothing deep-linkable, which CLAUDE.md §5
/// rules out. Passing [sections] is what lets a test watch a section lose
/// and gain its destination without a second list to keep in step.
///
/// [StatefulShellRoute.indexedStack] (rather than a plain `ShellRoute`) gives
/// every section its own [Navigator]: its own back stack, and scroll and load
/// state that survive leaving the section.
GoRouter createAppRouter({
  String? initialLocation,
  List<NavSection>? sections,
}) {
  final branches = sections ?? NavSection.visible();
  final home = branches.first.location;

  return GoRouter(
    initialLocation: initialLocation ?? home,
    // Makes the router's navigators restorable, so a branch can bring its own
    // stack back after the platform kills the app. The location itself is
    // restored through `restorationScopeId` on MaterialApp.router.
    restorationScopeId: 'app_router',
    redirect: (context, state) => state.uri.path == '/' ? home : null,
    // No error screen ships in this PR: an unknown deep link lands on the
    // home section instead of a page we have neither a design nor
    // translations for. `/news`, `/forecast` and `/miner` arrive here for as
    // long as they have no slice.
    onException: (context, state, router) => router.go(home),
    routes: [
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'app_shell',
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell, sections: branches),
        branches: [
          for (final section in branches)
            StatefulShellBranch(
              restorationScopeId: 'branch_${section.id}',
              routes: [
                GoRoute(
                  path: section.location,
                  builder: (context, state) => _screenFor(section),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: settingsLocation,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

/// The router is built once and kept for the lifetime of the app.
///
/// `BitcoinDashboardApp` rebuilds whenever locale or theme mode change. A
/// router constructed inside that build would be replaced on every theme
/// switch and drop the user back to the initial location — hence a provider
/// rather than a `build()` local.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// The body of a section.
///
/// Only sections with a shipped slice reach this: [createAppRouter] builds
/// no branch for the others, so the last case cannot be hit by the app. It
/// throws rather than rendering a placeholder, which is the difference this
/// change is about — a section without a slice is absent, not empty.
///
/// The two ways that can go wrong are both caught before a user sees them.
/// A seventh section added to the enum is an analyzer error here, because
/// the switch is exhaustive over [NavSection]. A flag flipped to
/// `hasShippedSlice: true` without a screen to go with it fails
/// `test/core/router/app_router_test.dart`, which opens every section
/// [NavSection.visible] returns.
Widget _screenFor(NavSection section) => switch (section) {
  NavSection.price => const PriceScreen(),
  NavSection.market => const MarketScreen(),
  NavSection.network => const NetworkScreen(),
  NavSection.forecast ||
  NavSection.miner ||
  NavSection.news => throw StateError(
    'Section ${section.id} has no shipped slice and therefore no branch; '
    'createAppRouter must not have been given it.',
  ),
};
