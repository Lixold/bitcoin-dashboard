import 'dart:async';

import 'package:bitcoin_dashboard/core/router/app_router.dart';
import 'package:bitcoin_dashboard/core/theme/app_spacing.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/app_navigation.dart';
import 'package:bitcoin_dashboard/features/network/data/network_pools_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/network_health_snapshot.dart';
import 'package:bitcoin_dashboard/features/network/presentation/network_screen.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/price/presentation/price_screen.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/harness.dart';

/// The three expressions and a width that produces each of them.
const _expressions = <(String, double)>[
  ('bar', 390),
  ('rail', 900),
  ('drawer', 1200),
];

Widget _harness(GoRouter router) {
  return ProviderScope(
    overrides: [
      // Keep the test offline and deterministic: the live stream never emits.
      priceLiveProvider.overrideWith((ref) {
        final controller = StreamController<dynamic>();
        ref.onDispose(controller.close);
        return controller.stream.cast();
      }),
      // Same reason: navigating to Network must not reach the CDN.
      networkPoolsProvider.overrideWith(
        (ref) => Completer<NetworkHealthSnapshot>().future,
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

/// A window [width] logical pixels wide, tall enough that no expression has
/// to scroll its destinations.
void _resize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
}

/// Finds a destination inside the navigation by name, regardless of case:
/// the bar and the rail uppercase their labels the way the design system's
/// `text-transform` does, the drawer does not.
///
/// Scoped to the navigation because a section whose slice has not shipped
/// prints its own name in the body — `find.text('News')` would match the
/// destination and the `ComingSoon` screen behind it.
Finder _destination(String label) => find.descendant(
  of: find.byType(AppNavigation),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data ?? '').toUpperCase() == label.toUpperCase(),
  ),
);

void main() {
  late AppL10n l10n;

  setUpTestHive();
  setUpAll(() async {
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  Future<GoRouter> pumpAt(
    WidgetTester tester, {
    required double width,
    String? initialLocation,
  }) async {
    _resize(tester, width);
    addTearDown(tester.view.reset);

    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();
    return router;
  }

  group('which expression the window gets', () {
    testWidgets('a phone-width window gets the bottom bar', (tester) async {
      await pumpAt(tester, width: 390);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('one dp below the tablet breakpoint is still the bar', (
      tester,
    ) async {
      await pumpAt(tester, width: AppSpacing.tabletBreakpoint - 1);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('the tablet breakpoint itself is the rail', (tester) async {
      await pumpAt(tester, width: AppSpacing.tabletBreakpoint);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('one dp below the wide breakpoint is still the rail', (
      tester,
    ) async {
      await pumpAt(tester, width: AppSpacing.wideLayoutBreakpoint - 1);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationDrawer), findsNothing);
    });

    testWidgets('the wide breakpoint itself is the drawer', (tester) async {
      await pumpAt(tester, width: AppSpacing.wideLayoutBreakpoint);

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the drawer takes the width the design system draws, not the '
        'modal default', (tester) async {
      await pumpAt(tester, width: 1400);

      expect(
        tester.getSize(find.byType(NavigationDrawer)).width,
        AppNavigation.drawerWidth,
      );
    });
  });

  group('destinations', () {
    for (final (name, width) in _expressions) {
      testWidgets('the $name offers the four reachable sections and nothing '
          'else', (tester) async {
        await pumpAt(tester, width: width);

        for (final section in NavSection.visible()) {
          expect(
            _destination(section.label(l10n)),
            findsOneWidget,
            reason: 'the $name should offer ${section.id}',
          );
        }

        // Forecast and Miner have no shipped slice, so they have no route
        // and are not destinations — and no "More" entry stands in for
        // them. Settings is a task, reached from the header gear.
        for (final absent in const ['Forecast', 'Miner', 'More', 'Settings']) {
          expect(
            _destination(absent),
            findsNothing,
            reason: 'the $name must not offer $absent',
          );
        }
      });
    }

    testWidgets('the destination order is the branch order', (tester) async {
      // The shell hands a destination index straight to `goBranch`, so a
      // destination and the branch it selects have to sit at the same
      // position. Walking the bar left to right walks the branches.
      final router = await pumpAt(tester, width: 390);

      for (final section in NavSection.visible()) {
        await tester.tap(_destination(section.label(l10n)));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, section.location);
      }
    });
  });

  group('selecting a section', () {
    for (final (name, width) in _expressions) {
      testWidgets('the $name swaps the body and the URL', (tester) async {
        final router = await pumpAt(tester, width: width);

        expect(find.byType(PriceScreen), findsOneWidget);

        await tester.tap(_destination(NavSection.network.label(l10n)));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, NavSection.network.location);
        expect(find.byType(NetworkScreen), findsOneWidget);
        expect(find.byType(PriceScreen), findsNothing);
      });
    }

    testWidgets('choosing the section already on screen stays on it', (
      tester,
    ) async {
      // `_select` passes `initialLocation: true` in that case, which resets
      // the branch to its section root. No branch has a second route yet,
      // so there is nothing for the reset to undo; what is checked here is
      // that the tap is answered rather than swallowed, and navigates
      // nowhere else.
      final router = await pumpAt(
        tester,
        width: 390,
        initialLocation: NavSection.news.location,
      );

      await tester.tap(_destination(NavSection.news.label(l10n)));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, NavSection.news.location);
    });
  });

  group('dragging the window across a breakpoint', () {
    testWidgets('the expression changes while the section and its state stay', (
      tester,
    ) async {
      final router = await pumpAt(
        tester,
        width: 390,
        initialLocation: NavSection.network.location,
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      final networkElement = tester.element(find.byType(NetworkScreen));

      // 390 -> 900: the bar becomes a rail.
      _resize(tester, 900);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(router.state.uri.path, NavSection.network.location);
      // The shell rebuilds into a different scaffold slot. The branch
      // navigator behind it must survive that, or every section would
      // reload while the window is being dragged.
      expect(tester.element(find.byType(NetworkScreen)), same(networkElement));

      // 900 -> 1200: the rail becomes a drawer.
      _resize(tester, 1200);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(router.state.uri.path, NavSection.network.location);
      expect(tester.element(find.byType(NetworkScreen)), same(networkElement));

      // 1200 -> 390: across both breakpoints in one drag, back to the bar.
      _resize(tester, 390);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDrawer), findsNothing);
      expect(router.state.uri.path, NavSection.network.location);
      expect(tester.element(find.byType(NetworkScreen)), same(networkElement));
    });

    testWidgets(
      'the selected destination follows the section across the drag',
      (tester) async {
        final newsIndex = NavSection.visible().indexOf(NavSection.news);

        await pumpAt(
          tester,
          width: 390,
          initialLocation: NavSection.news.location,
        );

        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          newsIndex,
        );

        _resize(tester, 900);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          newsIndex,
        );

        _resize(tester, 1200);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationDrawer>(find.byType(NavigationDrawer))
              .selectedIndex,
          newsIndex,
        );
      },
    );
  });

  group('accessibility', () {
    for (final (name, width) in _expressions) {
      testWidgets('every $name destination is named, and only the active one '
          'is flagged selected', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAt(
          tester,
          width: width,
          initialLocation: NavSection.network.location,
        );

        for (final section in NavSection.visible()) {
          final label = section.label(l10n);
          // The destination merges its descendants, so the name and the
          // selected flag live in the merged data rather than on the node
          // itself.
          final data = tester
              .getSemantics(_destination(label))
              .getSemanticsData();

          expect(
            data.label.toUpperCase(),
            contains(label.toUpperCase()),
            reason: 'the $name destination $label needs an accessible name',
          );
          expect(
            data.flagsCollection.isSelected.toBoolOrNull() ?? false,
            section == NavSection.network,
            reason: 'the $name should flag Network, and only Network',
          );
        }

        handle.dispose();
      });
    }

    for (final (name, width) in _expressions) {
      testWidgets('the $name follows a section change it did not start', (
        tester,
      ) async {
        // A deep link, a restored session or the browser's back button move
        // the route without anyone touching a destination. The mark has to
        // follow the route, not the tap.
        final handle = tester.ensureSemantics();
        final router = await pumpAt(tester, width: width);

        router.go(NavSection.news.location);
        await tester.pumpAndSettle();

        for (final section in NavSection.visible()) {
          final data = tester
              .getSemantics(_destination(section.label(l10n)))
              .getSemanticsData();

          expect(
            data.flagsCollection.isSelected.toBoolOrNull() ?? false,
            section == NavSection.news,
            reason: 'the $name should have moved its mark to News',
          );
        }

        handle.dispose();
      });
    }

    testWidgets('a rail destination can be reached and activated from the '
        'keyboard', (tester) async {
      final router = await pumpAt(tester, width: 900);

      bool focusIsInRail() {
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) return false;
        var inRail = false;
        context.visitAncestorElements((element) {
          if (element.widget is NavigationRail) {
            inRail = true;
            return false;
          }
          return true;
        });
        return inRail;
      }

      // The header gear is focusable too, so the rail is not necessarily
      // the first stop — walk the traversal order until it is reached.
      for (var step = 0; step < 12 && !focusIsInRail(); step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(
        focusIsInRail(),
        isTrue,
        reason: 'Tab has to reach the navigation rail',
      );

      // Then walk the rail with Tab, activating with Enter, until the
      // section changes. Enter on the destination that is already selected
      // keeps the route — correct, and not what this checks.
      final start = router.state.uri.path;
      for (var step = 0; step < 8; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (router.state.uri.path != start) break;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }

      expect(
        router.state.uri.path,
        isNot(start),
        reason: 'Enter on a rail destination has to switch the section',
      );
      expect(
        NavSection.visible().map((section) => section.location),
        contains(router.state.uri.path),
      );
    });
  });

  testWidgets('a section keeps its state when it is left and re-entered', (
    tester,
  ) async {
    final router = await pumpAt(tester, width: 900);

    final priceFinder = find.byType(PriceScreen, skipOffstage: false);
    final priceElement = tester.element(priceFinder);

    router.go(NavSection.news.location);
    await tester.pumpAndSettle();

    // Each branch has its own Navigator inside an IndexedStack: leaving Price
    // hides it, it does not tear it down. A plain ShellRoute would have
    // replaced the route and dropped everything Price had loaded.
    expect(find.byType(PriceScreen), findsNothing);
    expect(priceFinder, findsOneWidget);

    router.go(NavSection.price.location);
    await tester.pumpAndSettle();

    expect(tester.element(priceFinder), same(priceElement));
  });
}
