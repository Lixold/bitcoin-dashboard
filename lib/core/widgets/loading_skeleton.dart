import 'package:flutter/material.dart';

/// A block standing in for content that has not arrived.
///
/// Named after the design system's component. It is deliberately still:
/// no shimmer, no pulse. A skeleton says "this is coming", and an
/// animation on every screen that loads says it louder than the content
/// it is standing in for.
///
/// **A skeleton is not a placeholder in the sense CLAUDE.md §5 forbids.**
/// The rule is about figures a reader can mistake for real ones — a zero
/// in a price line, a dash where a share belongs. A blank block claims
/// nothing and is the honest way to hold the space a figure will take.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
  });

  /// Unset means "as wide as the parent allows", which is what a skeleton
  /// standing in for a full-width row wants.
  final double? width;

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
