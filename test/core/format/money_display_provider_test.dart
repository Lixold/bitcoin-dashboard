import 'dart:async';

import 'package:bitcoin_dashboard/core/format/money_display_provider.dart';
import 'package:bitcoin_dashboard/core/format/money_format.dart';
import 'package:bitcoin_dashboard/core/fx/fx_provider.dart';
import 'package:bitcoin_dashboard/core/fx/fx_rates.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

FxRates _rates() => FxRates.fromJson(const <String, dynamic>{
  '_meta': <String, dynamic>{
    'fetchedAt': '2026-09-10T16:15:46+00:00',
    'currencies': <String>['EUR', 'USD'],
  },
  'USD': <String, dynamic>{'EUR': 0.86088154, 'USD': 1},
});

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Sets the stored preference the way the app does, through the controller
/// that owns the box, rather than by writing its private key by hand.
Future<void> _choose(ProviderContainer container, String code) =>
    container.read(settingsControllerProvider.notifier).setFiatCurrency(code);

void main() {
  setUpTestHive(inMemory: true, clearBetweenTests: true);

  test('the default setting needs no rate at all', () async {
    // USD on first launch. Nothing is fetched into the answer and the
    // state says why: there is nothing to convert.
    final container = _container([
      fxRatesProvider.overrideWith((ref) => Completer<FxRates>().future),
    ]);

    expect(
      container.read(moneyDisplayProvider).state,
      MoneyDisplayState.source,
    );
    expect(container.read(moneyDisplayProvider).currency, 'USD');
  });

  test('the setting and the published rate meet here', () async {
    final container = _container([
      fxRatesProvider.overrideWith((ref) async => _rates()),
    ]);
    await _choose(container, 'EUR');
    await container.read(fxRatesProvider.future);

    final display = container.read(moneyDisplayProvider);

    expect(display.state, MoneyDisplayState.converted);
    expect(display.currency, 'EUR');
    expect(display.displayedAmount(100, from: 'usd'), closeTo(86.088154, 1e-9));
  });

  test('a rate still in flight is pending, not unavailable', () async {
    final container = _container([
      fxRatesProvider.overrideWith((ref) => Completer<FxRates>().future),
    ]);
    await _choose(container, 'EUR');

    expect(container.read(moneyDisplayProvider).isPending, isTrue);
  });

  test('a rate that failed leaves the setting alone', () async {
    // The one thing this state must not do is take a preference away. The
    // amounts fall back to dollars and say so; the setting stays EUR and
    // takes effect again the moment a rate arrives.
    final container = _container([
      fxRatesProvider.overrideWith((ref) async => throw Exception('offline')),
    ]);
    await _choose(container, 'EUR');
    await expectLater(
      container.read(fxRatesProvider.future),
      throwsA(isA<Exception>()),
    );

    expect(
      container.read(moneyDisplayProvider).state,
      MoneyDisplayState.unavailable,
    );
    expect(container.read(moneyDisplayProvider).currency, 'USD');
    expect(
      container.read(settingsControllerProvider).fiatCurrency,
      'EUR',
      reason: 'the reader still wants euros — the app just cannot say so yet',
    );
  });

  test('changing the setting changes the unit without a new request', () async {
    var builds = 0;
    final container = _container([
      fxRatesProvider.overrideWith((ref) async {
        builds++;
        return _rates();
      }),
    ]);
    container.listen(moneyDisplayProvider, (_, _) {});
    await container.read(fxRatesProvider.future);

    expect(container.read(moneyDisplayProvider).currency, 'USD');

    await _choose(container, 'EUR');

    expect(container.read(moneyDisplayProvider).currency, 'EUR');
    expect(
      builds,
      1,
      reason: 'conversion is client-side — the matrix is fetched once',
    );
  });
}
