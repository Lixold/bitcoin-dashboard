import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/nav_section.dart';
import '../domain/navigation_layout.dart';

/// The app's navigation, in the shape [layout] asks for.
///
/// One widget for all three expressions because they are one control: the
/// same destinations, in the same order, with the same selected index. The
/// index is the position in [sections], which is
/// [NavSection.visible] — and therefore also the router's branch order, so
/// [selectedIndex] can be handed straight to `goBranch`.
///
/// **The set is the same at every width.** A rail is not a place to hide a
/// destination the bar shows, and there is no overflow: the design system
/// keeps a section out of the navigation until its first slice has
/// shipped, so a "More" entry would have nothing to carry that is not
/// already here.
///
/// **It carries no settings gear.** The gear lives in `AppHeader` on every
/// width — see the note there. The design system draws one in the rail's
/// trailing slot and the drawer's footer; the repository decided against a
/// second entry point and that decision stands (CLAUDE.md §9).
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.layout,
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  final NavigationLayout layout;

  /// Destinations in branch order.
  final List<NavSection> sections;

  /// Index into [sections] of the section currently on screen.
  final int selectedIndex;

  /// Called with the index into [sections] that was chosen — including
  /// when the already-selected destination is chosen again.
  final ValueChanged<int> onSelect;

  /// Height of the bottom bar: a 44 px touch target (the design system's
  /// `--touch-min`) with `s2` above and below it. Material's default is 80,
  /// which is taller than the design draws it.
  static const double barHeight = 44 + AppSpacing.s2 * 2;

  /// Rail width, from the design system's `.nav-rail`. It is a minimum:
  /// `NavigationRail` grows past it rather than clipping a long label.
  static const double railWidth = 80;

  /// Drawer width, from the design system's `.nav-drawer`. Material's
  /// default `Drawer` is 304 — that is a modal drawer over content, not a
  /// permanent panel beside it.
  static const double drawerWidth = 240;

  /// Glyph size in every expression.
  static const double glyphSize = 24;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      NavigationLayout.bar => _Bar(
        sections: sections,
        selectedIndex: selectedIndex,
        onSelect: onSelect,
      ),
      NavigationLayout.rail => _Rail(
        sections: sections,
        selectedIndex: selectedIndex,
        onSelect: onSelect,
      ),
      NavigationLayout.drawer => _Drawer(
        sections: sections,
        selectedIndex: selectedIndex,
        onSelect: onSelect,
      ),
    };
  }
}

/// Label of a destination in the bar and the rail: the design system's
/// `.nav-dest__label` — mono, 10 px, uppercase, `--track-menu` tracking,
/// which is what [AppTypography.monoLabel] already is.
///
/// The uppercase is presentation, exactly as `text-transform` is in the
/// design system's CSS. The ARB keeps the section names in sentence case
/// so a locale that must not be shouted can be given one.
String _navLabel(NavSection section, AppL10n l10n) =>
    section.label(l10n).toUpperCase();

// -- Bottom bar --------------------------------------------------------------

class _Bar extends StatelessWidget {
  const _Bar({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<NavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: scheme.outline),
        NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          height: AppNavigation.barHeight,
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          // The design system marks the active destination in `--primary`
          // and draws no pill behind it.
          indicatorColor: Colors.transparent,
          indicatorShape: const StadiumBorder(),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => AppTypography.monoLabel.copyWith(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          destinations: [
            for (final section in sections)
              NavigationDestination(
                icon: BrandIcon(
                  section,
                  size: AppNavigation.glyphSize,
                  color: scheme.onSurfaceVariant,
                ),
                selectedIcon: BrandIcon(
                  section,
                  size: AppNavigation.glyphSize,
                  color: scheme.primary,
                ),
                label: _navLabel(section, l10n),
                // The label is already the accessible name; a tooltip
                // repeating it would only get in the way of a touch.
                tooltip: '',
              ),
          ],
        ),
      ],
    );
  }
}

// -- Rail --------------------------------------------------------------------

class _Rail extends StatelessWidget {
  const _Rail({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<NavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          minWidth: AppNavigation.railWidth,
          backgroundColor: scheme.surface,
          // `NavigationRail` rejects an explicit 0 — its Material 3 default
          // is flat already, and the hairline beside it is the only edge
          // the design system draws.
          groupAlignment: -1,
          // Every destination is labelled, the selected one included: the
          // header shows the wordmark and never the section, so an
          // icon-only rail would leave the screen unnamed.
          labelType: NavigationRailLabelType.all,
          useIndicator: false,
          unselectedLabelTextStyle: AppTypography.monoLabel.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          selectedLabelTextStyle: AppTypography.monoLabel.copyWith(
            color: scheme.primary,
          ),
          destinations: [
            for (final section in sections)
              NavigationRailDestination(
                icon: BrandIcon(
                  section,
                  size: AppNavigation.glyphSize,
                  color: scheme.onSurfaceVariant,
                ),
                selectedIcon: BrandIcon(
                  section,
                  size: AppNavigation.glyphSize,
                  color: scheme.primary,
                ),
                label: Text(_navLabel(section, l10n)),
              ),
          ],
        ),
        VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
      ],
    );
  }
}

// -- Drawer ------------------------------------------------------------------

class _Drawer extends StatelessWidget {
  const _Drawer({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<NavSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return Row(
      children: [
        DrawerTheme(
          // `NavigationDrawer` builds itself into a `Drawer`, which is
          // shaped for the modal case: 304 wide, elevated, rounded on the
          // trailing edge. This is a permanent panel, so it takes the
          // design system's width and sits flat against the content with
          // the same hairline the rail has.
          data: DrawerThemeData(
            width: AppNavigation.drawerWidth,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: const RoundedRectangleBorder(),
          ),
          child: NavigationDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            backgroundColor: scheme.surface,
            // Unlike the bar and the rail, the drawer does mark the active
            // row with a fill: the design system's `--tint-menu-active`,
            // 12 % primary over the variant surface.
            indicatorColor: Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.12),
              scheme.surfaceContainerHighest,
            ),
            indicatorShape: const StadiumBorder(),
            children: [
              // Non-destination children do not count towards the
              // destination index, so this spacer cannot shift the
              // mapping onto the router's branches.
              const SizedBox(height: AppSpacing.s5),
              for (final (index, section) in sections.indexed)
                NavigationDrawerDestination(
                  icon: BrandIcon(
                    section,
                    size: AppNavigation.glyphSize,
                    color: scheme.onSurfaceVariant,
                  ),
                  selectedIcon: BrandIcon(
                    section,
                    size: AppNavigation.glyphSize,
                    color: scheme.primary,
                  ),
                  // The drawer has room for a readable row, so its label
                  // is body text rather than the mono caption the bar and
                  // the rail use.
                  label: Text(
                    section.label(l10n),
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      color: index == selectedIndex
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
      ],
    );
  }
}
