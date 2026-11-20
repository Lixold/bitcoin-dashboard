import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/bands/band_scale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/mempool_provider.dart';
import '../domain/mempool_load.dart';
import '../domain/mempool_snapshot.dart';

/// How full the mempool is, and what a transaction pays to confirm in
/// about an hour (thesis F04.8, #112).
///
/// **Its own loading and error, not the section's.** The two statements
/// above read the daily CDN document; this one reads mempool.space every
/// minute. One failing says nothing about the other, so neither borrows
/// the other's state.
///
/// **Three states and no fourth.** There is no stale reading to show: the
/// provider keeps no cache, and an error replaces whatever was on screen
/// (decision 2 of #112).
class MempoolStatement extends ConsumerWidget {
  const MempoolStatement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(mempoolProvider);
    return reading.when(
      loading: () => const _MempoolLoading(),
      error: (_, _) =>
          _MempoolError(onRetry: () => ref.invalidate(mempoolProvider)),
      data: (snapshot) => _MempoolData(snapshot: snapshot),
    );
  }
}

// -- Formatting ---------------------------------------------------------------

/// Blocks' worth to one decimal, always.
///
/// Never rounded to a whole number: 29.6 would print as "30" next to the
/// verdict "Normal" and the caption "busy from 30", and the reader would
/// see a figure that contradicts its own band.
String _formatBlocks(String locale, double blocks) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(blocks);

/// A fee in sat/vB: whole numbers stay whole, a fractional rate keeps up
/// to two decimals.
String _formatFee(String locale, double fee) => (NumberFormat.decimalPattern(
  locale,
)..maximumFractionDigits = 2).format(fee);

String _formatBound(String locale, double bound) =>
    NumberFormat.decimalPattern(locale).format(bound);

// -- Data ---------------------------------------------------------------------

class _MempoolData extends StatelessWidget {
  const _MempoolData({required this.snapshot});

  final MempoolSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final band = snapshot.load;
    final blocks = _formatBlocks(locale, snapshot.blocksWorth);
    final time = DateFormat.Hm(locale).format(snapshot.observedAt.toLocal());

    return Statement(
      category: StatementCategory(
        label: l10n.mempoolCategory,
        isLive: true,
        trailing: [
          l10n.mempoolUpdatedAt(time),
          l10n.mempoolRefreshCadence(mempoolRefreshInterval.inSeconds),
        ],
      ),
      verdict: StatementVerdict(
        verdict: band.key.label(l10n),
        badgeLabel: l10n.mempoolBadge(blocks),
        tone: band.tone,
        infoLabel: l10n.mempoolInfoTrigger,
        onInfo: () => _showInfo(context, l10n),
      ),
      figures: _LoadFigure(snapshot: snapshot, band: band, locale: locale),
      insight: InsightPill(
        category: l10n.mempoolInsightCategory,
        text: band.key.insight(l10n, _formatFee(locale, snapshot.hourFee)),
        tone: band.tone,
      ),
      evidence: _FeeRows(snapshot: snapshot, locale: locale),
    );
  }
}

/// The queue in blocks' worth, what it is made of, and the band meter.
class _LoadFigure extends StatelessWidget {
  const _LoadFigure({
    required this.snapshot,
    required this.band,
    required this.locale,
  });

