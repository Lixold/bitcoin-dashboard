import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/language_picker_sheet.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required Locale locale,
  required ValueChanged<Locale> onSelect,
}) => MaterialApp(
  theme: AppTheme.dark(),
  locale: locale,
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: const [
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: LanguagePickerSheet(
      locales: AppL10n.supportedLocales,
      selected: locale,
      onSelect: onSelect,
    ),
  ),
);

void main() {
  group('languageLabel', () {
    test('names a language in the language on screen', () async {
      final en = await AppL10n.delegate.load(const Locale('en'));
      final de = await AppL10n.delegate.load(const Locale('de'));

      expect(languageLabel(const Locale('de'), en), 'German');
      expect(languageLabel(const Locale('en'), en), 'English');
      expect(languageLabel(const Locale('de'), de), 'Deutsch');
      expect(languageLabel(const Locale('en'), de), 'Englisch');
    });

    test('falls back to the tag for a locale nobody named yet', () async {
      final en = await AppL10n.delegate.load(const Locale('en'));

      // Visible enough to be caught when a locale ships without its two
      // strings, rather than silently reading as English.
      expect(languageLabel(const Locale('fr'), en), 'fr');
    });
  });

  testWidgets('lists every supported language', (tester) async {
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onSelect: (_) {}),
    );

    expect(find.text('English'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
  });

  testWidgets('marks the active language the way the system marks a choice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onSelect: (_) {}),
    );

    final active = tester.widget<Text>(find.text('English'));
    final other = tester.widget<Text>(find.text('German'));

    expect(active.style?.color, AppColors.primary);
    expect(other.style?.color, AppColors.darkOnSurface);
  });

  testWidgets('reports the language that was tapped', (tester) async {
    final picked = <Locale>[];

    await tester.pumpWidget(
      _harness(locale: const Locale('en'), onSelect: picked.add),
    );

    await tester.tap(find.text('German'));
    await tester.pumpAndSettle();

    expect(picked, [const Locale('de')]);
  });
}
