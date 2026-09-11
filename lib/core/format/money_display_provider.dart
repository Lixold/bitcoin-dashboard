import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_controller.dart';
import '../fx/fx_provider.dart';
import 'money_format.dart';

/// What every amount in the app is rendered in, this frame.
///
/// One place composes the two halves of that answer: the currency the
/// reader set, which lives in the local settings box, and the rates the
/// CDN published, which live in [fxRatesProvider]. A screen watches this
/// and asks it per amount; no screen reads a rate or a setting to decide
/// how to render money.
///
/// **It reaches from `core/` into `features/settings/`, as the router
/// does.** The currency is not a property of the settings screen — that
/// screen only happens to be where it is changed. It is an app-wide
/// preference that governs every figure on every screen, so the thing that
/// applies it belongs next to the formatter it feeds rather than inside
/// the one feature that edits it.
///
/// The loading flag is passed through rather than collapsed into "no
/// rates": a reader whose rates are still in flight is not a reader whose
/// conversion failed, and [MoneyDisplayState] keeps the two apart.
final moneyDisplayProvider = Provider<MoneyDisplay>((ref) {
  final wanted = ref.watch(
    settingsControllerProvider.select((settings) => settings.fiatCurrency),
  );
  final rates = ref.watch(fxRatesProvider);

  return MoneyDisplay.resolve(
    wanted: wanted,
    rates: rates.value,
    isLoading: rates.isLoading,
  );
});
