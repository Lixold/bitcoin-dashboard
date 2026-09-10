import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money_format.dart';
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
import '../../../core/widgets/segmented_control.dart';
import '../data/binance_api.dart';
import '../data/history_provider.dart';
import '../data/market_provider.dart';
import '../data/price_live_provider.dart';
import '../domain/ath_distance.dart';
import '../domain/market_dominance.dart';
import '../domain/market_snapshot.dart';
import '../domain/price_history.dart';
import '../domain/price_range.dart';
import '../domain/price_tick.dart';
import '../domain/price_trend.dart';
import 'price_trend_chart.dart';

/// Price overview — main landing screen (German label: "Kurs").
///
///   * **Header** — the shared [AppHeader]: brand lockup, currency pill,
///     settings gear
///   * **Hero**   — live price (display serif) with observation timestamp
///   * **Market movement** — which way the price has gone over the range
///     the reader picked, with the curve underneath as its evidence
///   * **Two statements** — how far below the all-time high the price
///     stands, and how much of the crypto market Bitcoin holds
///
/// Three sources, and they fail independently. The live price comes from
/// [priceLiveProvider] over a socket, the movement from
/// [historyProvider] for the selected range, the two statements below it
/// from [marketProvider]. Each section states its own age and shows its
/// own error, because a CDN document being unreachable says nothing about
/// the other two.
class PriceScreen extends ConsumerWidget {
  const PriceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickAsync = ref.watch(priceLiveProvider);
    final marketAsync = ref.watch(marketProvider);

