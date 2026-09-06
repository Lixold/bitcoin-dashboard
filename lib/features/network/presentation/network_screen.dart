import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/domain/nav_section.dart';
import '../data/network_pools_provider.dart';
import '../domain/mining_pool.dart';
import '../domain/network_health_snapshot.dart';
import '../domain/pool_concentration.dart';
import 'pool_share_list.dart';
import 'share_format.dart';

/// Network section — currently one statement: how concentrated mining is.
///
/// The other network figures (full-node count, aggregate health, hashrate
/// trend, block time, difficulty) are each their own slice and are not
/// stubbed here. A section with one finished statement is the shape
/// CLAUDE.md §5 asks for; a section with one statement and five dashes is
/// not.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(networkPoolsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(networkPoolsProvider),
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
                // Clears the floating pill, per the slice design.
                132,
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No currency pill: this section quotes shares of
                      // hashrate, which no fiat unit applies to.
                      const AppHeader(currency: null),
                      const SizedBox(height: AppSpacing.s6),
                      poolsAsync.when(
                        loading: () => const _PoolsLoading(),
                        error: (_, _) => _PoolsError(
                          onRetry: () => ref.invalidate(networkPoolsProvider),
                        ),
                        data: (snapshot) => _PoolsStatement(snapshot: snapshot),
                      ),
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

// -- Data -------------------------------------------------------------------

class _PoolsStatement extends StatelessWidget {
  const _PoolsStatement({required this.snapshot});

  final NetworkHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final now = DateTime.now();
    final isStale = snapshot.isStaleAt(now);
    final stamp = DateFormat.yMMMd(
      locale,
    ).add_Hm().format(snapshot.fetchedAt.toLocal());

    final concentration = PoolConcentration.from(snapshot.pools);
    final sorted = PoolConcentration.sortedByShare(snapshot.pools);
    final topPool = sorted.isEmpty ? null : sorted.first;

    final tone = switch (concentration?.verdict) {
      ConcentrationVerdict.ok => StatementTone.positive,
      ConcentrationVerdict.warning => StatementTone.warning,
      ConcentrationVerdict.critical => StatementTone.negative,
      null => StatementTone.neutral,
    };

    return Statement(
      category: StatementCategory(
        label: l10n.networkPoolsCategory,
        isLive: !isStale,
        trailing: [l10n.networkPoolsAsOf(stamp)],
      ),
      notice: isStale
          ? _StaleNotice(
              hours: now.toUtc().difference(snapshot.fetchedAt).inHours,
              stamp: stamp,
            )
          : null,
      verdict: concentration == null
          ? null
          : StatementVerdict(
              verdict: _verdictLabel(l10n, concentration.verdict),
              badgeLabel: _badgeLabel(l10n, concentration.verdict),
              tone: tone,
              infoLabel: l10n.networkPoolsInfoTrigger,
              onInfo: () => _showInfo(context),
            ),
      figures: topPool == null
          ? null
          : _Figures(
              topPool: topPool,
              concentration: concentration,
              tone: tone,
              locale: locale,
            ),
      insight: concentration == null
          ? null
          : InsightPill(
              category: concentration.verdict == ConcentrationVerdict.ok
                  ? l10n.networkPoolsInsightCategoryOk
                  : l10n.networkPoolsInsightCategoryAlert,
              text: _insightText(l10n, locale, concentration),
              tone: tone,
            ),
      evidence: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (concentration == null) ...[
            _EmptyNotice(count: snapshot.pools.length),
            const SizedBox(height: AppSpacing.s5),
          ],
          PoolShareList(
            pools: sorted,
            topThreeShare: concentration?.topThreeShare,
            listedShare: sorted.fold<double>(
              0,
              (sum, pool) => sum + pool.hashratePercent,
            ),
            tone: tone,
          ),
        ],
      ),
    );
  }

  String _verdictLabel(AppL10n l10n, ConcentrationVerdict verdict) =>
      switch (verdict) {
        ConcentrationVerdict.ok => l10n.networkPoolsVerdictOk,
        ConcentrationVerdict.warning => l10n.networkPoolsVerdictWarning,
        ConcentrationVerdict.critical => l10n.networkPoolsVerdictCritical,
      };

  String _badgeLabel(AppL10n l10n, ConcentrationVerdict verdict) =>
      switch (verdict) {
        ConcentrationVerdict.ok => l10n.networkPoolsBadgeOk,
        ConcentrationVerdict.warning => l10n.networkPoolsBadgeWarning,
        ConcentrationVerdict.critical => l10n.networkPoolsBadgeCritical,
      };

  String _insightText(
    AppL10n l10n,
    String locale,
    PoolConcentration concentration,
  ) {
    final topOne = formatShare(locale, concentration.topPoolShare);
    final topThree = formatShare(locale, concentration.topThreeShare);
    return switch (concentration.verdict) {
      ConcentrationVerdict.ok => l10n.networkPoolsInsightOk(
        topOne,
        formatThreshold(locale, PoolConcentration.topThreeWarningThreshold),
      ),
      ConcentrationVerdict.warning => l10n.networkPoolsInsightWarning(
        topOne,
        topThree,
      ),
      ConcentrationVerdict.critical => l10n.networkPoolsInsightCritical(
        topOne,
        topThree,
      ),
    };
  }

  Future<void> _showInfo(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 600),
      // The app's sheet vocabulary — 32 px top radius, surface ground —
      // plus the accent edge the design gives an explanation, so it does
      // not read as another picker.
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(color: scheme.primary, width: 2),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s6,
          AppSpacing.s5,
          AppSpacing.s7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.networkPoolsInfoTitle,
              style: AppTypography.displayMedium.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              l10n.networkPoolsInfoBody,
              style: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Figures ----------------------------------------------------------------

