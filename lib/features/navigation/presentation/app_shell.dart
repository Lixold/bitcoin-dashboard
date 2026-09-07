import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/nav_section.dart';
import '../domain/navigation_layout.dart';
import 'app_navigation.dart';

/// Top-level shell: the active section's navigator, with the navigation
/// beside it or below it depending on how wide the window is.
///
/// The shell does not own the active section: it is the builder of the
/// router's [StatefulShellRoute], and the section is read from
/// [StatefulNavigationShell.currentIndex]. Section order is
/// [NavSection.visible] on both sides — the router builds one branch per
/// entry, in that order, and [AppNavigation] lists its destinations in the
/// same order, so a destination index *is* a branch index.
///
/// The navigation is chrome, never an overlay: on a narrow window the bar
/// is the scaffold's `bottomNavigationBar` and the body ends above it; on
/// a wide one the rail or drawer takes its width out of the row. Neither
/// covers the content — which is what the floating pill this replaces did.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Switches to the branch at [index].
  ///
  /// Re-selecting the active section resets its branch to the section
  /// root; any other choice resumes that branch where it was left.
  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The window, not a `LayoutBuilder` box: the rail and the drawer take
    // width out of that box themselves, so measuring inside it would let
    // the navigation's own width decide which navigation is shown.
    final layout = NavigationLayout.forWidth(MediaQuery.sizeOf(context).width);

    final navigation = AppNavigation(
      layout: layout,
      sections: NavSection.visible(),
      selectedIndex: navigationShell.currentIndex,
      onSelect: _select,
    );

    if (layout == NavigationLayout.bar) {
      return Scaffold(body: navigationShell, bottomNavigationBar: navigation);
    }

    return Scaffold(
      body: Row(
        children: [
          navigation,
          // The branch navigators are `Navigator`s, and a `Navigator`'s
          // route barrier blocks the semantics of everything painted
          // before it. The rail and the drawer are painted before the
          // body, so without a boundary of its own here the whole
          // navigation drops out of the accessibility tree — visible on
          // screen, invisible to a screen reader. The bottom bar is not
          // affected: the scaffold paints it after the body.
          Expanded(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: navigationShell,
            ),
          ),
        ],
      ),
    );
  }
}
