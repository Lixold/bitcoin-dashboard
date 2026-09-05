import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/segmented_control.dart';
import 'package:bitcoin_dashboard/features/settings/presentation/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One row of a fixed width, carrying a three-option control.
///
/// The width stays the same across the two label cases on purpose: what
/// changes between them is the copy, and the copy is what has to move the
/// layout.
Widget _harness({required String label, double width = 420}) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: SettingsRow(
          label: label,
          trailing: AppSegmentedControl<int>(
            selected: 0,
            onSelected: (_) {},
            segments: const [
              AppSegment(value: 0, label: 'System'),
              AppSegment(value: 1, label: 'Light'),
              AppSegment(value: 2, label: 'Dark'),
            ],
          ),
        ),
      ),
    ),
  ),
);

Finder get _control => find.byType(SegmentedButton<int>);

void main() {
  group('a row lays itself out from its copy, not from a width', () {
    testWidgets('a short label keeps the control beside the text', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(label: 'Theme'));

      final label = find.text('Theme');

      expect(
        tester.getTopLeft(_control).dx,
        greaterThan(tester.getTopRight(label).dx),
        reason: 'the control belongs to the right of the label',
      );
      expect(
        tester.getCenter(_control).dy,
        moreOrLessEquals(tester.getCenter(label).dy, epsilon: 1),
        reason: 'both sit on one line',
      );
    });

    testWidgets('a longer translation of the same label stacks it', (
      tester,
    ) async {
      // Same row, same control, same width — only the word is longer.
      // This is the case a fixed threshold gets wrong: it would call this
      // width wide enough and leave the German label squeezed.
      await tester.pumpWidget(_harness(label: 'Erscheinungsbild'));

      final label = find.text('Erscheinungsbild');

      expect(
        tester.getTopLeft(_control).dy,
        greaterThan(tester.getBottomLeft(label).dy),
        reason:
            'the control moves under the text that no longer leaves it room',
      );
      expect(
        tester.getTopLeft(_control).dx,
        moreOrLessEquals(tester.getTopLeft(label).dx, epsilon: 1),
        reason: 'stacked, both start at the same left edge',
      );
    });

    testWidgets('the same long label fits again in a wider row', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(label: 'Erscheinungsbild', width: 700));

      final label = find.text('Erscheinungsbild');

      expect(
        tester.getTopLeft(_control).dx,
        greaterThan(tester.getTopRight(label).dx),
      );
    });
  });

  testWidgets('a row without a control has nothing to stack', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: SettingsRow(label: 'Version', value: '0.1.0'),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.text('0.1.0')).dy,
      moreOrLessEquals(tester.getCenter(find.text('Version')).dy, epsilon: 1),
    );
  });

  testWidgets('a section keeps its rows on one card, divided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SettingsSection(
            title: 'About the app',
            rows: [
              SettingsRow(label: 'Version', value: '0.1.0'),
              SettingsRow(label: 'Licence', value: 'MIT'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ABOUT THE APP'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });
}
