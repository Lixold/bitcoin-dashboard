import 'package:bitcoin_dashboard/features/network/domain/node_count.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `fullNodes` object as `cron-network-stats` writes it.
Map<String, dynamic> _fullNodes({
  Object? count = 26579,
  Object? percentChange24h = 0.3,
  Object? trend = 'stable',
}) {
  return <String, dynamic>{
    'count': count,
    'percentChange24h': percentChange24h,
    'trend': trend,
  };
}

void main() {
  group('NodeTrend.parse', () {
    test('reads the four labels the producer writes', () {
      expect(NodeTrend.parse('up'), NodeTrend.up);
      expect(NodeTrend.parse('down'), NodeTrend.down);
      expect(NodeTrend.parse('stable'), NodeTrend.stable);
      expect(NodeTrend.parse('unknown'), NodeTrend.unknown);
    });

    test('degrades a label it does not know instead of throwing', () {
      // The worker may introduce a fifth label. That must not send the
      // screen to an error state.
      expect(NodeTrend.parse('surging'), NodeTrend.unknown);
      expect(NodeTrend.parse(''), NodeTrend.unknown);
      expect(NodeTrend.parse(null), NodeTrend.unknown);
    });
  });

  group('NodeCount.from', () {
    test('reads the live shape of 2026-09-14', () {
      final nodes = NodeCount.from(_fullNodes())!;

      expect(nodes.count, 26579);
      expect(nodes.percentChange24h, 0.3);
      expect(nodes.trend, NodeTrend.stable);
      expect(nodes.hasChange, isTrue);
    });

    test('accepts a whole-percent change serialised as an int', () {
      final nodes = NodeCount.from(
        _fullNodes(percentChange24h: 1, trend: 'up'),
      )!;

      expect(nodes.percentChange24h, 1.0);
      expect(nodes.trend, NodeTrend.up);
    });

    test('a negative change keeps its sign', () {
      final nodes = NodeCount.from(
        _fullNodes(percentChange24h: -6.2, trend: 'down'),
      )!;

      expect(nodes.percentChange24h, -6.2);
      expect(nodes.trend, NodeTrend.down);
    });

    test('count without a comparison: the figure stands, the change does '
        'not', () {
      // The producer's honest failure — the 24 h reference sat more than
      // six hours off target, so it dropped the comparison and kept the
      // count.
      final nodes = NodeCount.from(
        _fullNodes(percentChange24h: null, trend: 'unknown'),
      )!;

      expect(nodes.count, 26579);
      expect(nodes.hasChange, isFalse);
      expect(nodes.trend, NodeTrend.unknown);
    });

    test('an unknown label with a change present still shows the change', () {
      // The label decides nothing: hiding a comparison that arrived
      // because of a word this app does not know would report "missing"
      // next to a figure that exists.
      final nodes = NodeCount.from(
        _fullNodes(percentChange24h: 2.4, trend: 'surging'),
      )!;

      expect(nodes.trend, NodeTrend.unknown);
      expect(nodes.hasChange, isTrue);
      expect(nodes.percentChange24h, 2.4);
    });

    test('no count means no statement, not an exception', () {
      expect(
        NodeCount.from(
          _fullNodes(count: null, percentChange24h: null, trend: 'unknown'),
        ),
        isNull,
      );
    });

    test('an empty object is read as no count', () {
      expect(NodeCount.from(const <String, dynamic>{}), isNull);
    });
  });
}
