import 'package:bitcoin_dashboard/core/theme/app_colors.dart';
import 'package:bitcoin_dashboard/core/theme/app_theme.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_band.dart';
import 'package:bitcoin_dashboard/features/market/domain/sentiment_index.dart';
import 'package:bitcoin_dashboard/features/market/presentation/sentiment_sparkline.dart';
import 'package:bitcoin_dashboard/l10n/generated/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A component, not a screen: the tree is built by hand so the test shows
/// what the widget actually needs — a theme and the localisations for the
/// band names, and nothing else (CLAUDE.md §7).
Widget _harness(SentimentIndex index) => MaterialApp(
  theme: AppTheme.dark(),
  locale: const Locale('en'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: const [
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: SentimentSparkline(index: index)),
);

SentimentIndex _window(List<int> values) {
  final last = DateTime.utc(2026, 9, 13);
  return SentimentIndex(
    points: [
      for (var i = 0; i < values.length; i++)
        SentimentPoint(
          at: last.subtract(Duration(days: values.length - 1 - i)),
          value: values[i],
        ),
    ],
  );
}

Future<LineChartData> _chart(WidgetTester tester, SentimentIndex index) async {
  await tester.pumpWidget(_harness(index));
  await tester.pumpAndSettle();
  return tester.widget<LineChart>(find.byType(LineChart)).data;
}

void main() {
  testWidgets('the axis is the scale, never the window', (tester) async {
    // Five quiet days inside one band. Scaled to their own minimum and
    // maximum this would look like a rally; on the fixed axis it is the
    // flat week it was, and the stripes behind it still mean something.
    final data = await _chart(tester, _window([60, 61, 62, 61, 63]));

    expect(data.minY, sentimentScaleMin);
    expect(data.maxY, sentimentScaleMax);
  });

  testWidgets('draws one stripe per band and one line per boundary', (
    tester,
  ) async {
    final data = await _chart(tester, _window([60, 61, 62]));

    final stripes = data.rangeAnnotations.horizontalRangeAnnotations;
    expect(stripes, hasLength(SentimentBand.values.length));
    expect(stripes.first.y1, sentimentScaleMin);
    expect(stripes.last.y2, sentimentScaleMax);
    expect(
      data.extraLinesData.horizontalLines.map((line) => line.y),
      sentimentScale.boundaries,
    );
    // Under the curve: they are the ground the reading is taken against.
    expect(data.extraLinesData.extraLinesOnTop, isFalse);
  });

  testWidgets('tints the band the current value sits in', (tester) async {
    final data = await _chart(tester, _window([30, 40, 61]));

    final greed = data.rangeAnnotations.horizontalRangeAnnotations[3];
    expect(greed.y1, 55);
    expect(
      greed.color,
      AppColors.warningFor(Brightness.dark).withValues(alpha: 0.14),
    );
  });

  testWidgets('plots one point per day and nothing else', (tester) async {
    final data = await _chart(tester, _window([60, 61, 62, 63]));

    final bar = data.lineBarsData.single;
    expect(bar.spots.map((spot) => spot.y), [60, 61, 62, 63]);
    expect(bar.isCurved, isFalse, reason: 'a spline invents readings');
    expect(bar.dotData.show, isFalse);
    expect(data.lineTouchData.enabled, isFalse);
  });

  testWidgets('names every band beside its stripe', (tester) async {
    await tester.pumpWidget(_harness(_window([60, 61, 62])));
    await tester.pumpAndSettle();

    expect(find.text('EXTREME FEAR'), findsOneWidget);
    expect(find.text('FEAR'), findsOneWidget);
    expect(find.text('NEUTRAL'), findsOneWidget);
    expect(find.text('GREED'), findsOneWidget);
    expect(find.text('EXTREME GREED'), findsOneWidget);
  });
}
