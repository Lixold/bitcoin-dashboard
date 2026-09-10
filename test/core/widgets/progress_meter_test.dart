import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/progress_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A component test, so it builds the tree by hand rather than reaching
/// for the screen harness — CLAUDE.md §7.
Widget _harness(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 200, child: child)),
  ),
);

/// The width the fill actually occupies, which is what the reader sees —
/// asserting on the `widthFactor` would only restate the argument.
Size _fillSize(WidgetTester tester) {
  final fill = tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    ),
  );
  return fill.size;
}

double _fillWidth(WidgetTester tester) => _fillSize(tester).width;

void main() {
  testWidgets('fills the share of the track the figure is', (tester) async {
    await tester.pumpWidget(
      _harness(const ProgressMeter(percent: 25, fill: Colors.amber)),
    );

    expect(_fillWidth(tester), 50);
  });

  testWidgets('fills the track it sits in from top to bottom', (tester) async {
    // The regression this guards: the fill is a childless `DecoratedBox`,
    // and the alignment on the track loosens its constraints, so without
    // a height factor it takes the smallest height on offer — zero — and
    // every bar in the app draws an empty track.
    await tester.pumpWidget(
      _harness(const ProgressMeter(percent: 25, fill: Colors.amber)),
    );

    expect(_fillSize(tester).height, 10);
  });

  testWidgets('measures against the track, not against another bar', (
    tester,
  ) async {
    // Two meters in one column: the smaller one must not grow to fill the
    // space just because it is the largest thing beside it.
    await tester.pumpWidget(
      _harness(
        const Column(
          children: [
            ProgressMeter(percent: 10, fill: Colors.amber),
            ProgressMeter(percent: 20, fill: Colors.amber),
          ],
        ),
      ),
    );

    final widths = tester
        .renderObjectList<RenderBox>(
          find.descendant(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.size.width)
        .toList();

    expect(widths, [20, 40]);
  });

  testWidgets('clamps a figure that overshoots its reference', (tester) async {
    // A producer's rounding can put a share a hair over 100. The bar is
    // not the place to raise that.
    await tester.pumpWidget(
      _harness(const ProgressMeter(percent: 100.4, fill: Colors.amber)),
    );

    expect(_fillWidth(tester), 200);
  });

  testWidgets('draws no fill at zero', (tester) async {
    await tester.pumpWidget(
      _harness(const ProgressMeter(percent: 0, fill: Colors.amber)),
    );

    expect(_fillWidth(tester), 0);
  });

  testWidgets('shows the corner labels uppercased when given', (tester) async {
    await tester.pumpWidget(
      _harness(
        const ProgressMeter(
          percent: 62.3,
          fill: Colors.amber,
          topLeft: 'At 62.3 % of the high',
          topRight: '100 % — all-time high',
        ),
      ),
    );

    expect(find.text('AT 62.3 % OF THE HIGH'), findsOneWidget);
    expect(find.text('100 % — ALL-TIME HIGH'), findsOneWidget);
  });

  testWidgets('is the bare track when no labels are given', (tester) async {
    await tester.pumpWidget(
      _harness(const ProgressMeter(percent: 62.3, fill: Colors.amber)),
    );

    expect(find.byType(Text), findsNothing);
  });
}
