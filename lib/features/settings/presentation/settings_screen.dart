import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.settingsLanguage),
            trailing: DropdownButton<Locale>(
              value: settings.locale,
              onChanged: (l) {
                if (l != null) controller.setLocale(l);
              },
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
                DropdownMenuItem(value: Locale('de'), child: Text('Deutsch')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsTheme),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (m) {
                if (m != null) controller.setThemeMode(m);
              },
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.settingsThemeSystem),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.settingsThemeLight),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.settingsThemeDark),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money_outlined),
            title: Text(l10n.settingsCurrency),
            // Currency picker arrives with the FX-rates feature.
            trailing: Text(settings.fiatCurrency),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: const Text('Bitcoin Dashboard 0.1.0 — MIT licence'),
          ),
        ],
      ),
    );
  }
}
