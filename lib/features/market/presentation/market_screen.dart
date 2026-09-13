import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/sentiment_provider.dart';
import '../domain/sentiment_band.dart';
import '../domain/sentiment_index.dart';
import 'sentiment_sparkline.dart';

/// Market section — currently one statement: how the mood stands, and how
/// it sits in its own month.
///
/// The other market figures (dominance, market capitalisation) already
/// ship inside the price screen from #30 and are deliberately not
/// repeated here; the 200-week average and the combined valuation signal
/// are #35 and are not stubbed. A section with one finished statement is
/// the shape CLAUDE.md §5 asks for.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentimentAsync = ref.watch(sentimentProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(sentimentProvider),
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
                      // No currency pill: the index is a dimensionless
                      // number on a 0–100 scale, which no fiat unit
                      // applies to.
                      const AppHeader(currency: null),
                      const SizedBox(height: AppSpacing.s6),
                      sentimentAsync.when(
                        loading: () => const _SentimentLoading(),
                        error: (_, _) => _SentimentError(
                          onRetry: () => ref.invalidate(sentimentProvider),
                        ),
                        data: (index) => _SentimentStatement(index: index),
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

class _SentimentStatement extends StatelessWidget {
  const _SentimentStatement({required this.index});

  final SentimentIndex index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final band = index.band;

    return Statement(
      category: StatementCategory(
        label: l10n.marketSentimentCategory,
        // No live dot: the index is set once a day at 00:00 UTC, and a
        // dot that pulses beside a figure published this morning would
        // claim the value is being watched.
        trailing: [l10n.marketSentimentAsOf(_stamp(locale, index.latest.at))],
      ),
      verdict: StatementVerdict(
        verdict: band.key.label(l10n),
        tone: band.tone,
        // No badge: the verdict word already *is* the band's name, so a
        // pill beside it would restate it.
        infoLabel: l10n.marketSentimentInfoTrigger,
      ),
      figures: _Figures(index: index, locale: locale),
      insight: InsightPill(
        category: l10n.marketSentimentInsightCategory,
        text: _insightText(l10n, locale, index),
        tone: band.tone,
      ),
      evidence: _Evidence(index: index, locale: locale),
    );
  }

  /// The sentence under the figure, in the form the window calls for.
  ///
  /// Three forms, one per [SentimentInsight] — which one applies is the
  /// domain's judgement, not the widget's, and the wording of each is a
  /// translation key rather than a string assembled here.
  String _insightText(AppL10n l10n, String locale, SentimentIndex index) {
    final claim = index.band.key.claim(l10n);
    final mean = _formatValue(locale, index.mean.round());
    final band = index.band.key.label(l10n);

    return switch (index.insight) {
      SentimentInsight.switched => l10n.marketSentimentInsightSwitch(
        claim,
        mean,
        band,
        _dayAndMonth(locale, index.runStart),
      ),
      SentimentInsight.steady => l10n.marketSentimentInsightSteady(
        claim,
        mean,
        band,
      ),
      SentimentInsight.short => l10n.marketSentimentInsightShort(
        claim,
        mean,
        _formatValue(locale, index.lowest),
        _formatValue(locale, index.highest),
      ),
    };
  }
}

// -- Figures ----------------------------------------------------------------

/// The index itself on its scale, with the four band boundaries marked.
class _Figures extends StatelessWidget {
  const _Figures({required this.index, required this.locale});

  final SentimentIndex index;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final neutral = AppColors.neutralFor(theme.brightness);
    final labelStyle = AppTypography.monoLabel.copyWith(color: neutral);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.marketSentimentFiguresLabel.toUpperCase(),
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(l10n.marketSentimentScale.toUpperCase(), style: labelStyle),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(locale, index.latest.value),
                style: AppTypography.displayLarge.copyWith(
                  color: scheme.onSurface,
                  fontFeatures: AppTypography.figureFeatures,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                l10n.marketSentimentUnit,
                style: AppTypography.monoValue.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          _BandMeter(
            value: index.latest.value.toDouble(),
            fill: index.band.tone.colorFor(theme.brightness),
          ),
          const SizedBox(height: AppSpacing.s2),
          _BoundaryLabels(locale: locale, style: labelStyle),
        ],
      ),
    );
  }
}

/// The shared [ProgressMeter] with the four band boundaries drawn over
/// it.
///
/// **The ticks are what make the figure readable as a judgement.** Without
/// them a bar filled to 61 % is just over half full; with them it is
/// visibly inside the fourth of five bands, six points above the line
/// where the verdict last changed. They stay here rather than in
/// [ProgressMeter] for the reason that widget states: only a figure that
/// has thresholds has them.
class _BandMeter extends StatelessWidget {
  const _BandMeter({required this.value, required this.fill});

