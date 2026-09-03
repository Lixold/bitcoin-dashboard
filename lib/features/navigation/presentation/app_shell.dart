import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/nav_section.dart';
import 'dynamic_nav_pill.dart';
import 'nav_bottom_sheet.dart';

/// Top-level shell. The body is the active section's navigator; a floating
/// pill at the bottom-centre opens the nav sheet to switch sections.
///
/// The shell no longer owns the active section: it is the builder of the
/// router's [StatefulShellRoute], and the section is read from
/// [StatefulNavigationShell.currentIndex]. Section order is
/// [NavSection.visible] on both sides — the router builds one branch per
/// entry, in that order.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  NavSection get _active => NavSection.visible()[navigationShell.currentIndex];

  Future<void> _openMenu(BuildContext context) async {
    await NavBottomSheet.show(
      context: context,
      active: _active,
      sections: NavSection.visible(),
      onSelect: _select,
    );
  }

  void _select(NavSection section) {
    final index = NavSection.visible().indexOf(section);
    if (index < 0) return;
    // Re-selecting the active section resets its branch to the section root;
    // any other tap resumes that branch where it was left.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.s5 + MediaQuery.viewPaddingOf(context).bottom,
            child: Center(
              child: DynamicNavPill(
                active: _active,
                onTap: () => _openMenu(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
