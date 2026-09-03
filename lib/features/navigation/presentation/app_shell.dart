import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../price/presentation/price_screen.dart';
import '../domain/nav_section.dart';
import 'dynamic_nav_pill.dart';
import 'nav_bottom_sheet.dart';

/// Top-level shell. The body is the active section; a floating pill at the
/// bottom-centre opens the nav sheet to switch sections.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavSection _active = NavSection.price;

  Future<void> _openMenu() async {
    await NavBottomSheet.show(
      context: context,
      active: _active,
      sections: NavSection.visible(),
      onSelect: (s) => setState(() => _active = s),
    );
  }

  Widget _bodyFor(NavSection section) {
    return switch (section) {
      NavSection.price => const PriceScreen(),
      NavSection.market ||
      NavSection.forecast ||
      NavSection.network ||
      NavSection.miner ||
      NavSection.news => _ComingSoon(section: section),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _bodyFor(_active)),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.s5 + MediaQuery.viewPaddingOf(context).bottom,
            child: Center(
              child: DynamicNavPill(active: _active, onTap: _openMenu),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.section});

  final NavSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(section.label(l10n), style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.s2),
            Text(
              l10n.comingSoon,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