    // **The pill names the currency of the data, not of the setting.**
    // The app cannot convert yet (#32), so every amount on this screen is
    // what the sources published — the Binance pair's quote currency for
    // the hero, `market.json`'s own `currency` field for the amounts
    // below. A pill reading EUR over dollar figures would not be a
    // display preference, it would be a false statement about the number
    // beneath it. #32 switches the value and the symbol together.
    final quoteCurrency = PriceTick.quoteCurrencyOf(
      tickAsync.value?.symbol ?? BinanceApi.defaultSymbol,
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(priceLiveProvider)
            ..invalidate(marketProvider)
            // The family, not one range: a pull to refresh is a request
            // for current figures, and the four ranges the reader is not
            // looking at are exactly what a later tap will show.
            ..invalidate(historyProvider);
        },
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
                      AppHeader(currency: quoteCurrency),
                      const SizedBox(height: AppSpacing.s6),
                      _PriceHero(tickAsync: tickAsync, currency: quoteCurrency),
                      const SizedBox(height: AppSpacing.s7),
                      const _TrendSection(),
                      const SizedBox(height: AppSpacing.s7),
                      marketAsync.when(
                        loading: () => const _MarketLoading(),
                        error: (_, _) => _MarketError(
                          onRetry: () => ref.invalidate(marketProvider),
                        ),
                        data: (snapshot) => _MarketStatements(
                          snapshot: snapshot,
                          tickAsync: tickAsync,
                        ),
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

// -- Price hero -------------------------------------------------------------

class _PriceHero extends StatelessWidget {
  const _PriceHero({required this.tickAsync, required this.currency});

  final AsyncValue<PriceTick> tickAsync;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The dot claims the price is being observed right now, so it
            // appears only when there is an observation to point at.
            if (tickAsync.hasValue) ...[
              LiveDot(color: AppColors.positiveFor(theme.brightness)),
              const SizedBox(width: AppSpacing.s2),
            ],
            Expanded(
              child: Text(
                switch (tickAsync) {
                  AsyncValue(:final value?) => l10n.priceHeroLabel(
                    DateFormat.yMMMd(
                      locale,
                    ).add_Hm().format(value.observedAt.toLocal()),
                  ),
                  AsyncError() => l10n.priceError,
                  _ => l10n.priceLoading,
                },
                style: AppTypography.monoCaption.copyWith(
                  color: tickAsync.hasError
                      ? AppColors.negativeFor(theme.brightness)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        switch (tickAsync) {
          AsyncValue(:final value?) => _PriceLine(
            price: formatMoney(locale, value.price, currency),
          ),
          // **No zero while loading.** A formatted `$0.00` in the hero is
          // a number a reader can mistake for a price, which is the
          // placeholder CLAUDE.md §5 rules out. The skeleton holds the
          // same space and claims nothing.
          AsyncError() => const SizedBox.shrink(),
          _ => const _HeroSkeleton(),
        },
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoadingSkeleton(width: 260, height: 56, radius: 8),
        SizedBox(height: AppSpacing.s3),
        LoadingSkeleton(width: 160, height: 14),
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

// -- Market movement --------------------------------------------------------

/// Which way the price has gone over the range the reader picked.
///
/// **The range strip is part of the statement, not part of the chart.**
/// Picking `1W` instead of `1Y` changes the verdict word, the figure and
/// the sentence, not just what the curve is drawn from — so the control
/// sits above the verdict, in the slot [Statement.selection] exists for.
/// A strip in the chart header would say it only re-draws a picture.
class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(selectedPriceRangeProvider);
    final historyAsync = ref.watch(historyProvider(range));

    return historyAsync.when(
      loading: () => _TrendLoading(range: range),
      // The one state where the range strip goes too: the document behind
      // every range comes from the same place, so a reader who could
      // switch would only reach the same failure five times. The retry is
      // the way out.
      error: (_, _) =>
          _TrendError(onRetry: () => ref.invalidate(historyProvider(range))),
      data: (history) => _TrendStatement(
        history: history,
        range: range,
        now: ref.watch(clockProvider)(),
      ),
    );
  }
}

/// The movement statement, in each of the four shapes its series can take.
///
/// | series | verdict and figure | evidence |
/// |---|---|---|
/// | full | stated | the curve |
/// | full, past the age threshold | stated | the curve, in neutral |
/// | under [PriceTrend.minPoints] | dropped | the points, dashed |
/// | none at all | dropped | nothing — no empty frame |
///
/// **A short series is not a thin trend, it is no trend.** A line through
/// five points looks exactly like a direction and is not one, so the
/// verdict and the figure fall away together and the sentence says why.
/// The other ranges stay selectable throughout: a strip that disappeared
/// on the one range that is short would strand the reader on it.
class _TrendStatement extends StatelessWidget {
  const _TrendStatement({
    required this.history,
    required this.range,
    required this.now,
  });

  final PriceHistory history;
  final PriceRange range;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final freshness = history.freshnessAt(now);
    final trend = PriceTrend.from(history);
    final points = history.points.length;
    final tone = trend == null ? StatementTone.warning : _tone(trend.verdict);

    return Statement(
      category: StatementCategory(
        label: l10n.priceTrendCategory,
        isLive: freshness == PayloadFreshness.fresh,
        trailing: [
          l10n.priceMarketAsOf(_stamp(locale, history.fetchedAt)),
          _age(l10n, history.ageAt(now)),
        ],
      ),
      selection: _RangePicker(selected: range),
      notice: _notice(l10n, locale, freshness, trend, points),
      verdict: trend == null
          ? null
          : StatementVerdict(
              verdict: _verdictLabel(l10n, trend.verdict),
              badgeLabel: _badgeLabel(l10n, trend.verdict),
              tone: tone,
              // Short enough for a tooltip, so the trigger carries the
              // whole explanation rather than promising a sheet.
              infoLabel: l10n.priceTrendInfo,
            ),
      figures: trend == null
          ? null
          : _Figure(
              // The sign belongs to the figure: "9.6 %" over a period
              // does not say which way, and this statement is only about
              // which way.
              value: '${formatSignedPercent(locale, trend.changePercent)} %',
              unit: l10n.priceTrendPeriod(_period(l10n, trend)),
            ),
      insight: InsightPill(
        category: trend == null
            ? l10n.priceTrendSparseCategory
            : l10n.priceTrendInsightCategory,
        text: _insightText(l10n, locale, trend, points),
        tone: tone,
      ),
      // No points, no card. An outlined box with nothing drawn in it is
      // the empty frame CLAUDE.md §5 rules out; the sentence above
      // already says there is nothing to show.
      evidence: points == 0
          ? null
          : PriceTrendChart(
              history: history,
              range: range,
              tone: trend == null
                  ? TrendChartTone.sparse
                  : freshness == PayloadFreshness.fresh
                  ? TrendChartTone.current
                  : TrendChartTone.aged,
            ),
    );
  }

  /// The notices this statement can carry, in the order they are read.
  ///
  /// **Both can be true at once.** A series can be short *and* older than
  /// the threshold, and the two say different things — one about what the
  /// series can support, one about when it was written. Neither replaces
  /// the other, so both are shown.
  Widget? _notice(
    AppL10n l10n,
    String locale,
    PayloadFreshness freshness,
    PriceTrend? trend,
    int points,
  ) {
    final notices = <Widget>[
      if (points == 0)
        _NoticePill(
          text: l10n.priceTrendEmptyNotice.toUpperCase(),
          showAlert: true,
        )
      else if (trend == null)
        _NoticePill(
          text: l10n
              .priceTrendSparseNotice(points, PriceTrend.minPoints)
              .toUpperCase(),
          showAlert: true,
        ),
      if (freshness != PayloadFreshness.fresh)
        _StaleNotice(
          fetchedAt: history.fetchedAt,
          age: history.ageAt(now),
          freshness: freshness,
        ),
    ];

    if (notices.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < notices.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s3),
          notices[i],
        ],
      ],
    );
  }

