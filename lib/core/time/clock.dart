import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's reading of the wall clock.
typedef Clock = DateTime Function();

/// Where the app asks what time it is.
///
/// Three places need a *now* they can be held to. Two judge an age: the
/// network provider decides whether its cached copy is inside the TTL, and
/// the network statement decides whether what it renders is stale. The
/// third records one: `BinanceApi` stamps a tick with the moment its fetch
/// returned, because the response carries no timestamp of its own.
///
/// All three are the product of a value and a moment, and a test that
/// cannot fix the moment has to build its input relative to the real
/// clock — which makes the assertion drift with the day it runs on and
/// rules out reading a payload from a captured fixture at all.
///
/// So the clock is a provider rather than a direct call, and a test
/// freezes it (`pumpApp(now: …)` in `test/support/`). Production wires it
/// to the real clock and nothing else overrides it.
///
/// **This is the seam for moments the app reasons about, not a general
/// time abstraction.** Formatting an instant for display and animation
/// timing read the clock for other reasons and are deliberately not routed
/// through here.
final clockProvider = Provider<Clock>((ref) => DateTime.now);
