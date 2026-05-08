import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/settings/data/settings_controller.dart';

/// Entry point. Initialises Hive (local cache + settings) before the first
/// frame, so settings can be read synchronously by the UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox<dynamic>(SettingsController.boxName);

  runApp(const ProviderScope(child: BitcoinDashboardApp()));
}