  /// The span the change was measured over, said in the unit that reads.
  String _period(AppL10n l10n, PriceTrend trend) => trend.readsInHours
      ? l10n.priceTrendSpanHours(trend.spanHours)
      : l10n.priceTrendSpanDays(trend.spanDays);

  String _insightText(
    AppL10n l10n,
    String locale,
    PriceTrend? trend,
    int points,
  ) {
    if (points == 0) return l10n.priceTrendEmptyInsight;
    if (trend == null) {
      // The expected count is what this statement needs, not what the
      // producer published: the per-range counts move from day to day, so
      // a reader compared against one of those would be told they are
      // missing points nobody promised.
      return l10n.priceTrendSparseInsight(points, PriceTrend.minPoints);
    }

    final period = _period(l10n, trend);
    // The sentence names the size of the move; the verdict beside it
    // already carries the direction, and "gained −9.6 %" is not a
    // sentence.
    final change = formatPercent(locale, trend.changePercent.abs());
    final band = formatThreshold(locale, PriceTrend.flatBandPercent);

    return switch (trend.verdict) {
      TrendVerdict.rising => l10n.priceTrendInsightUp(period, change, band),
      TrendVerdict.sideways => l10n.priceTrendInsightFlat(period, change, band),
      TrendVerdict.falling => l10n.priceTrendInsightDown(period, change, band),
    };
  }

  StatementTone _tone(TrendVerdict verdict) => switch (verdict) {
    TrendVerdict.rising => StatementTone.positive,
    // Neutral, not warning: no direction is not a caution, and the design
    // draws its marker in the neutral grey.
    TrendVerdict.sideways => StatementTone.neutral,
    TrendVerdict.falling => StatementTone.negative,
  };

  String _verdictLabel(AppL10n l10n, TrendVerdict verdict) => switch (verdict) {
    TrendVerdict.rising => l10n.priceTrendVerdictUp,
    TrendVerdict.sideways => l10n.priceTrendVerdictFlat,
    TrendVerdict.falling => l10n.priceTrendVerdictDown,
  };

  String _badgeLabel(AppL10n l10n, TrendVerdict verdict) => switch (verdict) {
    TrendVerdict.rising => l10n.priceTrendBadgeUp,
    TrendVerdict.sideways => l10n.priceTrendBadgeFlat,
    TrendVerdict.falling => l10n.priceTrendBadgeDown,
  };
}

/// The five ranges, as one connected strip across the statement.
///
/// The labels are translation keys rather than literals: German
/// abbreviates day and year as `T` and `J`, and the placeholder version
/// of this strip shipped them as German literals in code.
class _RangePicker extends ConsumerWidget {
  const _RangePicker({required this.selected});

  final PriceRange selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return Semantics(
      container: true,
      // Five two-character labels are not a name a screen reader can
      // announce a group by.
      label: l10n.priceTrendRangeLabel,
      child: AppSegmentedControl<PriceRange>(
        density: SegmentedDensity.compact,
        block: true,
        segments: [
          for (final range in PriceRange.values)
            AppSegment(value: range, label: _label(l10n, range)),
        ],
        selected: selected,
        onSelected: (range) =>
            ref.read(selectedPriceRangeProvider.notifier).select(range),
      ),
    );
  }

  String _label(AppL10n l10n, PriceRange range) => switch (range) {
    PriceRange.oneDay => l10n.priceRange1D,
    PriceRange.oneWeek => l10n.priceRange1W,
    PriceRange.oneMonth => l10n.priceRange1M,
    PriceRange.threeMonths => l10n.priceRange3M,
    PriceRange.oneYear => l10n.priceRange1Y,
  };
}

