import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_info.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/settings_controller.dart';
import 'language_picker_sheet.dart';
import 'settings_section.dart';

/// Global preferences, in three groups: appearance, language and region,
/// and what the app is.
///
/// **No loading and no error state.** Everything on this screen is read
/// from the local Hive box that `main` opens before the first frame, and
/// every change is written back to it. There is nothing to fetch, so there
/// is nothing to wait for and nothing that can fail — an error branch here
/// would be a state the user can never reach.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// The amount the number-format row is shown in. It is the sample the
  /// design draws — the row states the format, and the format needs a
  /// figure to be legible in.
  static const double formatSample = 1234.56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPad =
                constraints.maxWidth >= AppSpacing.tabletBreakpoint
                ? AppSpacing.screenMarginTablet
                : AppSpacing.screenMarginMobile;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                AppSpacing.s5,
                horizontalPad,
                // The 80 px of clearance the design reserves at the foot
                // of every screen.
                AppSpacing.s7 + AppSpacing.s6,
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppHeader.settings(),
                      const SizedBox(height: AppSpacing.s6),
                      _ScreenTitle(
                        title: l10n.settingsTitle,
                        note: l10n.settingsPrivacyNote,
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      _AppearanceSection(
                        mode: settings.themeMode,
                        onChanged: controller.setThemeMode,
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      _LanguageAndRegionSection(
                        locale: settings.locale,
                        currency: settings.fiatCurrency,
                        onLocaleChanged: controller.setLocale,
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      const _AboutSection(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The screen's own title.
///
/// A section screen gets none — the navigation names it. Settings sits
/// outside the shell, so nothing else on screen says where the user is.
class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          // Set from the design, not inherited: `titleLarge` carries
          // `displaySmall` (18) since #72, and an inherited title would
          // render two screen titles at two sizes.
          style: AppTypography.displayMedium.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          note,
          style: AppTypography.bodySmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SettingsSection(
      title: l10n.settingsGroupAppearance,
      rows: [
        SettingsRow(
          label: l10n.settingsTheme,
          description: l10n.settingsThemeDescription,
          trailing: AppSegmentedControl<ThemeMode>(
            selected: mode,
            onSelected: onChanged,
            segments: [
              AppSegment(
                value: ThemeMode.system,
                label: l10n.settingsThemeSystem,
              ),
              AppSegment(
                value: ThemeMode.light,
                label: l10n.settingsThemeLight,
              ),
              AppSegment(value: ThemeMode.dark, label: l10n.settingsThemeDark),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageAndRegionSection extends StatelessWidget {
  const _LanguageAndRegionSection({
    required this.locale,
    required this.currency,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final String currency;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final sample = NumberFormat.currency(
      locale: locale.toLanguageTag(),
      name: currency,
      decimalDigits: 2,
    ).format(SettingsScreen.formatSample);

    return SettingsSection(
      title: l10n.settingsGroupLanguageRegion,
      rows: [
        SettingsRow(
          label: l10n.settingsLanguage,
          description: l10n.settingsLanguageDescription,
          value: languageLabel(locale, l10n),
          onTap: () => LanguagePickerSheet.show(
            context: context,
            locales: AppL10n.supportedLocales,
            selected: locale,
            onSelect: onLocaleChanged,
          ),
        ),
        // A label, not a control: the picker behind it arrives with #32.
        SettingsRow(
          label: l10n.settingsCurrency,
          description: l10n.settingsCurrencyDescription,
          value: currency,
        ),
        SettingsRow(
          label: l10n.settingsNumberFormat,
          description: l10n.settingsNumberFormatDescription,
          value: sample,
        ),
      ],
    );
  }
}

/// What the app is, where its data comes from, and where to report it
/// when something is wrong.
///
/// Three of the five rows leave the app. They hand their address to the
/// platform browser and read nothing back: the app opens no connection of
/// its own here, so a link target is not a host under CLAUDE.md §1 — see
/// SECURITY.md. What the browser then finds is the browser's screen to
/// draw, which is why nothing is checked first and no error state is
/// offered.
///
/// Version, licence identifier and data sources stay facts: an address
/// they could open would not tell the reader more than the line already
/// does.
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    // Read once, here: the opener has to run inside the tap itself. On
    // the web a hop through an `await` costs the click its gesture and
    // the tab is blocked without a word — `core/links/url_opener.dart`.
    final open = ref.watch(urlOpenerProvider);

    return SettingsSection(
      title: l10n.settingsGroupAbout,
      rows: [
        SettingsRow(label: l10n.settingsVersion, value: AppInfo.version),
        SettingsRow(
          label: l10n.settingsLicence,
          value: AppInfo.licence,
          hint: l10n.settingsOpensInBrowser,
          onTap: () => open(AppInfo.licenceUrl),
        ),
        SettingsRow(
          label: l10n.settingsDataSources,
          description: AppInfo.dataSources,
        ),
        SettingsRow(
          label: l10n.settingsSourceCode,
          description: AppInfo.repository,
          hint: l10n.settingsOpensInBrowser,
          onTap: () => open(AppInfo.repositoryUrl),
        ),
        SettingsRow(
          label: l10n.settingsReportIssue,
          description: AppInfo.newIssue,
          hint: l10n.settingsOpensInBrowser,
          onTap: () => open(AppInfo.newIssueUrl),
        ),
      ],
    );
  }
}
