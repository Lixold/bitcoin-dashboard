import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/features/navigation/presentation/dynamic_nav_pill.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_hive_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(SettingsController.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('app boots and shows the price screen with the floating pill',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Replace the live polling stream with one that never emits and
          // never schedules a Timer — keeps the smoke test deterministic
          // and offline-safe.
          priceLiveProvider.overrideWith((ref) {
            final controller = StreamController<dynamic>();
            ref.onDispose(controller.close);
            return controller.stream.cast();
          }),
        ],
        child: const BitcoinDashboardApp(),
      ),
    );
    await tester.pump(); // first frame

    expect(find.byType(DynamicNavPill), findsOneWidget);
    // App title appears in the screen header.
    expect(find.text('Bitcoin Dashboard'), findsWidgets);
  });
}