/// The movement section while its document is in flight.
///
/// The range strip stays: it is driven by the reader's choice rather than
/// by the payload, and a control that vanished on every tap would flicker
/// once per range switch. The skeletons hold the height the verdict, the
/// sentence and the curve will take, so nothing below moves when the
/// series lands.
class _TrendLoading extends StatelessWidget {
  const _TrendLoading({required this.range});

  final PriceRange range;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Statement(
      category: StatementCategory(
        label: l10n.priceTrendCategory,
        trailing: [l10n.priceTrendLoadingLabel],
      ),
      selection: _RangePicker(selected: range),
      figures: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(width: 240, height: 34),
          SizedBox(height: AppSpacing.s5),
          LoadingSkeleton(width: 180, height: 44),
        ],
      ),
      insight: const LoadingSkeleton(height: 44, radius: 4),
      evidence: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
        child: LoadingSkeleton(
          height: PriceTrendChart.heightFor(MediaQuery.sizeOf(context).width),
          radius: AppSpacing.cardRadius,
        ),
      ),
    );
  }
}

/// The published history could not be reached and nothing was cached.
///
/// The statement and its range strip go together, and the copy names what
/// still works: the hero above is a live socket to Binance and is not
/// affected by a CDN document being unreachable.
class _TrendError extends StatelessWidget {
  const _TrendError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _ErrorBlock(
      title: l10n.priceTrendErrorTitle,
      body: l10n.priceTrendErrorBody,
      onRetry: onRetry,
    );
  }
}

// -- Market statements ------------------------------------------------------

/// The two statements `market.json` carries, in the order the design puts
/// them.
///
/// **A missing field drops one statement, not the section.** `ath` and
/// `btcDominance` are read independently: without the high the distance
/// falls away and the share stays whole, and the other way round. With
/// neither there is nothing to say and nothing is drawn — no dash, no
/// empty frame, no substitute line.
class _MarketStatements extends ConsumerWidget {
  const _MarketStatements({required this.snapshot, required this.tickAsync});

  final MarketSnapshot snapshot;
  final AsyncValue<PriceTick> tickAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read rather than called directly: the age is a comparison against
    // now, and a test has to be able to say which now it means. Asking at
    // build time is also what lets a screen left open cross the threshold
    // when the clock does.
    final now = ref.watch(clockProvider)();
    final freshness = snapshot.freshnessAt(now);

    final distance = AthDistance.from(
      high: snapshot.ath,
      price: tickAsync.value?.price,
    );
    final dominance = MarketDominance.from(snapshot.btcDominance);

    final statements = <Widget>[
      if (distance != null)
        _AthStatement(
          distance: distance,
          snapshot: snapshot,
          freshness: freshness,
          now: now,
        ),
      if (dominance != null)
        _DominanceStatement(
          dominance: dominance,
          snapshot: snapshot,
          freshness: freshness,
          now: now,
        ),
    ];

    if (statements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < statements.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s7),
          statements[i],
        ],
      ],
    );
  }
}

/// How far below its record the price stands.
class _AthStatement extends StatelessWidget {
  const _AthStatement({
    required this.distance,
    required this.snapshot,
    required this.freshness,
    required this.now,
  });

  final AthDistance distance;
  final MarketSnapshot snapshot;
  final PayloadFreshness freshness;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tone = _tone(distance.verdict);

