import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/data/settings_controller.dart';
import '../data/price_live_provider.dart';
import '../domain/price_tick.dart';

/// Price overview — main landing screen (German label: "Kurs").
///
/// Layout follows the Open Design `price-overview-final-3` mockup:
///
///   * **Header**   — logo + currency pill
///   * **Hero**     — large price (Newsreader), trend chip, sats
///   * **Chart**    — timeframe tabs + sparkline (fl_chart)
///   * **Metrics**  — MCAP + All-Time High cards
///   * **Sidebar**  — market insights (only above 1024 px)
///
/// Live price comes from [priceLiveProvider]. Historical/market/ATH
/// inputs are placeholders until the CDN-backed providers land in
/// later Phase-3 sprints.
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
            final isWide =
                constraints.maxWidth >= AppSpacing.wideLayoutBreakpoint;
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
                      _Header(currency: settings.fiatCurrency),
                      const SizedBox(height: AppSpacing.s6),
                      _PriceHero(tickAsync: tickAsync),
                      const SizedBox(height: AppSpacing.s7),
                      _DashboardGrid(showSidebar: isWide),
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

// -- Header -----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SvgPicture.asset(
          'assets/logos/logo-dark.svg',
          width: 32,
          height: 32,
          colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Text(
            AppL10n.of(context).appTitle,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayMedium.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        _CurrencyPill(currency: currency),
      ],
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$currency / BTC',
        style: AppTypography.monoCaption.copyWith(color: scheme.onSurface),
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
                    DateFormat.yMMMd(locale).add_Hm().format(
                          tick.observedAt.toLocal(),
                        ),
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
        const SizedBox(height: AppSpacing.s5),
        const Divider(),
        const SizedBox(height: AppSpacing.s4),
        const _SubPrice(
          // Sats / EUR placeholder until FX rates land.
          value: '— Sats',
          label: 'Wechselkurs · 1 EUR',
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
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s2,
      children: [
        Text(
          price,
          style: AppTypography.displayHero.copyWith(
            color: scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const _TrendChip(),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip();

  @override
  Widget build(BuildContext context) {
    // Placeholder until historyProvider feeds daily delta.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.positive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '▲ —',
        style: AppTypography.monoValue.copyWith(
          color: AppColors.positive,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _SubPrice extends StatelessWidget {
  const _SubPrice({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.monoValue.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          label,
          style: AppTypography.monoLabel.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
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

// -- Dashboard grid ---------------------------------------------------------

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.showSidebar});

  final bool showSidebar;

  @override
  Widget build(BuildContext context) {
    if (!showSidebar) return const _MainColumn();

    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _MainColumn()),
        SizedBox(width: AppSpacing.s4),
        Expanded(child: _Sidebar()),
      ],
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartCard(),
        SizedBox(height: AppSpacing.s4),
        _MetricsRow(),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 560;
        if (stack) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MarketCard(),
              SizedBox(height: AppSpacing.s4),
              _AthCard(),
            ],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _MarketCard()),
            SizedBox(width: AppSpacing.s4),
            Expanded(child: _AthCard()),
          ],
        );
      },
    );
  }
}

// -- Cards ------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.monoLabel.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          child,
        ],
      ),
    );
  }
}

class _ChartCard extends StatefulWidget {
  const _ChartCard();

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  static const _ranges = ['1T', '1W', '1M', '3M', '1J', 'ALL'];
  int _activeRange = 4; // 1J as in mock

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return _Card(
      title: l10n.marketEvolution,
      trailing: Text(
        '+ \$— (${_ranges[_activeRange]})',
        style: AppTypography.monoLabel.copyWith(color: AppColors.positive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _ranges.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
              itemBuilder: (context, i) {
                final isActive = i == _activeRange;
                return GestureDetector(
                  onTap: () => setState(() => _activeRange = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.surfaceContainerHighest
                          : Colors.transparent,
                      border: Border.all(
                        color: isActive ? scheme.outline : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _ranges[i],
                      style: AppTypography.monoCaption.copyWith(
                        color: isActive
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            height: 180,
            child: LineChart(_chartData(scheme.primary)),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(Color primary) {
    // Static placeholder data — replaced by historyProvider in Phase 3.
    const points = <FlSpot>[
      FlSpot(0, 1.0),
      FlSpot(1, 1.1),
      FlSpot(2, 1.05),
      FlSpot(3, 1.25),
      FlSpot(4, 1.4),
      FlSpot(5, 1.3),
      FlSpot(6, 1.55),
      FlSpot(7, 1.45),
      FlSpot(8, 1.7),
      FlSpot(9, 1.85),
      FlSpot(10, 1.8),
      FlSpot(11, 2.05),
      FlSpot(12, 2.3),
      FlSpot(13, 2.2),
      FlSpot(14, 2.45),
      FlSpot(15, 2.7),
      FlSpot(16, 2.6),
      FlSpot(17, 2.9),
      FlSpot(18, 2.85),
      FlSpot(19, 3.1),
    ];
    return LineChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: points,
          color: primary,
          isCurved: true,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: primary.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return _Card(
      title: l10n.marketData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$—',
                style: AppTypography.displayLarge.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'MCAP',
                style: AppTypography.monoCaption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          _InsightPill(
            text: l10n.marketDataInsightPlaceholder,
            accent: AppColors.neutral,
          ),
        ],
      ),
    );
  }
}

class _AthCard extends StatelessWidget {
  const _AthCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return _Card(
      title: l10n.athTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\$—',
            style: AppTypography.displayLarge.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.s2),
          _ProgressMeta(
            left: l10n.athDistance,
            right: '—',
          ),
          const SizedBox(height: AppSpacing.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          _ProgressMeta(left: l10n.athCurrent('—'), right: l10n.athTarget('—')),
        ],
      ),
    );
  }
}

class _ProgressMeta extends StatelessWidget {
  const _ProgressMeta({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTypography.monoLabel.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(left, style: style), Text(right, style: style)],
    );
  }
}

// -- Sidebar ----------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _Card(
      title: l10n.marketInsights,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightPill(
            text: l10n.insightPlaceholderBullish,
            accent: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.s3),
          _InsightPill(
            text: l10n.insightPlaceholderVolatility,
            accent: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.s3),
          _InsightPill(
            text: l10n.insightPlaceholderDominance,
            accent: AppColors.neutral,
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
