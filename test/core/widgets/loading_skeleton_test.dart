import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 200 px of *loose* width. A bare `SizedBox` would force its width onto
/// the child, and the first test could then not tell whether the skeleton
/// took the width it was given or the one it was handed.
Widget _harness(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 200,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('takes the width it is given', (tester) async {
    await tester.pumpWidget(
      _harness(const LoadingSkeleton(width: 120, height: 34)),
    );

    expect(tester.getSize(find.byType(LoadingSkeleton)), const Size(120, 34));
  });

  testWidgets('fills the parent when no width is given', (tester) async {
    await tester.pumpWidget(_harness(const LoadingSkeleton(height: 10)));

    expect(tester.getSize(find.byType(LoadingSkeleton)), const Size(200, 10));
  });

  testWidgets('holds space without claiming a value', (tester) async {
    // The distinction CLAUDE.md §5 draws: a blank block is not a
    // placeholder figure. Nothing here can be read as data.
    await tester.pumpWidget(_harness(const LoadingSkeleton(height: 34)));

    expect(find.byType(Text), findsNothing);
  });
}
