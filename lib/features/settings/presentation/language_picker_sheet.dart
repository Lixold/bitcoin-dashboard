import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The language a [Locale] is called in the language currently on screen.
///
/// Endonyms are deliberately not used: the design shows `Language ·
/// German` in the English locale, so the name follows the UI language
/// rather than its own. An unmapped locale falls back to its tag, which is
/// wrong-looking enough to be noticed when a locale is added without its
/// two strings.
String languageLabel(Locale locale, AppL10n l10n) =>
    switch (locale.languageCode) {
      'de' => l10n.settingsLanguageGerman,
      'en' => l10n.settingsLanguageEnglish,
      _ => locale.toLanguageTag(),
    };

/// Slide-up picker listing every supported language.
///
/// A picker rather than a segmented control: two languages today, fifteen
/// planned, and a segmented row does not survive that.
///
/// The design does not draw this sheet. It follows the vocabulary of the
/// navigation sheet — same surface, same 32 px top radius, same drag
/// handle and mono header — so the app gains no second sheet language.
class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({
    super.key,
    required this.locales,
    required this.selected,
    required this.onSelect,
  });

  final List<Locale> locales;
  final Locale selected;
  final ValueChanged<Locale> onSelect;

  /// Opens the sheet and returns once it is closed.
  static Future<void> show({
    required BuildContext context,
    required List<Locale> locales,
    required Locale selected,
    required ValueChanged<Locale> onSelect,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => LanguagePickerSheet(
        locales: locales,
        selected: selected,
        onSelect: (locale) {
          onSelect(locale);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s5 + viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            l10n.settingsLanguagePickerTitle,
            textAlign: TextAlign.center,
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          for (final locale in locales)
            _LanguageOption(
              label: languageLabel(locale, l10n),
              isSelected: locale.languageCode == selected.languageCode,
              onTap: () => onSelect(locale),
            ),
        ],
      ),
    );
  }
}

/// One language in the sheet.
///
/// The selection is marked the way the rest of the system marks a current
/// choice — `surfaceContainerHighest` behind a `primary` label. The icon
/// set has ten glyphs and no check mark, and this is not the slice that
/// adds an eleventh.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          child: Text(
            label,
            style: AppTypography.bodyLarge.copyWith(
              color: isSelected ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
