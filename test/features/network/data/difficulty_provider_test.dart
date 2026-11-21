import 'package:bitcoin_dashboard/features/network/data/difficulty_api.dart';
import 'package:bitcoin_dashboard/features/network/data/difficulty_provider.dart';
import 'package:bitcoin_dashboard/features/network/domain/difficulty_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reading whose only varying field is [remainingBlocks], so a test can
/// tell one fetch from the next.
DifficultySnapshot _reading(int remainingBlocks) => DifficultySnapshot(
  changePercent: 10.2,
  remaining: const Duration(days: 5),
  progressPercent: 57.5,
  remainingBlocks: remainingBlocks,
  averageBlockTime: const Duration(minutes: 9),
  observedAt: DateTime.utc(2026, 11, 21, 12, 29),
);

/// Answers each fetch with the next entry of [answers] — a reading, or an
/// error to throw — and counts how often it was asked.
class _ScriptedApi implements DifficultyApi {
  _ScriptedApi(this.answers);

  final List<Object> answers;
  int calls = 0;

  @override
  Future<DifficultySnapshot> fetch() async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (answer is DifficultySnapshot) return answer;
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
        .watch(difficultyProvider)
        .when(
          loading: () => 'loading',
          error: (_, _) => 'error',
          data: (snapshot) => 'data ${snapshot.remainingBlocks}',
        );
    return Text(text, textDirection: TextDirection.ltr);
  }
}

/// The probe in a scope whose API is [api]. `testWidgets` runs on fake
/// time, so the five-minute timer advances only when the test pumps it.
Future<void> _pump(WidgetTester tester, _ScriptedApi api) => tester.pumpWidget(
  ProviderScope(
    overrides: [difficultyApiProvider.overrideWithValue(api)],
    child: const _Probe(),
  ),
);

void main() {
  test('polls at the 5 min ADR-0002 gives difficulty', () {
    expect(difficultyRefreshInterval, const Duration(minutes: 5));
  });

  testWidgets('loads, then shows the reading', (tester) async {
    final api = _ScriptedApi([_reading(1)]);

    await _pump(tester, api);
    expect(find.text('loading'), findsOneWidget);

    await tester.pump();
    expect(find.text('data 1'), findsOneWidget);
  });

  testWidgets('replaces the reading every five minutes', (tester) async {
    final api = _ScriptedApi([_reading(1), _reading(2), _reading(3)]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('data 1'), findsOneWidget);

    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(api.calls, 1, reason: 'nothing is fetched before the interval');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(api.calls, 2);
    expect(find.text('data 2'), findsOneWidget);

    await tester.pump(difficultyRefreshInterval);
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

    // Riverpod's default would have retried ten times within this window.
    await tester.pump(const Duration(minutes: 1));
    expect(api.calls, 1);
  });

  testWidgets('an error replaces the earlier reading instead of keeping it', (
    tester,
  ) async {
    final api = _ScriptedApi([_reading(1), Exception('unreachable')]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('data 1'), findsOneWidget);

    await tester.pump(difficultyRefreshInterval);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);
    expect(find.text('data 1'), findsNothing);
  });

  testWidgets('recovers by itself on the next scheduled fetch', (tester) async {
    final api = _ScriptedApi([Exception('unreachable'), _reading(2)]);

    await _pump(tester, api);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);

    await tester.pump(difficultyRefreshInterval);
    await tester.pump();
    expect(find.text('data 2'), findsOneWidget);
  });

  testWidgets('stops polling once nothing watches it', (tester) async {
    final api = _ScriptedApi([_reading(1)]);

    await _pump(tester, api);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    await tester.pump(difficultyRefreshInterval * 3);
    expect(api.calls, 1);
  });
}
