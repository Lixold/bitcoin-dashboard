import 'package:bitcoin_dashboard/core/time/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production reads the real clock', () {
    // The seam exists so a test can fix the moment. If it also fixed it
    // for the app, every age the app reports would be frozen at whatever
    // constant was left in the provider.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = DateTime.now();
    final read = container.read(clockProvider)();
    final after = DateTime.now();

    expect(read.isBefore(before), isFalse);
    expect(read.isAfter(after), isFalse);
  });

  test('an override answers with the moment it was given', () {
    final frozen = DateTime.utc(2026, 9, 8, 12);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => frozen)],
    );
    addTearDown(container.dispose);

    expect(container.read(clockProvider)(), frozen);
    expect(container.read(clockProvider)(), frozen, reason: 'and again');
  });
}
