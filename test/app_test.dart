import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({required VoidCallback onOpenSettings}) => MaterialApp(
  supportedLocales: AppL10n.supportedLocales,
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: AppPlatformMenus(
    onOpenSettings: onOpenSettings,
    child: const Scaffold(body: Text('app body')),
  ),
);

void main() {
  testWidgets('the four targets without an app menu get no menu bar', (
    tester,
  ) async {
    // The override has to be back to null before the test body ends —
    // the binding checks that no foundation debug variable outlives a
    // test.
    try {
      for (final platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;

        await tester.pumpWidget(_harness(onOpenSettings: () {}));
        await tester.pumpAndSettle();

        expect(
          find.byType(PlatformMenuBar),
          findsNothing,
          reason: 'menu bar on $platform',
        );
        // The widget is transparent where it has nothing to add.
        expect(
          find.text('app body'),
          findsOneWidget,
          reason: 'body on $platform',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('macOS opens settings from the app menu behind cmd-comma', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var opened = 0;

    await tester.pumpWidget(_harness(onOpenSettings: () => opened++));
    await tester.pumpAndSettle();

    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    final appMenu = bar.menus.single as PlatformMenu;
    final settings = appMenu.menus.first;

    expect(settings.label, 'Settings');

    final shortcut = settings.shortcut! as SingleActivator;
    expect(shortcut.trigger, LogicalKeyboardKey.comma);
    expect(shortcut.meta, isTrue);

    settings.onSelected!();
    expect(opened, 1);

    // A declared app menu replaces the default one, so Quit has to be
    // declared with it.
    final rest = appMenu.menus.last as PlatformMenuItemGroup;
    expect(
      rest.members.single,
      isA<PlatformProvidedMenuItem>().having(
        (item) => item.type,
        'type',
        PlatformProvidedMenuItemType.quit,
      ),
    );

    expect(find.text('app body'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
