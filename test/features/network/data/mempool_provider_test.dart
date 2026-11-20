import 'package:bitcoin_dashboard/features/network/data/mempool_api.dart';
import 'package:bitcoin_dashboard/features/network/data/mempool_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/mempool_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reading whose only varying field is [count], so a test can tell
/// one fetch from the next.
MempoolSnapshot _reading(int count) => MempoolSnapshot(
  count: count,
  vsize: 35000000,
  fastestFee: 7,
  hourFee: 5,
  economyFee: 2,
  observedAt: DateTime.utc(2026, 11, 20, 13),
);

/// Answers each fetch with the next entry of [answers] — a reading, or an
/// error to throw — and counts how often it was asked.
class _ScriptedApi implements MempoolApi {
  _ScriptedApi(this.answers);

  final List<Object> answers;
  int calls = 0;

  @override
  Future<MempoolSnapshot> fetch() async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (answer is MempoolSnapshot) return answer;
    throw answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Renders the provider's state as one line of text, the way a screen
/// would read it through `when`.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref
        .watch(mempoolProvider)
        .when(
          loading: () => 'loading',
          error: (_, _) => 'error',
          data: (snapshot) => 'data ${snapshot.count}',
        );
    return Text(text, textDirection: TextDirection.ltr);
  }
}

/// The probe in a scope whose API is [api]. `testWidgets` runs on fake
/// time, so the 60 s timer advances only when the test pumps it.
Future<void> _pump(WidgetTester tester, _ScriptedApi api) => tester.pumpWidget(
  ProviderScope(
    overrides: [mempoolApiProvider.overrideWithValue(api)],
    child: const _Probe(),
  ),
);

void main() {
  testWidgets('loads, then shows the reading', (tester) async {
    final api = _ScriptedApi([_reading(1)]);

    await _pump(tester, api);
    expect(find.text('loading'), findsOneWidget);

    await tester.pump();
    expect(find.text('data 1'), findsOneWidget);
  });

  testWidgets('replaces the reading every 60 s', (tester) async {
    final api = _ScriptedApi([_reading(1), _reading(2), _reading(3)]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('data 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(api.calls, 1, reason: 'nothing is fetched before the minute is up');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(api.calls, 2);
    expect(find.text('data 2'), findsOneWidget);

    await tester.pump(mempoolRefreshInterval);
    await tester.pump();
    expect(find.text('data 3'), findsOneWidget);
  });

  testWidgets('declines retries: one failed fetch is one request', (
    tester,
  ) async {
    final api = _ScriptedApi([Exception('unreachable')]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);

    // Riverpod's default would have retried within this window.
    await tester.pump(const Duration(seconds: 30));
    expect(api.calls, 1);
  });

  testWidgets('an error replaces the earlier reading instead of keeping it', (
    tester,
  ) async {
    final api = _ScriptedApi([_reading(1), Exception('unreachable')]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('data 1'), findsOneWidget);

    await tester.pump(mempoolRefreshInterval);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);
    expect(find.text('data 1'), findsNothing);
  });

  testWidgets('recovers by itself on the next scheduled fetch', (tester) async {
    final api = _ScriptedApi([Exception('unreachable'), _reading(2)]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);

    await tester.pump(mempoolRefreshInterval);
    await tester.pump();
    expect(find.text('data 2'), findsOneWidget);
  });

  testWidgets('stops polling once nothing watches it', (tester) async {
    final api = _ScriptedApi([_reading(1)]);

    await _pump(tester, api);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    await tester.pump(mempoolRefreshInterval * 3);
    expect(api.calls, 1);
  });
}
