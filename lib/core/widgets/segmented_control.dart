import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// One option in an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;

  /// Already-localised copy. The control renders it as given.
  final String label;
}

/// The two densities `.segmented` ships, and the sizes that make them.
///
/// [comfortable] is the settings density: a 44 px option, which is also
/// the minimum touch target. [compact] is the price screen's range strip,
/// where the control sits inside a statement rather than being the
/// statement, and a second 44 px bar above the verdict would read as
/// another heading.
enum SegmentedDensity {
  comfortable(optionHeight: 44, optionPadding: 14, borderRadius: 8),
  compact(optionHeight: 34, optionPadding: 12, borderRadius: 6);

  const SegmentedDensity({
    required this.optionHeight,
    required this.optionPadding,
    required this.borderRadius,
  });

  /// Material's own floor under a segment, from the [TextButton] each one
  /// is built on.
  static const double _materialMinHeight = 40;

  /// Logical pixels one step of [VisualDensity] is worth.
  static const double _densityStep = 4;

  /// Height of one option.
  ///
  /// **Two properties are needed to set it, because one of them is not
  /// carried across.** [SegmentedButton] rebuilds a caller's [ButtonStyle]
  /// property by property for its segments and leaves `minimumSize` out,
  /// so a segment keeps Material's 40 px floor however small the label is
  /// sized. `visualDensity` *is* copied and moves that floor, so the two
  /// together are what a 34 px option takes: the label gives the height,
  /// [density] lowers the floor out of its way.
  final double optionHeight;

  /// `.segmented__option` horizontal padding.
  final double optionPadding;

  /// `.segmented` corner radius.
  final double borderRadius;

  /// The density that moves Material's floor out of [optionHeight]'s way.
  ///
  /// Only ever downward. Raising the floor to meet a taller option would
  /// also widen the padding the density adds around it, so an option
  /// already taller than the floor is left to size itself.
  VisualDensity get density {
    final steps = (optionHeight - _materialMinHeight) / _densityStep;
    return VisualDensity(vertical: steps < 0 ? steps : 0);
  }
}

/// The design system's `SegmentedControl`: one connected row of options
/// where exactly one is selected.
///
/// Material's [SegmentedButton] carries the behaviour — keyboard handling,
/// semantics, the divider between options — and only the tokens are ours.
/// A hand-rolled row of buttons would have to reimplement all of that.
///
/// Selection is structural rather than decorative: the selected option
/// takes a `surfaceContainerHighest` fill and a `primary` label, the same
/// pair the rest of the system uses to mark a current choice.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.density = SegmentedDensity.comfortable,
    this.block = false,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Which of the two densities to render — see [SegmentedDensity].
  final SegmentedDensity density;

  /// `.segmented--block`: fills the row and gives every option the same
  /// width, rather than sizing the group to its widest label.
  ///
  /// The five range labels are between two and three characters, so
  /// without this the strip would be a small cluster on the left of a
  /// wide screen and its options would be uneven.
  final bool block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SegmentedButton<T>(
      showSelectedIcon: false,
      // Non-null makes the group fill its parent and divide the width
      // evenly between the options; null leaves it at its intrinsic size.
      expandedInsets: block ? EdgeInsets.zero : null,
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(
            value: segment.value,
            label: SizedBox(
              height: density.optionHeight,
              child: Center(child: Text(segment.label)),
            ),
          ),
      ],
      selected: <T>{selected},
      onSelectionChanged: (selection) => onSelected(selection.first),
      style: ButtonStyle(
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: density.optionPadding),
        ),
        // The option height is the target; Material must not pad around
        // it.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: density.density,
        // `.segmented__option` sets no tracking of its own — the mono
        // caption's 1.1 is uppercase tracking, and these labels are not
        // uppercase.
        textStyle: WidgetStatePropertyAll<TextStyle>(
          AppTypography.monoCaption.copyWith(letterSpacing: 0),
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? scheme.surfaceContainerHighest
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: scheme.outline),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(density.borderRadius),
            ),
          ),
        ),
      ),
    );
  }
}
