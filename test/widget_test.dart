import 'dart:async';
import 'dart:io';

import 'package:bitcoin_dashboard/app.dart';
import 'package:bitcoin_dashboard/features/price/data/price_live_provider.dart';
import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Hive.init keeps tests free of path_provider; one tmp dir per run.
    tempDir = Directory.systemTemp.createTempSync('bd_test_hive_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(SettingsController.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('app boots and shows the price overview screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Replace the live polling stream with one that never emits and
        // never schedules a Timer — keeps the smoke test deterministic and
        // offline-safe.
        overrides: [
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

    // Default locale is `en` → AppBar shows the localised app title.
    expect(find.text('Bitcoin Dashboard'), findsWidgets);
    // Loading card while no tick has been emitted yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
