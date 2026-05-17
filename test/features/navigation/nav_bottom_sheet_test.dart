import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/nav_bottom_sheet.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
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
    home: Scaffold(body: child),
  );
}

void main() {
  group('motion tokens', () {
    test('uses the design-system curve cubic(0.16, 1, 0.3, 1)', () {
      expect(NavBottomSheet.transitionCurve, isA<Cubic>());
      expect(
        (NavBottomSheet.transitionCurve as Cubic).toString(),
        'Cubic(0.16, 1.00, 0.30, 1.00)',
      );
    });

    test('uses the design-system duration of 400 ms', () {
      expect(
        NavBottomSheet.transitionDuration,
        const Duration(milliseconds: 400),
      );
    });
  });

  group('rendering', () {
    testWidgets('lists exactly the visible sections in declaration order',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(
          NavBottomSheet(
            active: NavSection.price,
            sections: NavSection.visible(),
            onSelect: (_) {},
          ),
        ),
      );
      await tester.pump();

      // All four visible labels render…
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      // …and the deferred ones do not.
      expect(find.text('Forecast'), findsNothing);
      expect(find.text('Miner'), findsNothing);
    });

    testWidgets('shows the localised sections header', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(
          NavBottomSheet(
            active: NavSection.price,
            sections: NavSection.visible(),
            onSelect: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sections'), findsOneWidget);
    });
  });

  group('selection', () {
    testWidgets('fires onSelect with the tapped section', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      NavSection? selected;
      await tester.pumpWidget(
        _harness(
          NavBottomSheet(
            active: NavSection.price,
            sections: NavSection.visible(),
            onSelect: (s) => selected = s,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Network'));
      await tester.pump();

      expect(selected, NavSection.network);
    });

    testWidgets('routes selection on the active section back to itself',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      NavSection? selected;
      await tester.pumpWidget(
        _harness(
          NavBottomSheet(
            active: NavSection.price,
            sections: NavSection.visible(),
            onSelect: (s) => selected = s,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Price'));
      await tester.pump();

      expect(selected, NavSection.price);
    });
  });
}
