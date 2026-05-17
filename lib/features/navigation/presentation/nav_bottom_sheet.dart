import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/nav_section.dart';

/// Slide-up sheet listing all visible navigation sections.
///
/// The curve `Cubic(0.16, 1, 0.3, 1)` over 400 ms matches the
/// design-system motion token used in the Open Design mockups.
class NavBottomSheet extends StatelessWidget {
  const NavBottomSheet({
    super.key,
    required this.active,
    required this.sections,
    required this.onSelect,
  });

  final NavSection active;
  final List<NavSection> sections;
  final ValueChanged<NavSection> onSelect;

  /// Curve declared once so tests and animations stay aligned.
  static const Curve transitionCurve = Cubic(0.16, 1, 0.3, 1);
  static const Duration transitionDuration = Duration(milliseconds: 400);

  /// Show the sheet via [Navigator] using the design-system curve.
  static Future<void> show({
    required BuildContext context,
    required NavSection active,
    required List<NavSection> sections,
    required ValueChanged<NavSection> onSelect,
  }) {
    return Navigator.of(context).push(
      _NavSheetRoute(
        active: active,
        sections: sections,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Material(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        // Extra bottom padding leaves room for the floating pill that the
        // sheet sits in front of.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s6,
          AppSpacing.s5,
          AppSpacing.s5 + viewPadding.bottom + 96,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              l10n.navSectionsHeader,
              textAlign: TextAlign.center,
              style: AppTypography.monoCaption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            _SectionGrid(
              active: active,
              sections: sections,
              onSelect: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.active,
    required this.sections,
    required this.onSelect,
  });

  final NavSection active;
  final List<NavSection> sections;
  final ValueChanged<NavSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 6 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.s5,
          crossAxisSpacing: AppSpacing.s4,
          childAspectRatio: 0.85,
          children: [
            for (final s in sections)
              _SectionTile(
                section: s,
                isActive: s == active,
                onTap: () => onSelect(s),
              ),
          ],
        );
      },
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.isActive,
    required this.onTap,
  });

  final NavSection section;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    final tint = isActive ? scheme.primary : scheme.onSurface;
    final border = isActive ? scheme.primary : scheme.outline;
    final bg = isActive
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12),
            scheme.surfaceContainerHighest)
        : scheme.surfaceContainerHighest;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              section.asset,
              width: 34,
              height: 34,
              colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            section.label(l10n),
            style: AppTypography.monoLabel.copyWith(
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSheetRoute<T> extends PopupRoute<T> {
  _NavSheetRoute({
    required this.active,
    required this.sections,
    required this.onSelect,
  });

  final NavSection active;
  final List<NavSection> sections;
  final ValueChanged<NavSection> onSelect;

  @override
  Color? get barrierColor => const Color(0xB3000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => NavBottomSheet.transitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: NavBottomSheet(
          active: active,
          sections: sections,
          onSelect: (section) {
            onSelect(section);
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: NavBottomSheet.transitionCurve,
      reverseCurve: NavBottomSheet.transitionCurve.flipped,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
