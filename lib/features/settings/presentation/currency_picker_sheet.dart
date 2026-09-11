import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../core/fx/fx_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/settings_controller.dart';

/// Slide-up picker listing every currency the published rates reach.
///
/// **One sheet, two entries.** The header pill on a section screen and the
/// currency row in settings open this same sheet. A second picker would be
/// a second place to keep the list, the order and the selected marker in
/// step, and they would drift the first time one of them changed.
///
/// **The list is the payload's, not a constant in the code.** Thirty codes
/// written out here would be a second copy of something the producer
/// already publishes, and it would go wrong the first time the ECB drops a
/// currency — the app would offer a code no rate can honour. `FxRates`
/// filters the producer's own list down to what it can actually convert
/// into, and this sheet shows that.
///
/// The design does not draw this sheet. It follows the vocabulary of the
/// language picker — same surface, same 32 px top radius, same drag handle
/// and mono header — so the app gains no second sheet language.
class CurrencyPickerSheet extends ConsumerWidget {
  const CurrencyPickerSheet({super.key});

  /// Opens the sheet and returns once it is closed.
  static Future<void> show(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: false,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => const CurrencyPickerSheet(),
    );
  }

  /// Share of the screen the list may take before it scrolls inside the
  /// sheet. Thirty rows do not fit on a phone, and a sheet that runs off
  /// the bottom hides the selected one as often as not.
  static const double maxHeightFactor = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppL10n.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final selected = ref.watch(
      settingsControllerProvider.select((settings) => settings.fiatCurrency),
    );
    final ratesAsync = ref.watch(fxRatesProvider);

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
            l10n.settingsCurrencyPickerTitle,
            textAlign: TextAlign.center,
            style: AppTypography.monoCaption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          switch (ratesAsync) {
            // An empty document reaches the reader as the unreachable one
            // does: there is no currency to offer either way, and the two
            // have the same remedy.
            AsyncValue(:final value?) when value.currencies.isNotEmpty =>
              _Options(codes: value.currencies, selected: selected),
            AsyncLoading() => const _ListSkeleton(),
            _ => _Unavailable(message: l10n.settingsCurrencyPickerUnavailable),
          },
        ],
      ),
    );
  }
}

/// The currencies themselves, scrollable once thirty of them do not fit.
class _Options extends ConsumerWidget {
  const _Options({required this.codes, required this.selected});

  final List<String> codes;
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toLanguageTag();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height *
            CurrencyPickerSheet.maxHeightFactor,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final code in codes)
            _CurrencyOption(
              code: code,
              symbol: currencySymbol(locale, code),
              isSelected: code == selected,
              onTap: () {
                // The write goes to the local Hive box and the sheet does
                // not wait for it: the state is set synchronously, so the
                // screen behind is already correct when this closes.
                unawaited(
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setFiatCurrency(code),
                );
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

/// One currency in the sheet: the code, and the symbol it will be set in.
///
/// **The code leads and the symbol follows it.** `intl` gives this app
/// currency symbols but no localised currency *names*, and eight of the
/// thirty codes share the dollar sign — so the symbol alone would not tell
/// two of them apart, and a hand-written name table would be sixty strings
/// the design never asked for. The code is the unambiguous half and the
/// symbol shows what the amounts will carry.
///
/// The selection is marked the way the rest of the system marks a current
/// choice — `surfaceContainerHighest` behind a `primary` label. The icon
/// set has ten glyphs and no check mark, and this is not the slice that
/// adds an eleventh.
class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.code,
    required this.symbol,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String symbol;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = isSelected ? scheme.primary : scheme.onSurface;

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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: AppTypography.bodyLarge.copyWith(color: colour),
                ),
              ),
              Text(
                symbol,
                style: AppTypography.monoValue.copyWith(
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list while it is being fetched.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  /// Enough rows to read as a list rather than as one stray bar.
  static const int rows = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: LoadingSkeleton(height: 20),
          ),
      ],
    );
  }
}

/// No list to show, and why that changes nothing about the setting.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
