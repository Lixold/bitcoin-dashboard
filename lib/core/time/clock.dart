import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's reading of the wall clock.
typedef Clock = DateTime Function();

/// Where the app asks what time it is.
///
/// Two things in this app compare a payload's age against *now*: the
/// network provider decides whether its cached copy is inside the TTL, and
/// the network statement decides whether what it renders is stale. Both
/// judgements are the product of a figure and a moment, and a test that
/// cannot fix the moment has to build its input relative to
/// `DateTime.now()` — which makes the assertion drift with the day it runs
/// on and rules out reading the payload from a captured fixture at all.
///
/// So the clock is a provider rather than a direct `DateTime.now()`, and a
/// test freezes it (`pumpApp(now: …)` in `test/support/`). Production wires
/// it to the real clock and nothing else overrides it.
///
/// **This is the seam for age, not a general time abstraction.**
/// Formatting a timestamp, stamping an observation at the point it is
/// received, and animation timing all read the clock for other reasons and
/// are deliberately not routed through here.
final clockProvider = Provider<Clock>((ref) => DateTime.now);
