/// The three states of a `FutureProvider`, as override callbacks.
///
/// Every screen in this app has to show a loading, an error and a data
/// state (CLAUDE.md §5), so every screen's test reaches for the same three
/// stand-ins. Spelling them out per file made each one a few lines of
/// `Completer` and `throw` that said less than their name does:
///
/// ```dart
/// await pumpApp(
///   tester,
///   child: const NetworkScreen(),
///   overrides: [networkPoolsProvider.overrideWith(asyncLoading())],
/// );
/// ```
///
/// The type argument comes from the provider being overridden, so it never
/// has to be written out.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A future that never completes: the loading state, held still for as
/// long as the test wants to look at it.
FutureOr<T> Function(Ref) asyncLoading<T>() =>
    (ref) => Completer<T>().future;

/// A provider that fails with [error]: the error state.
FutureOr<T> Function(Ref) asyncError<T>(Object error) =>
    (ref) async => throw error;

/// A provider that resolves to [value]: the data state.
///
/// Asynchronous on purpose. Returning the value synchronously would let
/// the screen skip its loading frame entirely, so a widget that only
/// renders correctly after a settle would pass here and fail in the app.
FutureOr<T> Function(Ref) asyncData<T>(T value) =>
    (ref) async => value;
