import 'dart:io';
import 'dart:typed_data';

import 'package:bitcoin_dashboard/features/settings/data/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Gives the test file its own Hive instance on a temporary directory and
/// opens [boxes] on it.
///
/// Call it once at the top of `main()`: it registers the `setUpAll` that
/// opens the boxes and the `tearDownAll` that closes them and removes the
/// directory. Anything reading settings — which is every widget test that
/// pumps a screen — needs this, because [SettingsController] reads its box
/// during the first build.
///
/// [inMemory] puts the boxes on Hive's in-memory backend. A file-backed box
/// completes its writes on the real event loop, which a widget test's fake
/// async zone never reaches, so a test that *writes* a preference and then
/// asserts on the effect needs this or it has to wrap the write in
/// `tester.runAsync`. A test that only reads does not care.
///
/// [clearBetweenTests] empties the boxes after each test. Settings are
/// persisted, so a test that changes one would otherwise leak into the next.
void setUpTestHive({
  List<String> boxes = const [SettingsController.boxName],
  bool inMemory = false,
  bool clearBetweenTests = false,
}) {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('bd_test_');
    Hive.init(tempDir.path);
    for (final box in boxes) {
      await Hive.openBox<String>(box, bytes: inMemory ? Uint8List(0) : null);
    }
  });

  if (clearBetweenTests) {
    tearDown(() async {
      for (final box in boxes) {
        await Hive.box<String>(box).clear();
      }
    });
  }

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });
}
