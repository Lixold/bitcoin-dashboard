import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_header.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/data/settings_controller.dart';
import '../data/price_live_provider.dart';
import '../domain/price_tick.dart';

/// Price overview — main landing screen (German label: "Kurs").
///
/// Layout follows the Claude Design `price-overview-final-3` mockup:
///
///   * **Header** — the shared [AppHeader]: brand lockup, currency pill,
///     settings gear
///   * **Hero**   — live price (display serif) with observation timestamp
///
/// Live price comes from [priceLiveProvider]. Chart, market data, ATH
/// and insights arrive in later Phase-3 slices, once their CDN-backed
/// providers exist.
class PriceScreen extends ConsumerWidget {
  const PriceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(priceLiveProvider);
    final settings = ref.watch(settingsControllerProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(priceLiveProvider),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPad =
                constraints.maxWidth >= AppSpacing.tabletBreakpoint
                ? AppSpacing.screenMarginTablet
                : AppSpacing.screenMarginMobile;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.s5,
                horizontalPad,
                // Leave room for the floating pill (44 + 24 anchor + margins).
                AppSpacing.s7 * 2.5,
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppHeader(currency: settings.fiatCurrency),
                      const SizedBox(height: AppSpacing.s6),
                      _PriceHero(tickAsync: tickAsync),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -- Price hero -------------------------------------------------------------

class _PriceHero extends StatelessWidget {
  const _PriceHero({required this.tickAsync});

  final AsyncValue<PriceTick> tickAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: r'$',
      decimalDigits: 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LiveDot(color: AppColors.positive),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: tickAsync.when(
                data: (tick) => Text(
                  l10n.priceHeroLabel(
                    DateFormat.yMMMd(
                      locale,
                    ).add_Hm().format(tick.observedAt.toLocal()),
                  ),
                  style: AppTypography.monoCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                loading: () => Text(
                  l10n.priceLoading,
                  style: AppTypography.monoCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                error: (_, _) => Text(
                  l10n.priceError,
                  style: AppTypography.monoCaption.copyWith(
                    color: AppColors.negative,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        tickAsync.when(
          data: (tick) => _PriceLine(price: currencyFormat.format(tick.price)),
          loading: () => _PriceLine(price: currencyFormat.format(0)),
          error: (_, _) => Text(
            l10n.priceError,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      price,
      style: AppTypography.displayHero.copyWith(
        color: scheme.onSurface,
        fontSize: AppTypography.heroFontSize(MediaQuery.sizeOf(context).width),
        fontFeatures: AppTypography.figureFeatures,
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
