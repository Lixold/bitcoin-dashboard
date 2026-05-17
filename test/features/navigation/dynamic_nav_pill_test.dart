import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/navigation/domain/nav_section.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/dynamic_nav_pill.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required NavSection active,
  required VoidCallback onTap,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
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
      body: Center(
        child: DynamicNavPill(active: active, onTap: onTap),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the active section label and its SVG icon',
      (tester) async {
    await tester.pumpWidget(
      _harness(active: NavSection.price, onTap: () {}),
    );
    await tester.pump();

    expect(find.text('Price'), findsOneWidget);
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final svgString = svg.bytesLoader.toString();
    expect(svgString, contains('price.svg'));
  });

  testWidgets('renders the localised label for the German locale',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        active: NavSection.network,
        onTap: () {},
        locale: const Locale('de'),
      ),
    );
    await tester.pump();

    expect(find.text('Netzwerk'), findsOneWidget);
  });

  testWidgets('invokes onTap once when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(active: NavSection.price, onTap: () => taps++),
    );
    await tester.pump();

    await tester.tap(find.byType(DynamicNavPill));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('swaps label and icon when active changes', (tester) async {
    await tester.pumpWidget(
      _harness(active: NavSection.price, onTap: () {}),
    );
    await tester.pump();
    expect(find.text('Price'), findsOneWidget);

    await tester.pumpWidget(
      _harness(active: NavSection.market, onTap: () {}),
    );
    await tester.pump();

    expect(find.text('Price'), findsNothing);
    expect(find.text('Market'), findsOneWidget);
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.bytesLoader.toString(), contains('market.svg'));
  });

  testWidgets('declares an accessible button label on the pill',
      (tester) async {
    await tester.pumpWidget(
      _harness(active: NavSection.price, onTap: () {}),
    );
    await tester.pump();

    final pillSemantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(DynamicNavPill),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(pillSemantics.properties.button, isTrue);
    expect(pillSemantics.properties.label, 'Open navigation menu');
  });
}
