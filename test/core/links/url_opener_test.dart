import 'package:bitcoin_dashboard/core/links/url_opener.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The opener is the single place the app hands an address out, so the
/// two things that make it the right kind of handover are pinned here:
/// which mode it asks for, and that the address arrives unchanged.
///
/// The platform channel is mocked rather than the plugin's Dart API —
/// that way the assertions read the arguments the platform side actually
/// receives, not the ones the call site passed one layer above.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/url_launcher',
  );
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<Object?, Object?> argumentsOfTheOnlyCall() {
    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    return calls.single.arguments as Map<Object?, Object?>;
  }

  test('opens the address in the browser, not inside the app', () async {
    openInBrowser(Uri.parse('https://github.com/Lixold/bitcoin-dashboard'));
    await pumpEventQueue();

    final args = argumentsOfTheOnlyCall();

    expect(
      args['url'],
      'https://github.com/Lixold/bitcoin-dashboard',
      reason: 'the address is passed through, not rewritten',
    );
    expect(
      args['useWebView'],
      isFalse,
      reason:
          'an in-app web view would make the app the thing rendering a '
          'third-party page — F08.4 sets the browser as the target',
    );
    expect(args['useSafariVC'], isFalse, reason: 'same, on iOS');
    expect(
      args['universalLinksOnly'],
      isFalse,
      reason:
          'externalApplication: any browser may take it. '
          'externalNonBrowserApplication would refuse when none of the '
          'installed apps claims the link',
    );
  });

  test('asks the platform once, and reads nothing back', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          // The platform says it did not launch. Nothing downstream may
          // depend on that answer: whatever the browser does with the
          // address is the browser's screen, not a state this app owns.
          return false;
        });

    openInBrowser(Uri.parse('https://github.com/Lixold/bitcoin-dashboard'));
    await pumpEventQueue();

    expect(
      calls,
      hasLength(1),
      reason: 'a refused launch is neither retried nor reported',
    );
  });

  test('the provider hands out the real opener unless a test replaces it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(urlOpenerProvider),
      same(openInBrowser),
      reason:
          'an override that stayed behind would leave every link in the '
          'shipped app doing nothing at all',
    );
  });
}
