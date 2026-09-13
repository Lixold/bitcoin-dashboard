import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/core/widgets/statement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Statement', () {
    testWidgets('renders its slots in the fixed order', (tester) async {
      await tester.pumpWidget(
        _harness(
          const Statement(
            category: Text('CATEGORY'),
            notice: Text('NOTICE'),
            verdict: Text('VERDICT'),
            figures: Text('FIGURES'),
            insight: Text('INSIGHT'),
            evidence: Text('EVIDENCE'),
          ),
        ),
      );

      // Vertical order is the contract every later slice inherits: a slice
      // that puts its evidence above its verdict is a different component.
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('CATEGORY'), lessThan(top('NOTICE')));
      expect(top('NOTICE'), lessThan(top('VERDICT')));
      expect(top('VERDICT'), lessThan(top('FIGURES')));
      expect(top('FIGURES'), lessThan(top('INSIGHT')));
      expect(top('INSIGHT'), lessThan(top('EVIDENCE')));
    });

    testWidgets('omits the slots a state does not have', (tester) async {
      await tester.pumpWidget(
        _harness(const Statement(category: Text('CATEGORY'))),
      );

      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.byType(Statement), findsOneWidget);
    });
  });

  group('StatementCategory', () {
    testWidgets('shows the live dot only when the data is current', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const StatementCategory(label: 'Subject', isLive: true)),
      );
      expect(find.byType(LiveDot), findsOneWidget);

      await tester.pumpWidget(
        _harness(const StatementCategory(label: 'Subject')),
      );
      expect(
        find.byType(LiveDot),
        findsNothing,
        reason: 'a stale or absent payload must not claim to be live',
      );
    });

    testWidgets('puts the qualifiers on a line of their own', (tester) async {
      // Not appended to the subject: the design gives the stamp its own
      // line, so where it breaks cannot depend on the window width.
      await tester.pumpWidget(
        _harness(
          const StatementCategory(
            label: 'Subject',
            trailing: ['As of yesterday', '4 min ago'],
          ),
        ),
      );

      expect(find.text('SUBJECT'), findsOneWidget);
      expect(find.text('AS OF YESTERDAY · 4 MIN AGO'), findsOneWidget);

      final subject = tester.getTopLeft(find.text('SUBJECT'));
      final stamp = tester.getTopLeft(find.text('AS OF YESTERDAY · 4 MIN AGO'));
      expect(stamp.dy, greaterThan(subject.dy));
      expect(stamp.dx, subject.dx);
    });
  });

  group('StatementVerdict', () {
    testWidgets('carries a badge when the statement has a second thing to '
        'say', (tester) async {
      await tester.pumpWidget(
        _harness(
          const StatementVerdict(
            verdict: 'Uncritical',
            badgeLabel: 'DISTRIBUTION BROAD',
            tone: StatementTone.positive,
          ),
        ),
      );

      expect(find.text('Uncritical'), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);
    });

    testWidgets('omits it when the verdict word already says everything', (
      tester,
    ) async {
      // The sentiment statement's verdict *is* the band's name — a pill
      // beside it would restate the word next to itself. The marker still
      // carries the tone, through its shape.
      await tester.pumpWidget(
        _harness(
          const StatementVerdict(verdict: 'Greed', tone: StatementTone.warning),
        ),
      );

      expect(find.text('Greed'), findsOneWidget);
      expect(find.byType(StatusBadge), findsNothing);
      expect(find.byType(VerdictMarker), findsOneWidget);
    });
  });

  group('VerdictMarker', () {
    testWidgets('draws a different shape per tone, not only a colour', (
      tester,
    ) async {
      // The briefing requires the three levels to stay apart without
      // colour. The painter is what carries that, so the tones must not
      // compare equal to each other.
      const positive = VerdictMarker(tone: StatementTone.positive);
      const warning = VerdictMarker(tone: StatementTone.warning);
      const negative = VerdictMarker(tone: StatementTone.negative);

      for (final marker in [positive, warning, negative]) {
        await tester.pumpWidget(_harness(marker));
        expect(find.byType(CustomPaint), findsWidgets);
      }

      final painters = <CustomPainter>[];
      for (final marker in [positive, warning, negative]) {
        await tester.pumpWidget(_harness(marker));
        final paint = tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(VerdictMarker),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        painters.add(paint.painter!);
      }

      expect(painters[0].shouldRepaint(painters[1]), isTrue);
      expect(painters[1].shouldRepaint(painters[2]), isTrue);
    });
  });

  group('StatementTone', () {
    test('takes the light-scheme signal colours in the light theme', () {
      // The dark-scheme signals do not reach AA on the light surface;
      // reading them through the tone is what keeps a widget from
      // hard-coding the wrong one.
      expect(
        StatementTone.positive.colorFor(Brightness.light),
        AppColors.lightPositive,
      );
      expect(
        StatementTone.warning.colorFor(Brightness.light),
        AppColors.lightWarning,
      );
      expect(
        StatementTone.negative.colorFor(Brightness.light),
        AppColors.lightError,
      );
      expect(
        StatementTone.neutral.colorFor(Brightness.light),
        AppColors.lightNeutral,
      );
    });

    test('takes the dark-scheme signal colours in the dark theme', () {
      expect(
        StatementTone.positive.colorFor(Brightness.dark),
        AppColors.positive,
      );
      expect(StatementTone.warning.colorFor(Brightness.dark), AppColors.amber);
      expect(
        StatementTone.negative.colorFor(Brightness.dark),
        AppColors.negative,
      );
      expect(
        StatementTone.neutral.colorFor(Brightness.dark),
        AppColors.neutral,
      );
    });
  });

  group('InsightPill', () {
    testWidgets('prints the category before the sentence', (tester) async {
      await tester.pumpWidget(
        _harness(
          const InsightPill(
            category: 'Decentralisation',
            text: 'Nobody can decide on their own.',
            tone: StatementTone.positive,
          ),
        ),
      );

      expect(
        find.textContaining('Decentralisation: Nobody can decide'),
        findsOneWidget,
      );
    });
  });

  group('InfoTrigger', () {
    testWidgets('is a 44 px target carrying its question as a label', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _harness(
          InfoTrigger(
            label: 'What is a mining pool?',
            onTap: () => tapped = true,
          ),
        ),
      );

      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(InfoTrigger),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(size.width, InfoTrigger.targetSize);
      expect(size.height, InfoTrigger.targetSize);

      await tester.tap(find.byType(InfoTrigger));
      expect(tapped, isTrue);
    });
  });
}
