import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/brand_icon.dart';
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

  group('a row that opens something', () {
    /// The section in the tree it really sits in — a [Scaffold] brings a
    /// [Material] of its own, well above the card.
    Widget sectionAlone(List<Widget> rows) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SettingsSection(title: 'About the app', rows: rows),
      ),
    );

    /// The ink layer *inside* [scope].
    ///
    /// Scoped on purpose: the Scaffold above has an ink layer too, and
    /// that is the one a row used to paint into — underneath the card's
    /// own fill, where the pressed state was drawn and never seen.
    RenderObject inkLayerIn(WidgetTester tester, Finder scope) {
      RenderObject? found;
      void visit(RenderObject node) {
        if (found != null) return;
        if (node.runtimeType.toString() == '_RenderInkFeatures') {
          found = node;
          return;
        }
        node.visitChildren(visit);
      }

      visit(tester.renderObject(scope));
      expect(found, isNotNull, reason: 'the card carries no ink layer');
      return found!;
    }

    Finder chevronOf(Finder row) => find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (w) => w is BrandIcon && w.glyph == UiGlyph.chevronDown,
      ),
    );

    testWidgets('points its chevron the way the design points it', (
      tester,
    ) async {
      await tester.pumpWidget(
        sectionAlone([
          SettingsRow(
            label: 'Source code',
            description: 'github.com/x/y',
            onTap: () {},
          ),
        ]),
      );

      // The design system draws one chevron and turns it: both its
      // `SettingsRow` and its `PreferenceLink` render the `chevron-down`
      // glyph at `rotate(-90deg)`. Three quarter turns clockwise is that
      // same quarter turn anticlockwise — the glyph points right.
      final rotation = tester.widget<RotatedBox>(
        find.ancestor(
          of: chevronOf(find.byType(SettingsRow)),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(rotation.quarterTurns % 4, 3);
    });

    testWidgets('shows the chevron even when it states no value', (
      tester,
    ) async {
      await tester.pumpWidget(
        sectionAlone([
          SettingsRow(
            label: 'Source code',
            description: 'github.com/x/y',
            onTap: () {},
          ),
          const SettingsRow(label: 'Data sources', description: 'Binance'),
        ]),
      );

      final rows = find.byType(SettingsRow);
      expect(
        chevronOf(rows.at(0)),
        findsOneWidget,
        reason: 'the About links carry their address in the description',
      );
      expect(
        chevronOf(rows.at(1)),
        findsNothing,
        reason: 'a row that opens nothing must not look as if it does',
      );
    });

    testWidgets('darkens under the finger, on the card and not behind it', (
      tester,
    ) async {
      await tester.pumpWidget(
        sectionAlone([SettingsRow(label: 'Source code', onTap: () {})]),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SettingsRow)),
      );
      addTearDown(() => gesture.up());
      // One frame to start the highlight, one to run its fade-in out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        inkLayerIn(tester, find.byType(SettingsSection)),
        paints
          ..rect(color: AppTheme.dark().colorScheme.surfaceContainerHighest),
      );
    });

    testWidgets('says what it does before it does it', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        sectionAlone([
          SettingsRow(
            label: 'Source code',
            hint: 'Opens in your browser',
            onTap: () {},
          ),
        ]),
      );

      expect(
        tester.getSemantics(find.byType(SettingsRow)),
        isSemantics(
          label: 'Source code',
          // Read after the label, so the row announces that it leaves
          // the app before the user commits to the tap.
          hint: 'Opens in your browser',
          isButton: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });
}
