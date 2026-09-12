import 'package:bitcoin_dashboard/core/fx/fx_provider.dart';
import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/fx/fx_rates.dart';
import 'package:bitcoin_dashboard/core/widgets/loading_skeleton.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/currency_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/harness.dart';

/// The sheet is opened rather than pumped directly: what it puts on screen
/// is only half of it — the other half is that it closes on a choice and
/// leaves the preference behind.
Future<void> _openSheet(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
}) async {
  await pumpApp(
    tester,
    locale: locale,
    overrides: overrides,
    child: Builder(
      builder: (context) => TextButton(
        onPressed: () => CurrencyPickerSheet.show(context),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Override _ratesAre(FxRates rates) =>
    fxRatesProvider.overrideWith(asyncData(rates));

FxRates _published() => FxRates.fromJson(loadJsonFixture('fx-rates.json'));

/// Reads or writes the stored preference through the controller that owns
/// the box, so the test never has to know the key it is kept under.
Future<void> _choose(String code) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container
      .read(settingsControllerProvider.notifier)
      .setFiatCurrency(code);
}

String _stored() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(settingsControllerProvider).fiatCurrency;
}

void main() {
  setUpTestHive(inMemory: true, clearBetweenTests: true);

  testWidgets('lists what the published rates can reach', (tester) async {
    await _openSheet(tester, overrides: [_ratesAre(_published())]);

    expect(find.text('Choose a currency'), findsOneWidget);
    // All thirty, in the order the producer lists them. The first is on
    // screen; the rest are in the list behind it.
    expect(find.text('AUD'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(
      find.text('BTC'),
      findsNothing,
      reason: 'this picker sets the fiat unit, not the crypto one',
    );
  });

  testWidgets('shows the symbol each code will set amounts in', (tester) async {
    await _openSheet(tester, overrides: [_ratesAre(_published())]);

    // Eight of the thirty share the dollar sign, so the code leads and
    // the symbol follows it rather than standing on its own.
    expect(
      find.descendant(
        of: find.byType(CurrencyPickerSheet),
        matching: find.text('€'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing a currency stores it and closes', (tester) async {
    await _openSheet(tester, overrides: [_ratesAre(_published())]);

    // Thirty rows do not fit in the sheet, and EUR is the eighth: the
    // list has to be brought to it before it can be tapped.
    await tester.ensureVisible(find.text('EUR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();

    expect(find.byType(CurrencyPickerSheet), findsNothing);
    expect(_stored(), 'EUR');
  });

  testWidgets('marks the currency already set', (tester) async {
    await _choose('EUR');

    await _openSheet(tester, overrides: [_ratesAre(_published())]);

    // Marked the way the rest of the system marks a current choice: the
    // label turns `primary`. The glyph set has no check mark.
    expect(
      tester.widget<Text>(find.text('EUR')).style?.color,
      AppColors.primary,
    );
    expect(
      tester.widget<Text>(find.text('AUD')).style?.color,
      AppColors.darkOnSurface,
    );
  });

  testWidgets('holds the space while the list is being fetched', (
    tester,
  ) async {
    await _openSheet(
      tester,
      overrides: [fxRatesProvider.overrideWith(asyncLoading())],
    );

    expect(find.byType(LoadingSkeleton), findsWidgets);
    expect(find.text('AUD'), findsNothing);
  });

  testWidgets('says so when there is no list to show', (tester) async {
    await _openSheet(
      tester,
      overrides: [
        fxRatesProvider.overrideWith(asyncError(Exception('offline'))),
      ],
    );

    expect(
      find.textContaining('currency list could not be loaded'),
      findsOneWidget,
    );
    expect(find.byType(LoadingSkeleton), findsNothing);
  });

  testWidgets('a document quoting nothing reads the same as none', (
    tester,
  ) async {
    // Both leave the reader with nothing to pick, and the remedy for both
    // is the same — so they are not told apart on screen.
    final empty = FxRates.fromJson(const <String, dynamic>{
      '_meta': <String, dynamic>{'fetchedAt': '2026-09-10T16:15:46+00:00'},
    });

    await _openSheet(tester, overrides: [_ratesAre(empty)]);

    expect(
      find.textContaining('currency list could not be loaded'),
      findsOneWidget,
    );
  });

  testWidgets('the unavailable line is localised', (tester) async {
    await _openSheet(
      locale: const Locale('de'),
      tester,
      overrides: [
        fxRatesProvider.overrideWith(asyncError(Exception('offline'))),
      ],
    );

    expect(find.textContaining('Währungsliste'), findsOneWidget);
  });
}
