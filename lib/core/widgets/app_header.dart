import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'brand_icon.dart';

/// The header every screen carries: the brand lockup on the left, the
/// currency pill and the settings gear on the right.
///
/// **It never names the screen.** The lockup is the wordmark, not a section
/// title — the navigation says which section is open, and a screen that
/// needs to say so in its content carries its own title below the header
/// (settings does, the sections do not).
///
/// **Its composition does not change with the window width.** The gear is
/// the entry point to settings on every width; the navigation rail of #65
/// gets none. There is therefore no breakpoint in here, and no wide
/// variant to keep in sync.
class AppHeader extends StatelessWidget {
  /// The header of a section screen: currency pill, then the gear that
  /// opens `/settings`.
  ///
  /// [currency] is nullable so a section that has no currency to show can
  /// pass `null`; it is `required` so the omission is always deliberate.
  const AppHeader({super.key, required this.currency}) : isSettingsOpen = false;

  /// The header of the settings screen itself: no pill — the currency is
  /// set on this screen — and the gear marks the open screen and closes it.
  const AppHeader.settings({super.key})
    : currency = null,
      isSettingsOpen = true;

  /// ISO 4217 code shown in the pill, or `null` for no pill.
  final String? currency;

  /// Whether this header sits on the settings screen. The gear then renders
  /// in `primary` and leads back instead of forward.
  final bool isSettingsOpen;

  /// Edge of the gear's touch target. The glyph inside it is [gearGlyphSize].
  static const double gearTargetSize = 44;

  /// Glyph size inside the 44 px target, per the design.
  static const double gearGlyphSize = 22;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _BrandLockup()),
        if (currency != null) ...[
          _CurrencyPill(currency: currency!),
          const SizedBox(width: AppSpacing.s1),
        ],
        _SettingsGear(isOpen: isSettingsOpen),
      ],
    );
  }
}

// -- Brand lockup -----------------------------------------------------------

/// Ring mark plus wordmark, mirroring the design system's `BrandLogo`
/// (`.logo-box`): a 32 px mark, a 12 px gap, and the name in the display
/// face at 20 px / weight 500.
///
/// 20 px is not one of the four display roles in [AppTypography] — the
/// wordmark is part of the mark, not a step on the type ramp, so it is
/// stated here rather than promoted into a role nothing else would use.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  static const double markSize = 32;
  static const double wordmarkFontSize = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    // The mark carries the brand orange in its own artwork, so it is not
    // tinted: the two files differ only in the neutral that has to read
    // against the surface behind them.
    final asset = theme.brightness == Brightness.dark
        ? 'assets/logos/logo-dark.svg'
        : 'assets/logos/logo-light.svg';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(asset, width: markSize, height: markSize),
        const SizedBox(width: AppSpacing.s3),
        Flexible(
          child: Text(
            l10n.appTitle,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayMedium.copyWith(
              fontSize: wordmarkFontSize,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// -- Currency pill ----------------------------------------------------------

/// The unit the screen's figures are quoted in.
///
/// It is a label, not a control, until the currency picker lands with #32 —
/// so it carries no tap target and no chevron.
class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l10n.currencyPair(currency),
        style: AppTypography.monoCaption.copyWith(color: scheme.onSurface),
      ),
    );
  }
}

// -- Settings gear ----------------------------------------------------------

class _SettingsGear extends StatelessWidget {
  const _SettingsGear({required this.isOpen});

  final bool isOpen;

  void _onTap(BuildContext context) {
    if (!isOpen) {
      // A push, not a `go`: settings is a task on top of the section, and
      // closing it has to return to the section the user came from.
      context.push(settingsLocation);
      return;
    }
    // Opened by deep link there is nothing to pop back to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(homeLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return Semantics(
      button: true,
      label: l10n.settingsTitle,
      child: Tooltip(
        message: l10n.settingsTitle,
        child: InkWell(
          onTap: () => _onTap(context),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppHeader.gearTargetSize,
            height: AppHeader.gearTargetSize,
            child: Center(
              child: BrandIcon(
                UiGlyph.settings,
                size: AppHeader.gearGlyphSize,
                color: isOpen ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
