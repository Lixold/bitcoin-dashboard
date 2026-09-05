import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// One option in an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;

  /// Already-localised copy. The control renders it as given.
  final String label;
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
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  /// The comfortable density: a 44 px option, which is also the minimum
  /// touch target.
  ///
  /// The design system's second density (compact) belongs to the price
  /// chart's timeframe control and arrives with it in #31 — this widget
  /// ships one density because it has one consumer.
  ///
  /// It is set on the label rather than through `ButtonStyle.minimumSize`:
  /// [SegmentedButton] copies a caller's style property by property onto
  /// its segments and does not carry `minimumSize` across, so the segments
  /// would keep Material's 40 px default. Sizing the label sets the height
  /// the button then has to take.
  static const double optionHeight = 44;

  /// `.segmented__option` padding.
  static const double optionPadding = 14;

  /// `.segmented` corner radius.
  static const double borderRadius = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(
            value: segment.value,
            label: SizedBox(
              height: optionHeight,
              child: Center(child: Text(segment.label)),
            ),
          ),
      ],
      selected: <T>{selected},
      onSelectionChanged: (selection) => onSelected(selection.first),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: optionPadding),
        ),
        // The 44 px option is the target; Material must not pad around it.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
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
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          ),
        ),
      ),
    );
  }
}
