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
import '../data/binance_api.dart';
import '../data/market_provider.dart';
import '../data/price_live_provider.dart';
import '../domain/ath_distance.dart';
import '../domain/market_dominance.dart';
import '../domain/market_snapshot.dart';
import '../domain/price_tick.dart';

/// Price overview — main landing screen (German label: "Kurs").
///
///   * **Header** — the shared [AppHeader]: brand lockup, currency pill,
///     settings gear
///   * **Hero**   — live price (display serif) with observation timestamp
///   * **Two statements** — how far below the all-time high the price
///     stands, and how much of the crypto market Bitcoin holds
///
/// The live price comes from [priceLiveProvider], the two statements from
/// [marketProvider]. The chart between them is #31 and is not stubbed
/// here; a screen with one finished statement and a grey rectangle where
/// the next one goes is what CLAUDE.md §5 rules out.
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
            ..invalidate(marketProvider);
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
          : _StaleNotice(snapshot: snapshot, freshness: freshness, now: now),
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
          : _StaleNotice(snapshot: snapshot, freshness: freshness, now: now),
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

/// The age hint, in its two stages.
///
/// Past 45 minutes the line turns amber and the live dot is already gone.
/// Past 24 hours it gains the alert glyph: three quarters of an hour is a
/// hiccup, a full day means nobody is writing. **The figures stay in both
/// stages** — this says how old they are, it does not withdraw them.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({
    required this.snapshot,
    required this.freshness,
    required this.now,
  });

  final MarketSnapshot snapshot;
  final PayloadFreshness freshness;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
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
            if (freshness == PayloadFreshness.longStale) ...[
              BrandIcon(UiGlyph.alert, size: 16, color: warning),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                l10n
                    .priceMarketStaleNotice(
                      _age(l10n, snapshot.ageAt(now)),
                      _stamp(locale, snapshot.fetchedAt),
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
                  l10n.priceMarketErrorTitle,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.priceMarketErrorBody,
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
