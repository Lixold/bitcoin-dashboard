import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_icon.dart';

/// A titled group of [SettingsRow]s — the design system's
/// `SettingsSection`: a mono label above a single outlined card whose rows
/// are separated by hairlines.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.rows});

  /// Localised group title. Rendered upper-case, as the design system's
  /// `.settings-section__title` does.
  final String title;

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s3),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: scheme.outline),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One line inside a [SettingsSection].
///
/// Three shapes, all of them here rather than in three widgets, because
/// the design draws one row: a label with an optional description on the
/// left, and on the right either a [value], a [trailing] control, or —
/// when [onTap] is set — a value plus the chevron that says it opens
/// something.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.description,
    this.value,
    this.trailing,
    this.onTap,
  }) : assert(
         trailing == null || value == null,
         'a row carries either a control or a value, not both',
       );

  final String label;
  final String? description;

  /// The current setting, shown in the mono role.
  final String? value;

  /// A control that sets the row's value in place, such as an
  /// `AppSegmentedControl`.
  final Widget? trailing;

  /// Set when the row opens something — a picker, a sheet. Adds the
  /// chevron and the tap target; without it the row is a label, not a
  /// control.
  final VoidCallback? onTap;

  /// `--touch-min`.
  static const double minHeight = 44;

  /// Chevron size, as the design system uses it next to a value.
  static const double chevronSize = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              description!,
              style: AppTypography.bodySmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );

    final Widget? end = switch ((trailing, value)) {
      (final Widget control?, _) => control,
      (_, final String current?) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current,
            style: AppTypography.monoValue.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s2),
            BrandIcon(
              UiGlyph.chevronDown,
              size: chevronSize,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      _ => null,
    };

    // Side by side while the text and the control both fit at their
    // natural widths, stacked when they do not.
    //
    // [OverflowBar] makes that decision by measuring the two of them
    // against the width the row actually has, so it is the copy that
    // decides: a German label and its longer description stack at a width
    // where the English pair still sits on one line, and the fifteen
    // languages after them need no threshold of their own. A pixel
    // constant here would be a guess about text it has never seen — and
    // it would read like a layout breakpoint, which this is not.
    final Widget body = end == null
        ? Align(alignment: Alignment.centerLeft, child: text)
        : Center(
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.start,
              spacing: AppSpacing.s4,
              overflowSpacing: AppSpacing.s3,
              children: [text, end],
            ),
          );

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: body,
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      hoverColor: scheme.surfaceContainerHighest,
      child: content,
    );
  }
}