    return Statement(
      category: StatementCategory(
        label: l10n.priceAthCategory,
        isLive: freshness == PayloadFreshness.fresh,
        trailing: [
          l10n.priceMarketAsOf(_stamp(locale, snapshot.fetchedAt)),
          _age(l10n, snapshot.ageAt(now)),
        ],
      ),
      notice: freshness == PayloadFreshness.fresh
          ? null
          : _StaleNotice(
              fetchedAt: snapshot.fetchedAt,
              age: snapshot.ageAt(now),
              freshness: freshness,
            ),
      verdict: StatementVerdict(
        verdict: _verdictLabel(l10n, distance.verdict),
        badgeLabel: _badgeLabel(l10n, distance.verdict),
        tone: tone,
        // The explanation fits in a sentence, so the trigger carries it
        // rather than promising a sheet — see [InfoTrigger].
        infoLabel: l10n.priceAthInfoTrigger,
      ),
      // At or above the published high there is no distance to print.
      // The verdict word and its badge carry the reading instead: a `0`
      // under "% below the high" would be a figure claiming something the
      // price is not doing.
      figures: distance.verdict == AthVerdict.atOrAbove
          ? null
          : _Figure(
              value: formatPercent(locale, distance.percentBelow),
              unit: l10n.priceAthFigureUnit,
            ),
      evidence: _AthEvidence(
        distance: distance,
        snapshot: snapshot,
        tone: tone,
        now: now,
      ),
    );
  }

  StatementTone _tone(AthVerdict verdict) => switch (verdict) {
    // Amber, not green. Little room above is this product's overheated
    // zone, not its good news — the design says so explicitly.
    AthVerdict.atOrAbove => StatementTone.warning,
    AthVerdict.near => StatementTone.warning,
    AthVerdict.correction => StatementTone.neutral,
    AthVerdict.deep => StatementTone.negative,
  };

  String _verdictLabel(AppL10n l10n, AthVerdict verdict) => switch (verdict) {
    AthVerdict.atOrAbove => l10n.priceAthVerdictAtOrAbove,
    AthVerdict.near => l10n.priceAthVerdictNear,
    AthVerdict.correction => l10n.priceAthVerdictCorrection,
    AthVerdict.deep => l10n.priceAthVerdictDeep,
  };

  String _badgeLabel(AppL10n l10n, AthVerdict verdict) => switch (verdict) {
    AthVerdict.atOrAbove => l10n.priceAthBadgeAtOrAbove,
    AthVerdict.near => l10n.priceAthBadgeNear,
    AthVerdict.correction => l10n.priceAthBadgeCorrection,
    AthVerdict.deep => l10n.priceAthBadgeDeep,
  };
}

/// The record the distance is measured from, and how far along it the
/// price stands.
class _AthEvidence extends StatelessWidget {
  const _AthEvidence({
    required this.distance,
    required this.snapshot,
    required this.tone,
    required this.now,
  });

  final AthDistance distance;
  final MarketSnapshot snapshot;
  final StatementTone tone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final currency = snapshot.currency;
    final high = snapshot.ath;
    final athDate = snapshot.athDate;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressMeter(
            percent: distance.percentOfHigh,
            fill: tone.colorFor(theme.brightness),
            topLeft: l10n.priceAthMeterNow(
              formatPercent(locale, distance.percentOfHigh),
            ),
            topRight: l10n.priceAthMeterTop,
          ),
          const SizedBox(height: AppSpacing.s5),
          // The amount needs a currency to be labelled with, and the
          // payload is where that comes from. Without it the row is left
          // out rather than shown under a guessed symbol.
          if (high != null && currency != null)
            _EvidenceRow(
              label: l10n.priceAthEvidenceAth,
              value: formatMoney(locale, high, currency),
            ),
          if (athDate != null)
            _EvidenceRow(
              label: l10n.priceAthEvidenceDate,
              value: l10n.priceAthEvidenceDateValue(
                DateFormat.yMMMd(locale).format(athDate.toLocal()),
                now.toUtc().difference(athDate).inDays,
              ),
            ),
        ],
      ),
    );
  }
}

// -- Market share -----------------------------------------------------------

/// How much of the crypto market Bitcoin holds.
class _DominanceStatement extends StatelessWidget {
  const _DominanceStatement({
    required this.dominance,
    required this.snapshot,
    required this.freshness,
    required this.now,
  });

  final MarketDominance dominance;
  final MarketSnapshot snapshot;
  final PayloadFreshness freshness;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tone = _tone(dominance.verdict);

