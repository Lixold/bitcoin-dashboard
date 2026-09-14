import 'dart:async';

import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/core/fx/fx_provider.dart';
import 'package:bitcoin_dashboard/core/fx/fx_rates.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:bitcoin_dashboard/features/market/data/sentiment_provider.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_index.dart';
import 'package:bitcoin_dashboard/features/network/data/network_health_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:bitcoin_dashboard/features/price/data/history_provider.dart';
import 'package:bitcoin_dashboard/features/price/data/market_provider.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/domain/market_snapshot.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_history.dart';
import 'package:bitcoin_dashboard/features/price/domain/price_tick.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is exported from `misc.dart` rather than the main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Riverpod exports `Override` from `misc.dart` rather than from its main
// barrel. Re-exported so a test that names the type in a helper signature
// does not have to know that.
export 'package:flutter_riverpod/misc.dart' show Override;

/// Pumps [child] inside the wiring the app gives every screen: a
/// [ProviderScope] that cannot reach the network, the app theme, the four
/// localisation delegates, and a [Scaffold] to sit in.
///
/// ```dart
/// await pumpApp(
///   tester,
///   child: const NetworkScreen(),
///   overrides: [networkHealthProvider.overrideWith(asyncData(snapshot))],
/// );
/// ```
///
/// [overrides] wins over the offline defaults for the same provider — see
/// [_merge]. [now] freezes [clockProvider], which is what a test needs
/// whenever it asserts on the age of a payload.
Future<void> pumpApp(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  DateTime? now,
}) {
  return tester.pumpWidget(
    _scope(
      overrides: overrides,
      now: now,
      child: _app(
        locale: locale,
        brightness: brightness,
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// [pumpApp] for a screen that is reached through [router] rather than
/// placed directly — navigation, deep links, and anything that asserts on
/// the URL.
Future<void> pumpRouterApp(
  WidgetTester tester, {
  required GoRouter router,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  DateTime? now,
}) {
  return tester.pumpWidget(
    _scope(
      overrides: overrides,
      now: now,
      child: _app(locale: locale, brightness: brightness, router: router),
    ),
  );
}

/// The real [BitcoinDashboardApp], with the same offline defaults.
///
/// For the few tests whose subject *is* the app's own wiring — its router,
/// its theme mode, its state restoration. Locale and theme come from the
/// stored settings here, so this form takes neither.
Future<void> pumpAppRoot(
  WidgetTester tester, {
  List<Override> overrides = const [],
  DateTime? now,
}) {
  return tester.pumpWidget(
    _scope(overrides: overrides, now: now, child: const BitcoinDashboardApp()),
  );
}

// -- Internals --------------------------------------------------------------

const List<LocalizationsDelegate<dynamic>> _delegates = [
  AppL10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _scope({
  required List<Override> overrides,
  required DateTime? now,
  required Widget child,
}) {
  return ProviderScope(
    overrides: _merge([
      ..._offlineDefaults(),
      if (now != null) clockProvider.overrideWithValue(() => now),
    ], overrides),
    child: child,
  );
}

/// One `MaterialApp` configuration for both forms — `home:` and
/// `routerConfig:` are the only difference between them.
Widget _app({
  required Locale locale,
  required Brightness brightness,
  Widget? home,
  GoRouter? router,
}) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();

  if (router != null) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: _delegates,
      routerConfig: router,
    );
  }
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: locale,
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: _delegates,
    home: home,
  );
}

/// The providers that would otherwise open a socket from a widget test.
///
/// §7 asks for tests that are deterministic and offline. That is a
/// property of the harness rather than something each author has to
/// remember: a screen reached by navigating, not by being pumped, is easy
/// to miss, and the test that misses it passes locally and turns CI flaky.
///
/// The stand-ins hold their provider in `AsyncLoading` forever, which is
/// the honest default — a test that wants a different state says so.
List<Override> _offlineDefaults() => [
  priceLiveProvider.overrideWith(_silentPriceStream),
  networkHealthProvider.overrideWith(
    (ref) => Completer<NetworkHealthSnapshot>().future,
  ),
  marketProvider.overrideWith((ref) => Completer<MarketSnapshot>().future),
  sentimentProvider.overrideWith((ref) => Completer<SentimentIndex>().future),
  fxRatesProvider.overrideWith((ref) => Completer<FxRates>().future),
  // The family, so all five ranges are covered by one entry: a test that
  // taps a range the author did not think about must not reach the CDN.
  // `Override.origin` of a family override is the family itself, so
  // [_merge] still lets a test replace it.
  historyProvider.overrideWith(
    (ref, range) => Completer<PriceHistory>().future,
  ),
];

/// A price stream that never emits and never schedules a timer.
Stream<PriceTick> _silentPriceStream(Ref ref) {
  final controller = StreamController<PriceTick>();
  ref.onDispose(controller.close);
  return controller.stream;
}

/// [defaults], minus every provider [overrides] already speaks for,
/// followed by [overrides].
///
/// The two lists cannot simply be concatenated: Riverpod 3 asserts when
/// one container is handed two overrides of the same provider, so a test
/// that supplies its own `networkHealthProvider` would fail before it
/// rendered a frame. `Override.origin` says what each entry overrides —
/// it is `@visibleForTesting`, which is exactly where this file lives.
List<Override> _merge(List<Override> defaults, List<Override> overrides) {
  final claimed = <Override>{for (final override in overrides) override.origin};
  return [
    for (final fallback in defaults)
      if (!claimed.contains(fallback.origin)) fallback,
    ...overrides,
  ];
}
