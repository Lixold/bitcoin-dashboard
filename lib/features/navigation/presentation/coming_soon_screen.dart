import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/nav_section.dart';

/// Body of a section whose slice has not shipped yet.
///
/// Extracted from `AppShell` unchanged when the shell became a route
/// builder — the router, not the shell, now decides which body a section
/// gets.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.section});

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