    return Statement(
      category: StatementCategory(
        label: l10n.priceDominanceCategory,
        isLive: freshness == PayloadFreshness.fresh,
        trailing: [
          l10n.priceMarketAsOf(_stamp(locale, snapshot.fetchedAt)),
          _age(l10n, snapshot.ageAt(now)),
        ],
      ),
      notice: freshness == PayloadFreshness.fresh
          ? null
          : _StaleNotice(
              fetchedAt: snapshot.fetchedAt,
              age: snapshot.ageAt(now),
              freshness: freshness,
            ),
      // No info trigger here: the design gives one to the distance, where
      // "all-time high" needs saying, and none to a share of a market.
      verdict: StatementVerdict(
        verdict: _verdictLabel(l10n, dominance.verdict),
        badgeLabel: _badgeLabel(l10n, dominance.verdict),
        tone: tone,
      ),
      figures: _Figure(
        value: formatPercent(locale, dominance.share),
        unit: '%',
      ),
      evidence: _DominanceEvidence(
        dominance: dominance,
        snapshot: snapshot,
        tone: tone,
      ),
    );
  }

  StatementTone _tone(DominanceVerdict verdict) => switch (verdict) {
    DominanceVerdict.high => StatementTone.positive,
    DominanceVerdict.stable => StatementTone.neutral,
    DominanceVerdict.low => StatementTone.warning,
  };

  String _verdictLabel(AppL10n l10n, DominanceVerdict verdict) =>
      switch (verdict) {
        DominanceVerdict.high => l10n.priceDominanceVerdictHigh,
        DominanceVerdict.stable => l10n.priceDominanceVerdictStable,
        DominanceVerdict.low => l10n.priceDominanceVerdictLow,
      };

  String _badgeLabel(AppL10n l10n, DominanceVerdict verdict) =>
      switch (verdict) {
        DominanceVerdict.high => l10n.priceDominanceBadgeHigh,
        DominanceVerdict.stable => l10n.priceDominanceBadgeStable,
        DominanceVerdict.low => l10n.priceDominanceBadgeLow,
      };
}

/// The two bars, and the size the share is a share of.
class _DominanceEvidence extends StatelessWidget {
  const _DominanceEvidence({
    required this.dominance,
    required this.snapshot,
    required this.tone,
  });

  final MarketDominance dominance;
  final MarketSnapshot snapshot;
  final StatementTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final neutral = AppColors.neutralFor(theme.brightness);
    final marketCap = snapshot.marketCap;
    final currency = snapshot.currency;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShareRow(
            label: l10n.priceDominanceEvidenceBitcoin,
            percent: dominance.share,
            fill: tone.colorFor(theme.brightness),
            locale: locale,
          ),
          const SizedBox(height: AppSpacing.s3),
          _ShareRow(
            label: l10n.priceDominanceEvidenceRest,
            percent: dominance.rest,
            fill: neutral,
            locale: locale,
          ),
          if (marketCap != null && currency != null) ...[
            const SizedBox(height: AppSpacing.s5),
            _EvidenceRow(
              label: l10n.priceDominanceEvidenceMarketCap,
              // Short form: twelve digits are not read, they are
              // squinted at. `intl` owns the suffix, which differs by
              // more than the word between English and German.
              value: formatMoneyCompact(locale, marketCap, currency),
            ),
          ],
        ],
      ),
    );
  }
}