class _Figures extends StatelessWidget {
  const _Figures({
    required this.topPool,
    required this.concentration,
    required this.tone,
    required this.locale,
  });

  final MiningPool topPool;
  final PoolConcentration? concentration;
  final StatementTone tone;
  final String locale;

  /// Width one figure column needs before a second fits beside it.
  static const double columnBasis = 260;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final topOne = _FigureColumn(
      label: l10n.networkPoolsTopOneLabel,
      value: topPool.hashratePercent,
      subtitle: topPool.name,
      warningThreshold: PoolConcentration.topOneWarningThreshold,
      criticalThreshold: PoolConcentration.topOneCriticalThreshold,
      tone: tone,
      locale: locale,
    );

    // No top-three column when the statement is not formable. It is left
    // out entirely rather than shown with a dash: an em dash where a
    // figure belongs is the placeholder CLAUDE.md §5 rules out.
    final topThree = concentration == null
        ? null
        : _FigureColumn(
            label: l10n.networkPoolsTopThreeLabel,
            value: concentration!.topThreeShare,
            subtitle: concentration!.pools
                .take(PoolConcentration.minimumPools)
                .map((pool) => pool.name)
                .join(' · '),
            warningThreshold: PoolConcentration.topThreeWarningThreshold,
            criticalThreshold: PoolConcentration.topThreeCriticalThreshold,
            tone: tone,
            locale: locale,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsSideBySide =
            topThree != null &&
            constraints.maxWidth >= columnBasis * 2 + AppSpacing.s6;

        if (!fitsSideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topOne,
              if (topThree != null) ...[
                const SizedBox(height: AppSpacing.s6),
                topThree,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: topOne),
            const SizedBox(width: AppSpacing.s6),
            Expanded(child: topThree),
          ],
        );
      },
    );
  }
}

/// One figure with its meter, thresholds and distance note.
class _FigureColumn extends StatelessWidget {
  const _FigureColumn({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.tone,
    required this.locale,
  });

  final String label;
  final double value;
  final String subtitle;
  final double warningThreshold;
  final double criticalThreshold;
  final StatementTone tone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final neutral = AppColors.neutralFor(theme.brightness);

