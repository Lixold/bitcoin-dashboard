# Distribution

How the app reaches its users, per platform. The launch itself is phase 5 of
the [roadmap](../product/roadmap.md).

## Channels

| Platform | Channel | Format | Notes |
|---|---|---|---|
| macOS | Mac App Store | App Store package | Paid Apple Developer Program; notarisation required |
| macOS | GitHub Releases | DMG | Direct download, free |
| Windows | Microsoft Store | MSIX package | Free |
| Windows | GitHub Releases | Installer or portable EXE | Free |
| iOS | App Store | App Store package | Paid Apple Developer Program; TestFlight for beta |
| Android | Google Play | AAB | One-time registration fee |
| Android | GitHub Releases | APK | Sideloading |
| Linux | GitHub Releases | AppImage or Flatpak | No store needed |

Web is a development and preview target and is not distributed
([CLAUDE.md §2](../../CLAUDE.md)).

## Notes

- One Apple Developer Program membership covers macOS and iOS. Google Play is a
  one-time fee.
- A free start is possible: publish first through GitHub Releases, which needs
  no store account.

## Build and release automation

Continuous integration builds the app for all five native targets (Linux,
Windows, macOS, Android, iOS) on every pull request. That is a compile check:
it does not sign, package or publish anything
([`ci.yml`](../../.github/workflows/ci.yml), [CLAUDE.md §6](../../CLAUDE.md)).

There is no release pipeline yet. Versioning, the changelog and the first
signed artifact are open work (issue #50). The tools that were considered are
GitHub Actions, Codemagic and Fastlane; the choice is recorded in an ADR when it
is made. A new action in a workflow also needs a change in the repository's
action allow-list, which a pull request cannot make
([CLAUDE.md §6](../../CLAUDE.md)).

The Cloudflare Workers are not part of the app release; they are deployed by
hand through the `Deploy Cloudflare Workers` workflow
([ADR-0003](../adr/0003-backend-cloudflare-workers-r2.md)).
