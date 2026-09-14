import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/percent_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../navigation/domain/nav_section.dart';
import '../data/network_health_provider.dart';
import '../domain/mining_pool.dart';
import '../domain/network_health_snapshot.dart';
import '../domain/node_count.dart';
import '../domain/pool_concentration.dart';
import 'node_count_format.dart';
import 'pool_share_list.dart';
import 'share_format.dart';

/// Network section — two statements: how many full nodes carry the
/// network, and how concentrated mining is.
///
/// The remaining network figures (hashrate, difficulty, mempool, fees)
/// are their own slice and are not stubbed here. A section with two
/// finished statements is the shape CLAUDE.md §5 asks for; a section with
/// two statements and four dashes is not.
///
/// **Age, error and loading belong to the section, not to a statement.**
/// Both statements read the same document through the same fetch and the
/// same 26-hour threshold, so a hint carried by each of them would print
/// the same sentence twice, one above the other.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(networkHealthProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(networkHealthProvider),
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
                AppSpacing.screenFootClearance,
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No currency pill: this section quotes a count and
                      // shares of hashrate, which no fiat unit applies to.
                      const AppHeader(currency: null),
                      const SizedBox(height: AppSpacing.s6),
                      healthAsync.when(
                        loading: () => const _SectionLoading(),
                        error: (_, _) => _SectionError(
                          onRetry: () => ref.invalidate(networkHealthProvider),
                        ),
                        data: (snapshot) => _SectionBody(snapshot: snapshot),
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

// -- Section ----------------------------------------------------------------

/// The section once the document has arrived: the age hint if it is due,
/// then the two statements in the order the reader needs them.
///
/// Nodes first — "can anyone control the network" comes before "who
/// bundles the hashrate". Nothing sits between the age hint and the first
/// figure, so the hint keeps its subject.
class _SectionBody extends ConsumerWidget {
  const _SectionBody({required this.snapshot});

  final NetworkHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    // Read rather than called directly: staleness is a comparison against
    // now, and a test has to be able to say which now it means.
    final now = ref.watch(clockProvider)();
    final isStale = snapshot.isStaleAt(now);
    final stamp = DateFormat.yMMMd(
      locale,
    ).add_Hm().format(snapshot.fetchedAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStale) ...[
          _NoticePill(
            text: l10n.networkSectionStaleNotice(
              l10n.networkSectionStaleAge(
                now.toUtc().difference(snapshot.fetchedAt).inHours,
              ),
              stamp,
            ),
            color: AppColors.warningFor(theme.brightness),
          ),
          const SizedBox(height: AppSpacing.s6),
        ],
        _NodesStatement(snapshot: snapshot, stamp: stamp),
        // 48 px and no divider — the separation the price screen already
        // puts between two statements.
        const SizedBox(height: AppSpacing.s7),
        _PoolsStatement(snapshot: snapshot, stamp: stamp, isStale: isStale),
      ],
    );
  }
}

// -- Nodes ------------------------------------------------------------------

/// How many reachable full nodes carry the network.
///
/// **The verdict hangs on the figure, not on its movement.** That many
/// reachable nodes is what "no single actor can control the network"
/// rests on; a count that rose 0.3 % overnight says nothing about
/// controllability. So the word stands whenever a count arrives, and the
/// 24 h change is context underneath it.
class _NodesStatement extends StatelessWidget {
  const _NodesStatement({required this.snapshot, required this.stamp});

  final NetworkHealthSnapshot snapshot;

  /// The section's data stamp, formatted once for both statements.
  final String stamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final nodes = snapshot.fullNodes;

    final Widget? evidence;
    if (nodes == null) {
      evidence = const _NodesUnavailable();
    } else if (snapshot.sources.isEmpty) {
      evidence = null;
    } else {
      evidence = _NodeSources(sources: snapshot.sources);
    }

    return Statement(
      category: StatementCategory(
        label: l10n.networkNodesCategory,
        // No live dot. The producer runs once a day, so this figure is
        // never a currently observed one — see the note in [LiveDot].
        trailing: [l10n.networkNodesAsOf(stamp)],
      ),
      notice: nodes == null || nodes.hasChange
          ? null
          : _NoticePill(
              text: l10n.networkNodesTrendUnknownNotice,
              // Neutral, not warning: the figure above the notice is
              // current, only the comparison to it is missing.
              color: AppColors.neutralFor(theme.brightness),
            ),
      verdict: nodes == null
          ? null
          : StatementVerdict(
              verdict: l10n.networkNodesVerdictSecure,
              // No badge. A second word here could only name a
              // direction, and the direction carries no verdict.
              tone: StatementTone.positive,
              infoLabel: l10n.networkNodesInfoTrigger,
              onInfo: () => _showStatementInfo(
                context,
                title: l10n.networkNodesInfoTitle,
                body: l10n.networkNodesInfoBody,
              ),
            ),
      figures: nodes == null ? null : _NodeFigure(nodes: nodes, locale: locale),
      insight: nodes == null
          ? null
          : InsightPill(
              category: l10n.networkNodesInsightCategory,
              text: l10n.networkNodesInsight(
                formatNodeCount(locale, nodes.count),
              ),
              tone: StatementTone.positive,
            ),
      evidence: evidence,
    );
  }
}

/// The count, with its 24 h change as a muted line underneath.
///
/// **No meter and no threshold line.** A count has no denominator: there
/// is no canonical number of reachable nodes that makes a network safe,
/// and a bar would assert a scale that does not exist. [ProgressMeter]'s
/// own documentation says its fill is a share of a fixed reference —
/// there is none here. No sparkline either: the payload carries a value,
/// not a series.
class _NodeFigure extends StatelessWidget {
  const _NodeFigure({required this.nodes, required this.locale});