/// One labelled bar: who, how much of the whole, and the figure.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.percent,
    required this.fill,
    required this.locale,
  });

  final String label;
  final double percent;
  final Color fill;
  final String locale;

  /// Width the two labels and the two figures reserve, so both bars start
  /// and end on the same pixel and are comparable by eye.
  static const double labelWidth = 76;
  static const double figureWidth = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoValue.copyWith(
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: ProgressMeter(percent: percent, fill: fill, radius: 4),
        ),
        const SizedBox(width: AppSpacing.s3),
        SizedBox(
          width: figureWidth,
          child: Text(
            '${formatPercent(locale, percent)} %',
            textAlign: TextAlign.right,
            style: AppTypography.monoValue.copyWith(
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// -- Shared pieces ----------------------------------------------------------

/// The headline number and the unit that says what it counts.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppTypography.displayLarge.copyWith(
            color: scheme.onSurface,
            fontFeatures: AppTypography.figureFeatures,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Flexible(
          child: Text(
            unit,
            style: AppTypography.monoValue.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One `label · value` line under a statement.
class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.monoLabel.copyWith(
                color: AppColors.neutralFor(theme.brightness),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          // Both halves flex. A German label is longer than its English
          // counterpart and an amount is longer than a share, so a fixed
          // side would push the other off the row on a narrow phone.
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.monoValue.copyWith(
                fontSize: 12,
                color: scheme.onSurface,
                fontFeatures: AppTypography.figureFeatures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lozenge every notice on this screen is set in: an amber outline,
/// mono caps, and the alert glyph when the state has earned it.
///
/// Three statements sit on this screen and each can qualify its figures.
/// One shape for all of them is what keeps "this is three quarters of an
/// hour old" and "this series is too short" reading as the same *kind* of
/// remark, told apart by what they say rather than by how they look.
class _NoticePill extends StatelessWidget {
  const _NoticePill({required this.text, this.showAlert = false});

  /// Already localised and already upper-cased by its caller — the copy
  /// differs per notice and so does where the casing belongs.
  final String text;

  /// The glyph is the second stage, not decoration: it marks the notices
  /// that mean something is wrong rather than merely old.
  final bool showAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            if (showAlert) ...[
              BrandIcon(UiGlyph.alert, size: 16, color: warning),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                text,
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

/// The age hint, in its two stages.
///
/// Past 45 minutes the line turns amber and the live dot is already gone.
/// Past 24 hours it gains the alert glyph: three quarters of an hour is a
/// hiccup, a full day means nobody is writing. **The figures stay in both
/// stages** — this says how old they are, it does not withdraw them.
///
/// It takes the stamp and the age rather than a payload: three documents
/// on this screen report an age and they are not the same type.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({
    required this.fetchedAt,
    required this.age,
    required this.freshness,
  });

  final DateTime fetchedAt;
  final Duration age;
  final PayloadFreshness freshness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return _NoticePill(
      text: l10n
          .priceMarketStaleNotice(_age(l10n, age), _stamp(locale, fetchedAt))
          .toUpperCase(),
      showAlert: freshness == PayloadFreshness.longStale,
    );
  }
}

// -- Error ------------------------------------------------------------------

/// The CDN could not be reached and nothing was cached.
///
/// Both statements fall away together — they rest on one document — and
/// the copy names what still works, so a section that fails does not read
/// as the app failing.
class _MarketError extends StatelessWidget {
  const _MarketError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _ErrorBlock(
      title: l10n.priceMarketErrorTitle,
      body: l10n.priceMarketErrorBody,
      onRetry: onRetry,
    );
  }
}

/// One section's failure: the glyph, what could not be reached, what is
/// unaffected, and a retry the reader chooses.
///
/// Two documents feed this screen and either can fail on its own, so the
/// block takes its copy rather than naming a source. Both failing at once
/// shows two of these, which is the truth — they are two documents, and
/// a single merged message would hide that one of them may have come
/// back.
class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
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
                  title,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            body,
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
              l10n.priceMarketRetry.toUpperCase(),
              style: AppTypography.monoLabel.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Loading ----------------------------------------------------------------

/// Skeletons in the shape the statements will take: an eyebrow, a
/// verdict, a figure, and the evidence block. No verdict word, no number,
/// never a zero.
class _MarketLoading extends StatelessWidget {
  const _MarketLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Statement(
      category: StatementCategory(
        label: l10n.priceAthCategory,
        trailing: [l10n.priceMarketLoadingLabel],
      ),
      figures: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(width: 240, height: 34),
          SizedBox(height: AppSpacing.s5),
          LoadingSkeleton(width: 180, height: 44),
        ],
      ),
      evidence: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(height: 10),
            SizedBox(height: AppSpacing.s4),
            LoadingSkeleton(height: 10),
            SizedBox(height: AppSpacing.s3),
            LoadingSkeleton(height: 10),
          ],
        ),
      ),
    );
  }
}

// -- Formatting helpers -----------------------------------------------------

/// The producer's timestamp, in the reader's locale and local zone.
String _stamp(String locale, DateTime fetchedAt) =>
    DateFormat.yMMMd(locale).add_Hm().format(fetchedAt.toLocal());

/// An age in the largest unit that still says something.
///
/// Minutes up to an hour, then hours up to a day, then days. "vor 4320
/// Min." is technically the same fact and tells the reader nothing.
String _age(AppL10n l10n, Duration age) {
  if (age.inHours < 1) return l10n.priceMarketAgeMinutes(age.inMinutes);
  if (age.inDays < 1) return l10n.priceMarketAgeHours(age.inHours);
  return l10n.priceMarketAgeDays(age.inDays);
}
