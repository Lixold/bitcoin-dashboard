import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/difficulty_provider.dart';
import '../domain/difficulty_snapshot.dart';
import 'countdown_format.dart';

/// When the next difficulty adjustment comes and which way it is expected
/// to go (thesis F04.6, #46).
///
/// **Its own loading and error, not the section's.** It reads
/// mempool.space every five minutes; the statements above read the daily
/// CDN document and the mempool every minute. One failing says nothing
/// about the others.
///
/// **Three states and no fourth.** There is no stale reading to show: the
/// provider keeps no cache, and an error replaces whatever was on screen
/// (decision 4 of #46).
class DifficultyStatement extends ConsumerWidget {
  const DifficultyStatement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(difficultyProvider);
    return reading.when(
      loading: () => const _DifficultyLoading(),
      error: (_, _) =>
          _DifficultyError(onRetry: () => ref.invalidate(difficultyProvider)),
      data: (snapshot) => _DifficultyData(snapshot: snapshot),
    );
  }
}

// -- Formatting ---------------------------------------------------------------

/// One decimal, always: the change, the block time and the position.
String _oneDecimal(String locale, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(value);

/// The change with its sign, for the badge: "+10.2", "−3.4".
///
/// The sign is written explicitly so a rise reads as one at a glance; the
/// sentence says the direction in words and takes [_oneDecimal] of the
/// absolute value instead.
String _signedChange(String locale, double change) {
  final size = _oneDecimal(locale, change.abs());
  if (change > 0) return '+$size';
  if (change < 0) return '−$size';
  return size;
}

String _count(String locale, int value) =>
    NumberFormat.decimalPattern(locale).format(value);

// -- Data ---------------------------------------------------------------------

class _DifficultyData extends StatelessWidget {
  const _DifficultyData({required this.snapshot});

  final DifficultySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final band = snapshot.direction;
    final time = DateFormat.Hm(locale).format(snapshot.observedAt.toLocal());
    final about = aboutRemaining(snapshot.remaining);

    return Statement(
      category: StatementCategory(
        label: l10n.difficultyCategory,
        isLive: true,
        trailing: [
          l10n.difficultyUpdatedAt(time),
          l10n.difficultyRefreshCadence(difficultyRefreshInterval.inMinutes),
        ],
      ),
      verdict: StatementVerdict(
        verdict: band.key.label(l10n),
        badgeLabel: l10n.difficultyBadge(
          _signedChange(locale, snapshot.shownChangePercent),
        ),
        tone: band.tone,
        infoLabel: l10n.difficultyInfoTrigger,
        onInfo: () => _showInfo(context, l10n),
      ),
      figures: _Countdown(remaining: snapshot.remaining),
      insight: InsightPill(
        category: l10n.difficultyInsightCategory,
        text: band.key.insight(
          l10n,
          about.unit.phrase(l10n, about.value),
          _oneDecimal(locale, snapshot.shownChangePercent.abs()),
        ),
        tone: band.tone,
      ),
      evidence: _Evidence(snapshot: snapshot, locale: locale),
    );
  }
}

/// The time to the adjustment as the design system's countdown grid: a
/// serif number over a mono unit, two units at most.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.difficultyFigureLabel.toUpperCase(),
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.neutralFor(theme.brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s5,
            runSpacing: AppSpacing.s2,
            children: [
              for (final part in countdownParts(remaining))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _count(locale, part.value),
                      style: AppTypography.displayLarge.copyWith(
                        color: scheme.onSurface,
                        fontFeatures: AppTypography.figureFeatures,
                      ),
                    ),
                    Text(
                      part.unit.label(l10n, part.value).toUpperCase(),
                      style: AppTypography.monoLabel.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The evidence: where in the period the estimate stands, and the block
/// time that drives it.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.snapshot, required this.locale});

  final DifficultySnapshot snapshot;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final neutral = AppColors.neutralFor(theme.brightness);
    final titleStyle = AppTypography.monoLabel.copyWith(color: neutral);
    final noteStyle = AppTypography.bodyMedium.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final averageMinutes =
        snapshot.averageBlockTime.inMilliseconds /
        Duration.millisecondsPerMinute;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.difficultyPositionTitle.toUpperCase(), style: titleStyle),
          const SizedBox(height: AppSpacing.s3),
          ProgressMeter(
            percent: snapshot.progressPercent,
            fill: neutral,
            topLeft: l10n
                .difficultyPositionBlocks(
                  _count(locale, snapshot.blocksMined),
                  _count(locale, blocksPerRetargetPeriod),
                )
                .toUpperCase(),
            topRight: l10n.difficultyPositionPercent(
              _oneDecimal(locale, snapshot.progressPercent),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.difficultyPositionNote(
              snapshot.remainingBlocks,
              _count(locale, snapshot.blocksMined),
              _count(locale, snapshot.remainingBlocks),
            ),
            style: noteStyle,
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(l10n.difficultyBlockTimeTitle.toUpperCase(), style: titleStyle),
          const SizedBox(height: AppSpacing.s2),
          _BlockTimeRow(
            label: l10n.difficultyBlockTimeAverage,
            minutes: _oneDecimal(locale, averageMinutes),
          ),
          _BlockTimeRow(
            label: l10n.difficultyBlockTimeTarget,
            minutes: _count(locale, targetBlockTime.inMinutes),
            isLast: true,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(snapshot.direction.key.reason(l10n), style: noteStyle),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.difficultySource.toUpperCase(),
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockTimeRow extends StatelessWidget {
  const _BlockTimeRow({
    required this.label,
    required this.minutes,
    this.isLast = false,
  });

  final String label;
  final String minutes;
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
            minutes,
            style: AppTypography.displaySmall.copyWith(
              color: scheme.onSurface,
              fontFeatures: AppTypography.figureFeatures,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(
            l10n.difficultyMinutesUnit,
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
    // The sheet vocabulary of the statements above: 32 px top radius,
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
            l10n.difficultyInfoTitle,
            style: AppTypography.displayMedium.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l10n.difficultyInfoBody,
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
class _DifficultyLoading extends StatelessWidget {
  const _DifficultyLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Statement(
      category: StatementCategory(
        label: l10n.difficultyCategory,
        trailing: [l10n.difficultyLoading],
      ),
      figures: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Statement.proseMaxWidth),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(width: 180, height: 36),
            SizedBox(height: AppSpacing.s4),
            LoadingSkeleton(width: 200, height: 56),
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
            LoadingSkeleton(height: 10),
            SizedBox(height: AppSpacing.s4),
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
/// an absent countdown is honest, a stale one would be wrong.
class _DifficultyError extends StatelessWidget {
  const _DifficultyError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);

    return Statement(
      category: StatementCategory(label: l10n.difficultyCategory),
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
                    l10n.difficultyErrorTitle,
                    style: AppTypography.displaySmall.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              l10n.difficultyErrorBody,
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
