import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/navigation/domain/nav_section.dart';
import '../../features/navigation/presentation/app_shell.dart';
import '../../features/navigation/presentation/coming_soon_screen.dart';
import '../../features/network/presentation/network_screen.dart';
import '../../features/price/presentation/price_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Location of the section the app opens on, and the target for any request
/// that does not match a route.
String get homeLocation => NavSection.visible().first.location;

/// Settings sits outside the shell: it covers the whole screen, including the
/// floating pill, and is not one of the sections.
///
/// The gear in `AppHeader` pushes this location, so settings opens on top of
/// the section the user was in and closing it returns there. The navigation
/// still does not list it: it is a task, not a destination.
const String settingsLocation = '/settings';

/// Builds the app's routing table.
///
/// **One branch per *reachable* section.** The branch list follows
/// [NavSection.visible], so `/forecast` and `/miner` — which render nothing
/// but a placeholder and cannot be opened from the UI — get no route. Giving
/// them one would make placeholder surface deep-linkable, which CLAUDE.md §5
/// rules out. When #65 turns `isVisibleInPhase3` into `hasShippedSlice`, the
/// branches follow that flag without a change here.
///
/// [StatefulShellRoute.indexedStack] (rather than a plain `ShellRoute`) gives
/// every section its own [Navigator]: its own back stack, and scroll and load
/// state that survive leaving the section. It is also the construction the
/// `NavigationBar` / `NavigationRail` of #65 attach to.
GoRouter createAppRouter({String? initialLocation}) {
  final sections = NavSection.visible();

  return GoRouter(
    initialLocation: initialLocation ?? homeLocation,
    // Makes the router's navigators restorable, so a branch can bring its own
    // stack back after the platform kills the app. The location itself is
    // restored through `restorationScopeId` on MaterialApp.router.
    restorationScopeId: 'app_router',
    redirect: (context, state) => state.uri.path == '/' ? homeLocation : null,
    // No error screen ships in this PR: an unknown deep link lands on the
    // home section instead of a page we have neither a design nor
    // translations for.
    onException: (context, state, router) => router.go(homeLocation),
    routes: [
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'app_shell',
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final section in sections)
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

Widget _screenFor(NavSection section) => switch (section) {
  NavSection.price => const PriceScreen(),
  NavSection.network => const NetworkScreen(),
  NavSection.market ||
  NavSection.forecast ||
  NavSection.miner ||
  NavSection.news => ComingSoonScreen(section: section),
};
