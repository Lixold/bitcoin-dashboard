import 'package:bitcoin_dashboard/core/router/app_router.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/app_navigation.dart';
import 'package:bitcoin_dashboard/features/network/presentation/network_screen.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_screen.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/harness.dart';

/// Index of the destination the navigation marks as active. The tests below
/// run at a width where the rail is the expression; which expression appears
/// at which width is the navigation's own test.
int? _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

void main() {
  late AppL10n l10n;

  setUpTestHive();
  setUpAll(() async {
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
    // Wide enough for the rail, tall enough that the settings screen does
    // not have to scroll before a finder can reach it.
    useView(tester, TestView.tallTablet);

    final router = createAppRouter(initialLocation: location);
    addTearDown(router.dispose);

    await pumpRouterApp(tester, router: router);
    await tester.pumpAndSettle();
    return router;
  }

  group('deep links', () {
    testWidgets('every reachable section has a route that opens it', (
      tester,
    ) async {
      final router = await pumpAt(tester, NavSection.price.location);

      // Also pins the branch order: the shell reads the section back from
      // the branch index, so a reordered branch list would mark the wrong
      // destination.
      for (final section in NavSection.visible()) {
        router.go(section.location);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, section.location);
        expect(
          _selectedIndex(tester),
          NavSection.visible().indexOf(section),
          reason: 'the navigation should mark ${section.id}',
        );
      }
    });

    testWidgets('/ opens the home section', (tester) async {
      final router = await pumpAt(tester, '/');

      expect(router.state.uri.path, homeLocation);
      expect(find.byType(PriceScreen), findsOneWidget);
    });

    testWidgets('a section without a shipped slice has no route and lands on '
        'the home section', (tester) async {
      // A section with no slice has nothing to show, so it deliberately gets
      // no route (CLAUDE.md §5) — a typed URL must not open surface the
      // navigation refuses to offer. `news` is the interesting one here: it
      // was a destination until this section list stopped counting it, so
      // the link exists in the wild.
      for (final section in NavSection.values.where(
        (section) => !section.hasShippedSlice,
      )) {
        final router = await pumpAt(tester, section.location);

        expect(
          router.state.uri.path,
          homeLocation,
          reason: '${section.id} has no slice and must not open',
        );
        expect(find.byType(PriceScreen), findsOneWidget);
        expect(
          find.text(section.label(l10n).toUpperCase()),
          findsNothing,
          reason: '${section.id} must not be offered as a destination',
        );
      }
    });
  });

  group('the section list', () {
    // `createAppRouter` takes the list it builds branches from and hands
    // that same list to the shell, so these tests can watch a section
    // appear and disappear without waiting for its slice to ship — and
    // without a second list that could quietly disagree with the first.
    Future<GoRouter> pumpWith(
      WidgetTester tester,
      List<NavSection> sections, {
      String? at,
    }) async {
      useView(tester, TestView.tallTablet);

      final router = createAppRouter(sections: sections, initialLocation: at);
      addTearDown(router.dispose);

      await pumpRouterApp(tester, router: router);
      await tester.pumpAndSettle();
      return router;
    }

    List<NavigationRailDestination> destinations(WidgetTester tester) =>
        tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations;

    testWidgets('a section outside it has no destination and no route', (
      tester,
    ) async {
      final router = await pumpWith(tester, const [
        NavSection.price,
        NavSection.market,
      ]);

      expect(destinations(tester), hasLength(2));
      expect(
        find.text(NavSection.network.label(l10n).toUpperCase()),
        findsNothing,
      );

      router.go(NavSection.network.location);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, NavSection.price.location);
      expect(find.byType(NetworkScreen), findsNothing);
    });

    testWidgets('the same section inside it is a destination that opens', (
      tester,
    ) async {
      final router = await pumpWith(tester, const [
        NavSection.price,
        NavSection.market,
        NavSection.network,
      ]);

      expect(destinations(tester), hasLength(3));

      router.go(NavSection.network.location);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, NavSection.network.location);
      expect(find.byType(NetworkScreen), findsOneWidget);
      // The list is one list: position 2 in it is destination 2 and branch 2.
      expect(_selectedIndex(tester), 2);
    });

    testWidgets('the home section follows the list rather than the enum', (
      tester,
    ) async {
      // Everything above keeps Price first, which is also what
      // `NavSection.visible()` says — so nothing there would notice if the
      // router still read the enum behind the parameter's back.
      final router = await pumpWith(tester, const [
        NavSection.market,
        NavSection.network,
      ]);

      expect(router.state.uri.path, NavSection.market.location);

      router.go(NavSection.price.location);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, NavSection.market.location);
      expect(_selectedIndex(tester), 0);
    });
  });

  group('settings', () {
    testWidgets('/settings opens the settings screen outside the shell', (
      tester,
    ) async {
      await pumpAt(tester, settingsLocation);

      expect(find.byType(SettingsScreen), findsOneWidget);
      // No navigation chrome: settings is not a section.
      expect(find.byType(AppNavigation), findsNothing);
    });

    testWidgets('the navigation does not list settings as a section', (
      tester,
    ) async {
      // The header's gear is the way in. The navigation lists sections
      // only — settings is a task, not a destination.
      await pumpAt(tester, homeLocation);

      expect(find.byType(AppNavigation), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppNavigation),
          matching: find.textContaining(
            RegExp(l10n.settingsTitle, caseSensitive: false),
          ),
        ),
        findsNothing,
      );
    });
  });

  group('back gesture', () {
    testWidgets('closes settings and returns to the section it was opened '
        'from', (tester) async {
      // Settings is pushed on top of the section rather than replacing it,
      // so the system back gesture has something to pop before it can
      // leave the app.
      final router = await pumpAt(tester, NavSection.market.location);

      router.push(settingsLocation);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(router.state.uri.path, NavSection.market.location);
    });
  });
}