  final NodeCount nodes;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final neutral = AppColors.neutralFor(theme.brightness);
    final change = nodes.percentChange24h;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.networkNodesFigureLabel.toUpperCase(),
          style: AppTypography.monoLabel.copyWith(color: neutral),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          formatNodeCount(locale, nodes.count),
          style: AppTypography.displayLarge.copyWith(
            color: scheme.onSurface,
            fontFeatures: AppTypography.figureFeatures,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          change == null
              ? l10n.networkNodesChangeUnavailable
              : l10n.networkNodesChange24h(
                  '${formatSignedPercent(locale, change)} %',
                ),
          style: AppTypography.monoValue.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The evidence behind the node figure: who says so.
///
/// The names from `_meta.sources` and nothing else — no derivation, no
/// producer cadence, and no repeat of the stamp the category already
/// carries.
class _NodeSources extends StatelessWidget {
  const _NodeSources({required this.sources});

  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);

    return Text(
      [l10n.networkNodesSourcesTitle, ...sources].join(' · ').toUpperCase(),
      style: AppTypography.monoCaption.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

/// No count in the payload: this statement has no subject.
///
/// **Not a section failure.** The pool statement below reads the same
/// document and is untouched, so the body names it rather than leaving
/// the reader to wonder what else broke.
class _NodesUnavailable extends StatelessWidget {
  const _NodesUnavailable();

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
                  l10n.networkNodesUnavailableTitle,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.networkNodesUnavailableBody,
            style: AppTypography.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Pools ------------------------------------------------------------------

class _PoolsStatement extends StatelessWidget {
  const _PoolsStatement({
    required this.snapshot,
    required this.stamp,
    required this.isStale,
  });

  final NetworkHealthSnapshot snapshot;

  /// The section's data stamp, formatted once for both statements.
  final String stamp;

  /// Whether the payload is past [stalePayloadAge]. The age hint itself
  /// belongs to the section; this statement reads the flag only to decide
  /// whether it may still claim to be live.
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

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
      verdict: concentration == null
          ? null
          : StatementVerdict(
              verdict: _verdictLabel(l10n, concentration.verdict),
              badgeLabel: _badgeLabel(l10n, concentration.verdict),
              tone: tone,
              infoLabel: l10n.networkPoolsInfoTrigger,
              onInfo: () => _showStatementInfo(
                context,
                title: l10n.networkPoolsInfoTitle,
                body: l10n.networkPoolsInfoBody,
              ),
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
}

// -- Info sheet -------------------------------------------------------------

/// The long explanation behind a verdict's `?` trigger.
///
/// Both statements on this screen explain a term this way, so the sheet
/// is written once and takes the copy from its caller.
Future<void> _showStatementInfo(
  BuildContext context, {
  required String title,
  required String body,
}) {
  final scheme = Theme.of(context).colorScheme;
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
            title,
            style: AppTypography.displayMedium.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            body,
            style: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    ),
  );
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

/// The shared [ProgressMeter] with this statement's two threshold ticks
/// drawn over it.
///
/// **The ticks are what make the figure readable as a judgement.** Without
/// them a 57.9 % bar is just over half full; with them it is visibly short
/// of the line where the verdict would change. They stay here rather than
/// in [ProgressMeter] because only a figure that has thresholds has them.
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
                child: ProgressMeter(
                  percent: value,
                  fill: fill,
                  height: trackHeight,
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

/// The capsule both notices on this screen are set in: a bordered pill,
/// an alert glyph in the notice's own colour, one line of mono caption.
///
/// Deliberately not an error in either use. The section's age hint sits
/// above figures that are still worth reading, and the node statement's
/// missing-comparison hint sits above a figure that is current.
class _NoticePill extends StatelessWidget {
  const _NoticePill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandIcon(UiGlyph.alert, size: 16, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text.toUpperCase(),
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

/// The document is unreachable, so both statements fall away at once.
///
/// One error with one retry, and a sentence that names what still works:
/// a section that cannot load must not read as the app failing.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

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
                  l10n.networkSectionErrorTitle,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.networkSectionErrorMessage,
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
              l10n.networkSectionRetry.toUpperCase(),
              style: AppTypography.monoLabel.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Loading ----------------------------------------------------------------

/// One skeleton for the section, not one per statement: there is one
/// fetch to wait for, and two stacked skeletons would promise a screen
/// twice as tall as the one that arrives.
///
/// No timestamp in the eyebrow — there is no data stand to name yet.
class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Statement(
      category: StatementCategory(label: l10n.networkSectionLoading),
      figures: const _LoadingFigure(),
      insight: const _LoadingInsight(),
      evidence: const _LoadingEvidence(),
    );
  }
}

class _LoadingFigure extends StatelessWidget {
  const _LoadingFigure();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoadingSkeleton(width: 150, height: 10),
        SizedBox(height: AppSpacing.s3),
        LoadingSkeleton(width: 240, height: 44),
      ],
    );
  }
}

class _LoadingInsight extends StatelessWidget {
  const _LoadingInsight();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: const LoadingSkeleton(height: 72, radius: 10),
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
            LoadingSkeleton(width: 140, height: 10),
            SizedBox(height: AppSpacing.s4),
            LoadingSkeleton(height: 10),
            SizedBox(height: AppSpacing.s3),
            LoadingSkeleton(height: 10),
            SizedBox(height: AppSpacing.s3),
            LoadingSkeleton(height: 10),
          ],
        ),
      ),
    );
  }
}
