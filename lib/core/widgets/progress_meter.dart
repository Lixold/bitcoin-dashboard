import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A horizontal track with a fractional fill: how much of a whole one
/// figure is.
///
/// Named after the design system's component of the same name, which is
/// what both callers were separately drawing. It is **not** a progress
/// indicator in the Material sense — nothing here advances on its own,
/// and the fill is a share of a fixed reference, not a step towards
/// completion.
///
/// **The fill is absolute, never relative to the largest value shown.**
/// A bar filling a quarter of its track means a quarter of the reference.
/// Scaling to the biggest entry on screen would make a 52 % and a 24 %
/// figure look alike, which is the opposite of what a meter is for.
///
/// The design system puts labels in the meter's corners; [topLeft] and
/// [topRight] are those. A caller whose labels sit elsewhere — the
/// network statement writes its thresholds *under* the bar — leaves them
/// null and lays its own out.
///
/// What this widget deliberately does not carry is the network
/// statement's threshold ticks. Those mark where a *verdict* changes, and
/// only a figure that has thresholds has them: the distance to the
/// all-time high is measured against 100 %, which is a reference, not a
/// line the reading crosses. The ticks stay with the statement that owns
/// them and are drawn over this track.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.percent,
    required this.fill,
    this.topLeft,
    this.topRight,
    this.height = 10,
    this.radius = 3,
  });

  /// The share to fill, 0–100. Values outside that range are clamped
  /// rather than rejected: a payload can carry a rounding artefact just
  /// over 100, and a bar is not the place to raise it.
  final double percent;

  final Color fill;

  /// Label above the track, left-aligned — usually what the fill is.
  final String? topLeft;

  /// Label above the track, right-aligned — usually what the track is.
  final String? topRight;

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final track = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (percent / 100).clamp(0.0, 1.0),
          // Both factors, never only the width. The alignment above
          // loosens what the fill is offered, and a `DecoratedBox` with
          // no child inside it takes the smallest size it is given — so
          // without this the fill lays out zero pixels high and the
          // track draws empty at every percentage.
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ),
    );

    if (topLeft == null && topRight == null) return track;

    final labelStyle = AppTypography.monoLabel.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (topLeft != null)
              Flexible(child: Text(topLeft!.toUpperCase(), style: labelStyle)),
            if (topRight != null)
              Flexible(
                child: Text(
                  topRight!.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        track,
      ],
    );
  }
}
