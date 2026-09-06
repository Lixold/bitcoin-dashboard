import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/mining_pool.dart';
import '../domain/pool_concentration.dart';
import 'share_format.dart';

/// The evidence behind the concentration statement: every pool the
/// payload listed, as a share of the whole 24-hour sample.
///
/// **The bars are absolute, not relative to the largest pool.** A bar
/// filling a quarter of its track means a quarter of the hashrate. Scaling
/// to the leader would make a 52 % pool and a 24 % pool look identical,
/// which is the opposite of what this list is here to show.
///
/// The three largest are grouped and always visible — they are what the
/// statement claims. The rest is one tap away: ten rows is a lot of
/// evidence to put in front of a reader who only wanted the verdict.
class PoolShareList extends StatefulWidget {
  const PoolShareList({
    super.key,
    required this.pools,
    required this.topThreeShare,
    required this.listedShare,
    required this.tone,
  });

  /// Pools sorted largest first.
  final List<MiningPool> pools;

  /// Combined share of the leaders, or `null` when fewer than three pools
  /// were listed and the group has nothing to sum.
  final double? topThreeShare;

  final double listedShare;
  final StatementTone tone;

  @override
  State<PoolShareList> createState() => _PoolShareListState();
}

class _PoolShareListState extends State<PoolShareList> {
  bool _restVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final neutral = AppColors.neutralFor(theme.brightness);
    final toneColor = widget.tone.colorFor(theme.brightness);

    final leaders = widget.pools.take(PoolConcentration.minimumPools).toList();
    final rest = widget.pools.skip(PoolConcentration.minimumPools).toList();
    final isComplete = widget.pools.length >= PoolConcentration.minimumPools;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Statement.evidenceMaxWidth),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l10n.networkPoolsEvidenceTitle.toUpperCase(),
                    style: AppTypography.monoLabel.copyWith(color: neutral),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  l10n
                      .networkPoolsPayloadCount(widget.pools.length)
                      .toUpperCase(),
                  style: AppTypography.monoLabel.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),

            if (leaders.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(AppSpacing.s2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.topThreeShare != null)
                      Text(
                        l10n
                            .networkPoolsTopThreeBox(
                              formatShare(locale, widget.topThreeShare!),
                            )
                            .toUpperCase(),
                        style: AppTypography.monoLabel.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.s3),
                    for (var i = 0; i < leaders.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == leaders.length - 1
                              ? AppSpacing.s4
                              : AppSpacing.s3,
                        ),
                        child: _PoolRow(
                          rank: i + 1,
                          pool: leaders[i],
                          color: toneColor,
                          locale: locale,
                        ),
                      ),
                  ],
                ),
              ),

            if (rest.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s4),
              _RestToggle(
                expanded: _restVisible,
                onTap: () => setState(() => _restVisible = !_restVisible),
              ),
            ],

            if (_restVisible)
              for (var i = 0; i < rest.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? AppSpacing.s4 : AppSpacing.s3,
                  ),
                  child: _PoolRow(
                    rank: PoolConcentration.minimumPools + i + 1,
                    pool: rest[i],
                    color: toneColor,
                    locale: locale,
                    faint: true,
                  ),
                ),

            const SizedBox(height: AppSpacing.s5),
            Divider(height: 1, color: scheme.outline),
            const SizedBox(height: AppSpacing.s4),

            // What the list covers. Without this the reader has no way to
            // know the bars stop short of 100 %.
            if (isComplete) ...[
              _CoverageTrack(
                share: widget.listedShare,
                color: neutral,
                outline: scheme.outline,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                l10n
                    .networkPoolsCoverage(
                      formatShareExact(locale, widget.listedShare),
                    )
                    .toUpperCase(),
                style: AppTypography.monoLabel.copyWith(
                  color: neutral,
                  height: 1.5,
                ),
              ),
            ] else
              Text(
                l10n.networkPoolsEmptyFooter(widget.pools.length).toUpperCase(),
                style: AppTypography.monoLabel.copyWith(
                  color: neutral,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One pool: rank, name, its share as a bar, and the figure.
class _PoolRow extends StatelessWidget {
  const _PoolRow({
    required this.rank,
    required this.pool,
    required this.color,
    required this.locale,
    this.faint = false,
  });

  final int rank;
  final MiningPool pool;
  final Color color;
  final String locale;

  /// Rows outside the top three are dimmed: they are context, not the
  /// claim.
  final bool faint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            '$rank',
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        SizedBox(
          width: 112,
          child: Text(
            pool.name,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoValue.copyWith(
              fontSize: 12,
              color: faint ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: faint ? 8 : 10,
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (pool.hashratePercent / 100).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: faint ? color.withValues(alpha: 0.45) : color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        SizedBox(
          width: 64,
          child: Text(
            formatShareDetailed(locale, pool.hashratePercent),
            textAlign: TextAlign.right,
            style: AppTypography.monoValue.copyWith(
              fontSize: 12,
              color: faint ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _RestToggle extends StatelessWidget {
  const _RestToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          side: BorderSide(color: scheme.outline),
          shape: const StadiumBorder(),
          foregroundColor: scheme.onSurfaceVariant,
        ),
        child: Text(
          (expanded ? l10n.networkPoolsHideRest : l10n.networkPoolsShowRest)
              .toUpperCase(),
          style: AppTypography.monoLabel.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The dashed track showing how much of the whole the list accounts for.
class _CoverageTrack extends StatelessWidget {
  const _CoverageTrack({
    required this.share,
    required this.color,
    required this.outline,
  });

  final double share;
  final Color color;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: (share / 100).clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
