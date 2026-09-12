import 'package:bitcoin_dashboard/features/price/domain/sats_quote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one bitcoin is a hundred million sats', () {
    expect(satsPerUnit(1), satsPerBitcoin);
  });

  test('reads a price back as what one unit buys', () {
    // A bitcoin at $96,442.50 makes a dollar worth some 1,037 sats.
    expect(satsPerUnit(96442.50), closeTo(1036.88, 0.01));
  });

  test('a weak currency buys a fraction of a sat', () {
    // A bitcoin costs about 1.38 billion rupiah. The figure is real and
    // small; what the screen must not do is round it to nothing.
    final sats = satsPerUnit(1382660000)!;

    expect(sats, greaterThan(0));
    expect(sats, lessThan(1));
  });

  test('a price that cannot carry the question is left unanswered', () {
    // The line is dropped rather than shown as a figure nothing stands
    // behind — there is no sensible sats-per-unit at a price of zero.
    expect(satsPerUnit(0), isNull);
    expect(satsPerUnit(-1), isNull);
    expect(satsPerUnit(double.nan), isNull);
    expect(satsPerUnit(double.infinity), isNull);
  });
}
