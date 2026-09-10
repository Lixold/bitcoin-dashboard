import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

AppSegmentedControl<ThemeMode> _control({
  required ThemeMode selected,
  required ValueChanged<ThemeMode> onSelected,
  SegmentedDensity density = SegmentedDensity.comfortable,
  bool block = false,
}) => AppSegmentedControl<ThemeMode>(
  selected: selected,
  onSelected: onSelected,
  density: density,
  block: block,
  segments: const [
    AppSegment(value: ThemeMode.system, label: 'System'),
    AppSegment(value: ThemeMode.light, label: 'Light'),
    AppSegment(value: ThemeMode.dark, label: 'Dark'),
  ],
);

void main() {
  testWidgets('renders one option per segment', (tester) async {
    await tester.pumpWidget(
      _harness(_control(selected: ThemeMode.system, onSelected: (_) {})),
    );

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('reports the option that was tapped', (tester) async {
    final picked = <ThemeMode>[];

    await tester.pumpWidget(
      _harness(_control(selected: ThemeMode.system, onSelected: picked.add)),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(picked, [ThemeMode.dark]);
  });

  testWidgets('marks the selection structurally, not decoratively', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_control(selected: ThemeMode.light, onSelected: (_) {})),
    );

    final button = tester.widget<SegmentedButton<ThemeMode>>(
      find.byType(SegmentedButton<ThemeMode>),
    );
    final style = button.style!;

    expect(
      style.foregroundColor!.resolve(<WidgetState>{WidgetState.selected}),
      AppColors.primary,
    );
    expect(
      style.foregroundColor!.resolve(<WidgetState>{}),
      AppColors.darkOnSurfaceVariant,
    );
    expect(
      style.backgroundColor!.resolve(<WidgetState>{WidgetState.selected}),
      AppColors.darkSurfaceVariant,
    );
    expect(style.backgroundColor!.resolve(<WidgetState>{}), Colors.transparent);
  });

  testWidgets('every option is a full touch target', (tester) async {
    await tester.pumpWidget(
      _harness(_control(selected: ThemeMode.system, onSelected: (_) {})),
    );

    // The whole control and every option inside it: Material's default
    // segment is 40 px, which is under the touch minimum.
    expect(
      tester.getSize(find.byType(SegmentedButton<ThemeMode>)).height,
      SegmentedDensity.comfortable.optionHeight,
    );
    for (final label in <String>['System', 'Light', 'Dark']) {
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(SizedBox),
                  )
                  .first,
            )
            .height,
        SegmentedDensity.comfortable.optionHeight,
        reason: 'option $label',
      );
    }
  });

  testWidgets('the compact density is shorter than the comfortable one', (
    tester,
  ) async {
    // The range strip sits inside a statement rather than being one, and
    // a second 44 px bar above the verdict would read as a heading. 34 px
    // is still over the 24 px minimum target size.
    await tester.pumpWidget(
      _harness(
        _control(
          selected: ThemeMode.system,
          onSelected: (_) {},
          density: SegmentedDensity.compact,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SegmentedButton<ThemeMode>)).height,
      SegmentedDensity.compact.optionHeight,
    );
    expect(
      SegmentedDensity.compact.optionHeight,
      lessThan(SegmentedDensity.comfortable.optionHeight),
    );
  });

  testWidgets('a block control fills the row in equal parts', (tester) async {
    await tester.pumpWidget(
      _harness(
        SizedBox(
          width: 300,
          child: _control(
            selected: ThemeMode.system,
            onSelected: (_) {},
            density: SegmentedDensity.compact,
            block: true,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SegmentedButton<ThemeMode>)).width, 300);
    final widths = <double>[
      for (final label in <String>['System', 'Light', 'Dark'])
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(SizedBox),
                  )
                  .first,
            )
            .width,
    ];
    expect(widths.toSet(), hasLength(1), reason: 'every option the same width');
  });

  testWidgets('without block it stays at its intrinsic width', (tester) async {
    // Wider than the three labels need. Inside a box narrow enough to
    // squeeze them, both forms fill it — the difference only shows where
    // there is room to leave.
    await tester.pumpWidget(
      _harness(
        SizedBox(
          width: 900,
          child: _control(selected: ThemeMode.system, onSelected: (_) {}),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SegmentedButton<ThemeMode>)).width,
      lessThan(900),
    );
  });
}
