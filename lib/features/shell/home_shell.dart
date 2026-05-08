import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../price/presentation/price_overview_screen.dart';
import '../settings/presentation/settings_screen.dart';

/// Top-level shell with adaptive navigation:
///
///   * width <  600 → bottom NavigationBar (mobile)
///   * width >= 600 → side NavigationRail (tablet/desktop)
///
/// Tabs that aren't implemented yet show a `Coming soon` placeholder. They
/// stay in the navigation so the information architecture is visible from
/// day one and contributors know where each feature lives.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final destinations = <_Destination>[
      _Destination(
        icon: Icons.show_chart,
        label: l10n.navPrice,
        page: const PriceOverviewScreen(),
      ),
      _Destination(
        icon: Icons.link,
        label: l10n.navOnChain,
        page: _ComingSoon(label: l10n.navOnChain),
      ),
      _Destination(
        icon: Icons.article_outlined,
        label: l10n.navNews,
        page: _ComingSoon(label: l10n.navNews),
      ),
      _Destination(
        icon: Icons.settings_outlined,
        label: l10n.navSettings,
        page: const SettingsScreen(),
      ),
    ];

    final body = IndexedStack(
      index: _index,
      children: destinations.map((d) => d.page).toList(),
    );

    final wide = MediaQuery.sizeOf(context).width >= 600;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.label,
    required this.page,
  });
  final IconData icon;
  final String label;
  final Widget page;
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Text(
          l10n.comingSoon,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
