import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/price_history.dart';
import '../domain/price_range.dart';

/// How the curve should be read, which is the only thing that changes its
/// drawing.
enum TrendChartTone {
  /// A full series from a current payload: the brand accent, solid.
  current,

  /// A full series the app is serving from cache past the age threshold.
  /// Neutral rather than accent — the shape is still true, the last point
  /// is simply not "now" any more, and the live price in the hero is
  /// newer than it.
  aged,

  /// Too few points to carry a direction: amber and dashed, with the
  /// points themselves marked. A solid line through five points looks
  /// exactly like a trend, which is the one thing this state must not do.
  sparse,
}

/// The evidence under the trend statement: the curve, how many points it
/// is made of, where it starts and that it ends now.
///
/// **No axes, no grid, no tooltips, no zoom, no pan, no second series.**
/// The design draws one polyline and two labels; everything a chart
/// library offers beyond that answers a question this statement does not
/// ask. The figure above says what happened — this shows the shape it
/// happened in.
class PriceTrendChart extends StatelessWidget {
  const PriceTrendChart({
    super.key,
    required this.history,
    required this.range,
    required this.tone,
  });

  /// Chart height below [AppSpacing.wideLayoutBreakpoint] and at or above
  /// it. The design gives the wide layout a taller box because the curve
  /// gets wider there and a flat, wide box loses its shape.
  static const double compactHeight = 150;
  static const double wideHeight = 240;

  /// The height a chart takes in a [width]-wide window.
  ///
  /// The loading state asks too: a skeleton that does not hold the height
  /// the curve will take makes the whole screen jump when the series
  /// arrives.
  static double heightFor(double width) =>
      width >= AppSpacing.wideLayoutBreakpoint ? wideHeight : compactHeight;

  /// Stroke width of the curve, and the blur that gives it its glow.
  static const double lineWidth = 2;
  static const double glowBlur = 8;

  final PriceHistory history;
  final PriceRange range;
  final TrendChartTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final points = history.points;
    final colour = _colour(theme);
    final width = MediaQuery.sizeOf(context).width;

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
                    l10n.priceTrendChartTitle.toUpperCase(),
                    style: AppTypography.monoCaption.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                // Read off the series, never from a per-range constant:
                // the counts vary from day to day, and a number that
                // disagrees with the curve beside it is worse than none.
                Text(
                  l10n.priceTrendPoints(points.length).toUpperCase(),
                  style: AppTypography.monoLabel.copyWith(
                    color: AppColors.neutralFor(theme.brightness),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              height: heightFor(width),
              child: LineChart(_data(points, colour)),
            ),
            const SizedBox(height: AppSpacing.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _startLabel(locale, points.first.at),
                    style: _axisStyle(theme),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Text(
                  l10n.priceTrendNow.toUpperCase(),
                  style: _axisStyle(theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _axisStyle(ThemeData theme) => AppTypography.monoLabel.copyWith(
    color: AppColors.neutralFor(theme.brightness),
    letterSpacing: 1.1,
  );

  Color _colour(ThemeData theme) => switch (tone) {
    TrendChartTone.current => theme.colorScheme.primary,
    TrendChartTone.aged => AppColors.neutralFor(theme.brightness),
    TrendChartTone.sparse => AppColors.warningFor(theme.brightness),
  };

  /// The x label under the left edge: enough of the start to place it,
  /// and no more.
  ///
  /// A day needs the time, a year needs the year, and the three ranges in
  /// between are unambiguous with a day and a month.
  String _startLabel(String locale, DateTime at) {
    final local = at.toLocal();
    return switch (range) {
      PriceRange.oneDay => DateFormat.MMMd(locale).add_Hm().format(local),
      PriceRange.oneWeek ||
      PriceRange.oneMonth ||
      PriceRange.threeMonths => DateFormat.MMMd(locale).format(local),
      PriceRange.oneYear => DateFormat.yMMM(locale).format(local),
    }.toUpperCase();
  }

  LineChartData _data(List<PricePoint> points, Color colour) {
    final spots = <FlSpot>[
      for (final point in points)
        // The x value is the timestamp itself, read from the point rather
        // than counted off its index. The spacing inside a document is
        // nominal — the last interval is always shorter, because the last
        // point is "now" — so an evenly spaced x axis would draw the end
        // of every series slightly wrong (ADR-0005).
        FlSpot(point.at.millisecondsSinceEpoch.toDouble(), point.price),
    ];

    var low = spots.first.y;
    var high = spots.first.y;
    for (final spot in spots) {
      if (spot.y < low) low = spot.y;
      if (spot.y > high) high = spot.y;
    }
    // A flat series would give the chart a zero-height range to divide
    // by. Giving it a nominal one draws the flat line in the middle,
    // which is what a flat series looks like.
    final padding = high == low ? (high.abs() * 0.01) + 1 : (high - low) * 0.08;

    return LineChartData(
      minY: low - padding,
      maxY: high + padding,
      minX: spots.first.x,
      maxX: spots.last.x,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      // No touch handling: the design draws no tooltip and no crosshair,
      // and a chart that highlights a point on hover promises a reading
      // it then does not give.
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: colour,
          barWidth: lineWidth,
          // **Never smoothed.** A spline through these points invents
          // prices between them and rounds off exactly the spikes a
          // reader is looking for.
          isCurved: false,
          isStrokeCapRound: true,
          dashArray: tone == TrendChartTone.sparse ? const <int>[6, 10] : null,
          dotData: FlDotData(
            // The points are drawn only where there are few enough to
            // count, which is the state where each one is a fact rather
            // than a pixel.
            show: tone == TrendChartTone.sparse,
            getDotPainter: (spot, percent, bar, index) =>
                FlDotCirclePainter(radius: 3, color: colour, strokeWidth: 0),
          ),
          shadow: Shadow(
            color: colour.withValues(alpha: 0.45),
            blurRadius: glowBlur,
          ),
        ),
      ],
    );
  }
}
