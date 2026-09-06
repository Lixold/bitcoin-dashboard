import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands one URL to whatever the platform uses to open it.
///
/// A function rather than a class, so a test can put its own in the
/// provider and record the address instead of leaving the platform to it.
typedef UrlOpener = void Function(Uri url);

/// The opener every screen resolves — override it in tests, never call
/// [openInBrowser] from a widget directly.
///
/// It lives in `core/` because the About rows are not its only caller:
/// the news slice opens articles the same way, and a second copy of this
/// would be a second place where the launch mode could drift.
final Provider<UrlOpener> urlOpenerProvider = Provider<UrlOpener>(
  (ref) => openInBrowser,
);

/// Opens [url] in the platform's own browser.
///
/// **The app makes no request here.** It passes the address out and the
/// browser decides what to do with it, which is why a link target is not
/// a host under CLAUDE.md §1 and does not belong in ADR-0002 — see
/// SECURITY.md.
///
/// **Nothing is awaited and nothing is checked first.** Whatever the
/// browser finds at the other end — a moved page, no network, a login
/// wall — is the browser's screen to draw, not ours, so there is no
/// result worth reading and no failure state this app could show that
/// the browser does not show better.
///
/// **The synchronous call is the point.** On the web a new tab opens only
/// while the browser still counts the click as a user gesture, and an
/// `await` before this line ends that gesture: the tab is blocked in
/// silence, with no exception and no `false` to notice. Keep this at the
/// tap handler.
void openInBrowser(Uri url) {
  unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
}
