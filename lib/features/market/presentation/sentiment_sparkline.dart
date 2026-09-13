import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/statement.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/sentiment_band.dart';
import '../domain/sentiment_index.dart';

/// The window behind the statement: thirty daily values drawn over the
/// five bands they are read against.
///
/// **Two things make this not a second `PriceTrendChart`, and neither is
/// negotiable.**
///
/// The axis is fixed to 0–100 rather than scaled to the window. A curve
/// scaled to its own minimum and maximum would draw a calm week with the
/// same amplitude as a crash, and the stripes behind it — the whole
/// reason this chart exists — would stop meaning anything, because the
/// band a value sits in would no longer be where the eye finds it.
///
/// The stripes are the bands, with the current one tinted in its tone and
/// the others left as faint alternating ground. That is what turns a line
/// into a reading: the reader sees not only that the value moved, but
/// which bands it moved through.
///
/// Beyond that, the same restraint as the price curve: one polyline, no
/// axes, no grid, no tooltip, no touch.
class SentimentSparkline extends StatelessWidget {
  const SentimentSparkline({super.key, required this.index});

  /// Height of the drawing area. The band labels sit inside it, so it has
  /// to stay tall enough for five rows of mono caption — at 184 the
  /// narrowest band, the eight points of Neutral, is still 15 px high.
  static const double height = 184;

  static const double lineWidth = 2;

  /// How far the band names sit from the right edge.
  static const double labelInset = AppSpacing.s2;

  final SentimentIndex index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final current = index.band;
    final toneColour = current.tone.colorFor(theme.brightness);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: LineChart(_data(scheme, toneColour))),
          for (final band in sentimentScale.bands)
            _BandLabel(
              text: band.key.label(l10n),
              from: band.from,
              to: sentimentScale.upperBoundOf(band) ?? sentimentScaleMax,
              colour: band.key == current.key
                  ? scheme.onSurface
                  : AppColors.neutralFor(theme.brightness),
            ),
        ],
      ),
    );
  }

  LineChartData _data(ColorScheme scheme, Color toneColour) {
    final points = index.points;
    final current = index.band;

    return LineChartData(
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      // The scale itself, not the window. See the class comment.
      minY: sentimentScaleMin,
      maxY: sentimentScaleMax,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      // No touch handling: the design draws no tooltip and no crosshair,
      // and a chart that highlights a point on hover promises a reading
      // it then does not give.
      lineTouchData: const LineTouchData(enabled: false),
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          for (var i = 0; i < sentimentScale.bands.length; i++)
            HorizontalRangeAnnotation(
              y1: sentimentScale.bands[i].from,
              y2:
                  sentimentScale.upperBoundOf(sentimentScale.bands[i]) ??
                  sentimentScaleMax,
              color: sentimentScale.bands[i].key == current.key
                  ? toneColour.withValues(alpha: 0.14)
                  : i.isEven
                  ? scheme.onSurface.withValues(alpha: 0.04)
                  : Colors.transparent,
            ),
        ],
      ),
      extraLinesData: ExtraLinesData(
        // Under the curve, never over it: these are the ground the
        // reading is taken against.
        extraLinesOnTop: false,
        horizontalLines: [
          for (final boundary in sentimentScale.boundaries)
            HorizontalLine(y: boundary, color: scheme.outline, strokeWidth: 1),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < points.length; i++)
              // The x value is the index, not the timestamp: this series
              // is one value per calendar day with no gaps, so counting
              // days and spacing them evenly are the same thing.
              FlSpot(i.toDouble(), points[i].value.toDouble()),
          ],
          color: scheme.onSurface,
          barWidth: lineWidth,
          // **Never smoothed.** A spline through daily values invents
          // readings between them, and it would carry the curve across a
          // band boundary the index never crossed.
          isCurved: false,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}

/// One band's name, laid over the stripe it belongs to.
///
/// Positioned against the same 0–100 axis the chart uses, so the label
/// and its stripe cannot drift apart.
class _BandLabel extends StatelessWidget {
  const _BandLabel({
    required this.text,
    required this.from,
    required this.to,
    required this.colour,
  });

  final String text;
  final double from;
  final double to;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    const span = sentimentScaleMax - sentimentScaleMin;
    return Positioned(
      right: SentimentSparkline.labelInset,
      top: SentimentSparkline.height * (sentimentScaleMax - to) / span,
      height: SentimentSparkline.height * (to - from) / span,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text.toUpperCase(),
          style: AppTypography.monoLabel.copyWith(color: colour),
        ),
      ),
    );
  }
}