  final MempoolSnapshot snapshot;
  final Band<MempoolLoad> band;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final neutral = AppColors.neutralFor(theme.brightness);
    final boundaries = mempoolLoadScale.boundaries;
    final congestedFrom = boundaries.last;
    final distance = (snapshot.blocksWorth - congestedFrom).abs();
    final distanceText = _formatBlocks(locale, distance);
    final note = snapshot.blocksWorth < congestedFrom
        ? l10n.mempoolDistanceBelow(distanceText)
        : l10n.mempoolDistanceAbove(distanceText);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mempoolFigureLabel.toUpperCase(),
            style: AppTypography.monoLabel.copyWith(color: neutral),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatBlocks(locale, snapshot.blocksWorth),
                style: AppTypography.displayLarge.copyWith(
                  color: scheme.onSurface,
                  fontFeatures: AppTypography.figureFeatures,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Flexible(
                child: Text(
                  l10n.mempoolFigureUnit,
                  style: AppTypography.monoValue.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            l10n.mempoolTransactionCount(
              NumberFormat.decimalPattern(locale).format(snapshot.count),
            ),
            style: AppTypography.monoValue.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          _LoadMeter(
            blocks: snapshot.blocksWorth,
            boundaries: boundaries,
            fill: band.tone.colorFor(theme.brightness),
            locale: locale,
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.s4,
            runSpacing: AppSpacing.s1,
            children: [
              Text(
                l10n
                    .mempoolThresholdLower(
                      _formatBound(locale, boundaries[0]),
                      _formatBound(locale, boundaries[1]),
                    )
                    .toUpperCase(),
                style: AppTypography.monoLabel.copyWith(color: neutral),
              ),
              Text(
                l10n
                    .mempoolThresholdCongested(
                      _formatBound(locale, congestedFrom),
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
      ),
    );
  }
}

/// The shared [ProgressMeter] on a 0–[mempoolLoadMeterMax] track, with a
/// tick and its number at every band boundary.
///
/// The ticks are what make the fill readable as a band: without them a
/// bar a little past half full says nothing about how close the next
/// verdict is.
class _LoadMeter extends StatelessWidget {
  const _LoadMeter({
    required this.blocks,
    required this.boundaries,
    required this.fill,
    required this.locale,
  });

  final double blocks;
  final List<double> boundaries;
  final Color fill;
  final String locale;

  static const double trackHeight = 10;
  static const double tickOverhang = 4;
  static const double labelWidth = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final labelStyle = AppTypography.monoLabel.copyWith(
      color: AppColors.neutralFor(theme.brightness),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(double value) => width * (value / mempoolLoadMeterMax);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: trackHeight + tickOverhang * 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: tickOverhang,
                    left: 0,
                    right: 0,
                    child: ProgressMeter(
                      percent: blocks / mempoolLoadMeterMax * 100,
                      fill: fill,
                      height: trackHeight,
                    ),
                  ),
                  for (final boundary in boundaries)
                    Positioned(
                      left: at(boundary) - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: scheme.onSurface),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final boundary in boundaries)
                    Positioned(
                      left: at(boundary) - labelWidth / 2,
                      width: labelWidth,
                      child: Text(
                        _formatBound(locale, boundary),
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                    ),
                  Positioned(
                    right: 0,
                    child: Text(
                      l10n.mempoolMeterEnd(
                        _formatBound(locale, mempoolLoadMeterMax),
                      ),
                      style: labelStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The evidence: the other two fees, each labelled by what it buys, and
/// the source.
///
/// `hourFee` is not repeated here — the sentence already names it.
class _FeeRows extends StatelessWidget {
  const _FeeRows({required this.snapshot, required this.locale});

  final MempoolSnapshot snapshot;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.mempoolFeesTitle.toUpperCase(),
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.neutralFor(theme.brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          _FeeRow(
            label: l10n.mempoolFeeNextBlock,
            fee: _formatFee(locale, snapshot.fastestFee),
          ),
          _FeeRow(
            label: l10n.mempoolFeeNoPromise,
            fee: _formatFee(locale, snapshot.economyFee),
            isLast: true,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.mempoolSource.toUpperCase(),
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.fee, this.isLast = false});

  final String label;
  final String fee;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    final rule = BorderSide(color: scheme.outline);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: isLast ? rule : BorderSide.none),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: scheme.onSurface),
            ),
          ),
          Text(
            fee,
            style: AppTypography.displaySmall.copyWith(
              color: scheme.onSurface,
              fontFeatures: AppTypography.figureFeatures,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(
            l10n.mempoolFeeUnit,
            style: AppTypography.monoValue.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showInfo(BuildContext context, AppL10n l10n) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    constraints: const BoxConstraints(maxWidth: 600),
    // The sheet vocabulary of the two statements above: 32 px top radius,
    // surface ground, the accent edge that marks an explanation.
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
            l10n.mempoolInfoTitle,
            style: AppTypography.displayMedium.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.mempoolInfoBody,
            style: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    ),
  );
}

// -- Loading ------------------------------------------------------------------

/// The statement's frame with shimmer where the figures will be, sized
/// like what arrives so the section does not jump.
class _MempoolLoading extends StatelessWidget {
  const _MempoolLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Statement(
      category: StatementCategory(
        label: l10n.mempoolCategory,
        trailing: [l10n.mempoolLoading],
      ),
      figures: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(width: 180, height: 36),
            SizedBox(height: AppSpacing.s4),
            LoadingSkeleton(width: 120, height: 36),
            SizedBox(height: AppSpacing.s5),
            LoadingSkeleton(height: 10),
          ],
        ),
      ),
      insight: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
        child: const LoadingSkeleton(height: 72, radius: 10),
      ),
      evidence: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
        child: const Column(
          children: [
            LoadingSkeleton(height: 20),
            SizedBox(height: AppSpacing.s4),
            LoadingSkeleton(height: 20),
          ],
        ),
      ),
    );
  }
}

// -- Error --------------------------------------------------------------------

/// mempool.space did not answer, or answered with something unreadable.
///
/// The sentence names what still works and why nothing older stands in:
/// an absent fee estimate is honest, a stale one would be wrong.
class _MempoolError extends StatelessWidget {
  const _MempoolError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);

    return Statement(
      category: StatementCategory(label: l10n.mempoolCategory),
      evidence: ConstrainedBox(
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
                    l10n.mempoolErrorTitle,
                    style: AppTypography.displaySmall.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              l10n.mempoolErrorBody,
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
                style: AppTypography.monoLabel.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