    final distance = (value - warningThreshold).abs();
    final note = value <= warningThreshold
        ? l10n.networkPoolsDistanceBelow(
            formatPoints(locale, distance),
            formatThreshold(locale, warningThreshold),
          )
        : l10n.networkPoolsDistanceAbove(
            formatPoints(locale, distance),
            formatThreshold(locale, warningThreshold),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.monoLabel.copyWith(color: neutral),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatShare(locale, value),
              style: AppTypography.displayLarge.copyWith(
                color: scheme.onSurface,
                fontFeatures: AppTypography.figureFeatures,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              '%',
              style: AppTypography.monoValue.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          subtitle,
          style: AppTypography.monoValue.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        _ThresholdMeter(
          value: value,
          warningThreshold: warningThreshold,
          criticalThreshold: criticalThreshold,
          fill: tone.colorFor(theme.brightness),
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n
                  .networkPoolsThreshold(
                    formatThreshold(locale, warningThreshold),
                  )
                  .toUpperCase(),
              style: AppTypography.monoLabel.copyWith(color: neutral),
            ),
            Text(
              l10n
                  .networkPoolsCriticalFrom(
                    formatThreshold(locale, criticalThreshold),
                  )
                  .toUpperCase(),
              style: AppTypography.monoLabel.copyWith(color: neutral),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          note.toUpperCase(),
          style: AppTypography.monoLabel.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The bar with the two threshold ticks drawn on it.
///
/// **The ticks are what make the figure readable as a judgement.** Without
/// them a 57.9 % bar is just over half full; with them it is visibly short
/// of the line where the verdict would change.
class _ThresholdMeter extends StatelessWidget {
  const _ThresholdMeter({
    required this.value,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.fill,
  });

  final double value;
  final double warningThreshold;
  final double criticalThreshold;
  final Color fill;

  static const double trackHeight = 10;
  static const double tickOverhang = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: trackHeight + tickOverhang * 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: tickOverhang,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: trackHeight,
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (value / 100).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _Tick(
                left: width * (warningThreshold / 100),
                color: scheme.onSurface,
              ),
              _Tick(
                left: width * (criticalThreshold / 100),
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.left, required this.color});

  final double left;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      child: Container(width: 2, color: color),
    );
  }
}

// -- Notices ----------------------------------------------------------------

/// The age hint. Deliberately not an error: the figures below it are the
/// last ones the producer published and are still worth reading.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.hours, required this.stamp});

  final int hours;
  final String stamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final warning = AppColors.warningFor(theme.brightness);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: warning),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandIcon(UiGlyph.alert, size: 16, color: warning),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n
                    .networkPoolsStaleNotice(
                      l10n.networkPoolsStaleAge(hours),
                      stamp,
                    )
                    .toUpperCase(),
                style: AppTypography.monoCaption.copyWith(
                  color: scheme.onSurface,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fewer than three pools: the statement has no substitute value.
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandIcon(
                NavSection.network,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s3),
              Flexible(
                child: Text(
                  l10n.networkPoolsEmptyTitle,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.networkPoolsEmptyBody(count),
            style: AppTypography.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Error ------------------------------------------------------------------

class _PoolsError extends StatelessWidget {
  const _PoolsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.networkPoolsCategory.toUpperCase(),
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              BrandIcon(
                UiGlyph.alert,
                size: 20,
                color: AppColors.warningFor(theme.brightness),
              ),
              const SizedBox(width: AppSpacing.s3),
              Flexible(
                child: Text(
                  l10n.networkPoolsErrorTitle,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          // Names what still works. A section that fails should not read
          // as the app failing.
          Text(
            l10n.networkPoolsErrorBody,
            style: AppTypography.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              side: BorderSide(color: scheme.outline),
              shape: const StadiumBorder(),
            ),
            child: Text(
              l10n.networkPoolsRetry.toUpperCase(),
              style: AppTypography.monoLabel.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Loading ----------------------------------------------------------------

class _PoolsLoading extends StatelessWidget {
  const _PoolsLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Statement(
      category: StatementCategory(
        label: l10n.networkPoolsCategory,
        trailing: [l10n.networkPoolsLoadingLabel],
      ),
      figures: const _LoadingFigures(),
      evidence: const _LoadingEvidence(),
    );
  }
}

class _LoadingFigures extends StatelessWidget {
  const _LoadingFigures();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Skeleton(width: 240, height: 36),
        SizedBox(height: AppSpacing.s5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _SkeletonFigure()),
            SizedBox(width: AppSpacing.s6),
            Expanded(child: _SkeletonFigure()),
          ],
        ),
      ],
    );
  }
}

class _SkeletonFigure extends StatelessWidget {
  const _SkeletonFigure();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Skeleton(width: 110, height: 10),
        SizedBox(height: AppSpacing.s3),
        _Skeleton(width: 150, height: 34),
        SizedBox(height: AppSpacing.s3),
        _Skeleton(height: 10),
      ],
    );
  }
}

class _LoadingEvidence extends StatelessWidget {
  const _LoadingEvidence();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Skeleton(width: 180, height: 10),
            SizedBox(height: AppSpacing.s4),
            _Skeleton(height: 10),
            SizedBox(height: AppSpacing.s3),
            _Skeleton(height: 10),
            SizedBox(height: AppSpacing.s3),
            _Skeleton(height: 10),
            SizedBox(height: AppSpacing.s4),
            _Skeleton(width: 200, height: 44, radius: 999),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.width, required this.height, this.radius = 4});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
