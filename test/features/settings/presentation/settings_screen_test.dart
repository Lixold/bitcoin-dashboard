import 'dart:io';
import 'dart:typed_data';

import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/core/router/app_router.dart';
import 'package:bitcoin_dashboard/core/theme/app_typography.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The app, opened straight on `/settings`.
///
/// The screen under test is reached through the real router rather than
/// through a bare `home:` — the sheet, the theme and the locale all run
/// through the app's own wiring, which is what "takes effect immediately"
/// means.
Widget _app() {
  return ProviderScope(
    overrides: [
      appRouterProvider.overrideWith((ref) {
        final router = createAppRouter(initialLocation: settingsLocation);
        ref.onDispose(router.dispose);
        return router;
      }),
    ],
    child: const BitcoinDashboardApp(),
  );
}

/// The screen is taller than the 800x600 default view.
void _useTallView(WidgetTester tester, {Size size = const Size(900, 1600)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SettingsScreen)));

/// Taps something that writes a preference and settles the frame it
/// causes.
///
/// The controller writes to the box before it updates its state, so the
/// write has to have completed by the time the assertion runs — see the
/// in-memory box in `setUpAll`.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_settings_');
    Hive.init(tempDir.path);
    // `bytes:` puts the box on Hive's in-memory backend. A file-backed box
    // completes its writes on the real event loop, which a widget test's
    // fake async zone never reaches — the theme would still be light three
    // frames after the tap. This keeps the settings path deterministic and
    // off the disk.
    await Hive.openBox<String>(SettingsController.boxName, bytes: Uint8List(0));
  });

  tearDown(() async {
    await Hive.box<String>(SettingsController.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('renders the three groups and nothing to wait for', (
    tester,
  ) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('LANGUAGE AND REGION'), findsOneWidget);
    expect(find.text('ABOUT THE APP'), findsOneWidget);

    // Preferences come out of the local box before the first frame: there
    // is no loading state to render and no request that can fail.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Every row states a real value.
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('MIT'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets('the screen title is set from the design, not inherited', (
    tester,
  ) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Settings'));

    // `titleLarge` carries displaySmall (18) since #72, so an inherited
    // title would be four points too small and in the wrong role.
    expect(title.style?.fontSize, AppTypography.displayMedium.fontSize);
    expect(title.style?.fontWeight, AppTypography.displayMedium.fontWeight);
  });

  testWidgets('switching the theme takes effect immediately', (tester) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_theme(tester).brightness, Brightness.light);

    await _tapAndSettle(tester, find.text('Dark'));

    expect(_theme(tester).brightness, Brightness.dark);
  });

  testWidgets('switching the language takes effect immediately', (
    tester,
  ) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    // The picker, not a segmented control: two languages today, fifteen
    // planned.
    expect(find.text('Choose a language'), findsOneWidget);

    await _tapAndSettle(tester, find.text('German'));

    expect(find.text('ERSCHEINUNGSBILD'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('the number format follows the language', (tester) async {
    _useTallView(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Number format'), findsOneWidget);
    expect(find.textContaining('1,234.56'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, find.text('German'));

    expect(find.textContaining('1.234,56'), findsOneWidget);
  });

  testWidgets('a row stacks its control under the text on a phone', (
    tester,
  ) async {
    _useTallView(tester, size: const Size(390, 1600));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final label = find.text('Theme');
    final control = find.byType(SegmentedButton<ThemeMode>);

    expect(
      tester.getTopLeft(control).dy,
      greaterThan(tester.getBottomLeft(label).dy),
      reason: 'the three options and the label do not fit on one phone line',
    );

    // Wide enough, and the control returns to the right of the text.
    _useTallView(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(control).dx,
      greaterThan(tester.getTopRight(label).dx),
    );
  });
}
