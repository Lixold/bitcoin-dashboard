import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/nav_section.dart';

/// Floating pill anchored to the bottom-centre of the shell. The icon
/// container shows the active section; tapping the pill is supposed to
/// open the [NavBottomSheet].
class DynamicNavPill extends StatelessWidget {
  const DynamicNavPill({super.key, required this.active, required this.onTap});

  final NavSection active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return Semantics(
      button: true,
      label: l10n.navOpenMenu,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(color: scheme.outline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillIcon(section: active),
                const SizedBox(width: 12),
                Text(
                  active.label(l10n),
                  style: AppTypography.displayMedium.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({required this.section});

  final NavSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        section.asset,
        width: 28,
        height: 28,
        colorFilter: const ColorFilter.mode(
          AppColors.darkOnPrimary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
