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
}) => AppSegmentedControl<ThemeMode>(
  selected: selected,
  onSelected: onSelected,
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
      AppSegmentedControl.optionHeight,
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
        AppSegmentedControl.optionHeight,
        reason: 'option $label',
      );
    }
  });
}