  final double value;
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
              for (final boundary in sentimentScale.boundaries)
                Positioned(
                  left: width * (boundary / sentimentScaleMax),
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: scheme.onSurface),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The four boundary numbers, each under its own tick.
class _BoundaryLabels extends StatelessWidget {
  const _BoundaryLabels({required this.locale, required this.style});

  final String locale;
  final TextStyle style;

  /// Room for one line of [AppTypography.monoLabel].
  static const double height = 14;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final boundary in sentimentScale.boundaries)
                Positioned(
                  left: width * (boundary / sentimentScaleMax),
                  top: 0,
                  child: Text(
                    _formatValue(locale, boundary.round()),
                    style: style,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// -- Evidence ---------------------------------------------------------------

/// The month behind the verdict: the curve over its bands, the range it
/// covered, where it starts, and where it comes from.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.index, required this.locale});

  final SentimentIndex index;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final footStyle = AppTypography.monoLabel.copyWith(
      color: AppColors.neutralFor(theme.brightness),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s5),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n
                  .marketSentimentEvidenceTitle(
                    _dayAndShortMonth(locale, index.points.first.at),
                    _stamp(locale, index.latest.at),
                  )
                  .toUpperCase(),
              style: AppTypography.monoCaption.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            SentimentSparkline(index: index),
            const SizedBox(height: AppSpacing.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l10n
                        .marketSentimentSpan(
                          _formatValue(locale, index.lowest),
                          _formatValue(locale, index.highest),
                        )
                        .toUpperCase(),
                    style: footStyle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Flexible(
                  child: Text(
                    l10n
                        .marketSentimentOldest(
                          _stamp(locale, index.points.first.at),
                        )
                        .toUpperCase(),
                    textAlign: TextAlign.right,
                    style: footStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.marketSentimentSource,
              style: AppTypography.monoCaption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Error ------------------------------------------------------------------

class _SentimentError extends StatelessWidget {
  const _SentimentError({required this.onRetry});

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
            l10n.marketSentimentCategory.toUpperCase(),
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
                  l10n.marketSentimentErrorTitle,
                  style: AppTypography.displaySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          // Names what still works. One section failing should not read
          // as the app failing — and this source has nothing to do with
          // the price or the network figures.
          Text(
            l10n.marketSentimentErrorBody,
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
              l10n.marketSentimentRetry.toUpperCase(),
              style: AppTypography.monoLabel.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Loading ----------------------------------------------------------------

class _SentimentLoading extends StatelessWidget {
  const _SentimentLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Statement(
      category: StatementCategory(
        label: l10n.marketSentimentCategory,
        trailing: [l10n.marketSentimentLoadingLabel],
      ),
      figures: const _LoadingFigures(),
      insight: const LoadingSkeleton(height: 44),
      evidence: const _LoadingEvidence(),
    );
  }
}

class _LoadingFigures extends StatelessWidget {
  const _LoadingFigures();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The verdict's place, so the screen does not jump when the
          // word arrives.
          LoadingSkeleton(width: 240, height: 36),
          SizedBox(height: AppSpacing.s5),
          LoadingSkeleton(width: 110, height: 10),
          SizedBox(height: AppSpacing.s3),
          LoadingSkeleton(width: 150, height: 34),
          SizedBox(height: AppSpacing.s5),
          LoadingSkeleton(height: 10, radius: 3),
        ],
      ),
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
        padding: const EdgeInsets.all(AppSpacing.s5),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(width: 180, height: 10),
            SizedBox(height: AppSpacing.s4),
            // The curve's own height, so the card does not resize under
            // the reader when the window arrives.
            LoadingSkeleton(height: SentimentSparkline.height, radius: 8),
            SizedBox(height: AppSpacing.s3),
            LoadingSkeleton(height: 10),
          ],
        ),
      ),
    );
  }
}

// -- Formatting -------------------------------------------------------------

/// One index value, in the reader's digits.
String _formatValue(String locale, int value) =>
    NumberFormat.decimalPattern(locale).format(value);

/// A calendar day with its year — the data stamp and the window's ends.
///
/// **Formatted in UTC, never converted to local time.** alternative.me
/// stamps every entry at 00:00 UTC, so `toLocal()` would move the date to
/// the previous day everywhere west of Greenwich and the screen would
/// report today's value under yesterday's date.
String _stamp(String locale, DateTime day) =>
    DateFormat.yMMMd(locale).format(day);

/// A day and its month, without the year: the day a band run began, which
/// is always inside the last thirty.
String _dayAndMonth(String locale, DateTime day) =>
    DateFormat.MMMMd(locale).format(day);

/// A day and its abbreviated month — the left end of the window's span,
/// where the year is carried by the right end.
String _dayAndShortMonth(String locale, DateTime day) =>
    DateFormat.MMMd(locale).format(day);
