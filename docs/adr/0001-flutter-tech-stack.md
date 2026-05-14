# ADR-0001 — Flutter as the cross-platform tech stack

- **Date:** 2026-05-06
- **Status:** Accepted
- **Decider:** Daniel Nagel

## Context

Bitcoin Dashboard ships as a native application on macOS, Windows, iOS,
and Android (Linux as a bonus target). All platforms are served from a
single codebase. The product is free of charge, so the framework must be
free of licence cost. There is no backend the app needs to talk to other
than public APIs; data visualisation (interactive charts) is a central
feature.

**Core requirements**

- Single codebase for macOS, Windows, iOS, Android (+ optional Linux)
- First-class support for interactive charts
- No licence cost
- Active community, long-term support
- Production-ready on every target platform

## Options considered

### Option A — Flutter (Dart) — chosen

Google's cross-platform framework with its own rendering engine
(Impeller).

- All five target platforms production-ready
- Flutter 3.41 / Dart 3.11 (Feb 2026) — current and stable
- Impeller engine: consistent 60/120 FPS, no shader jank
- fl_chart: solid free chart library for fintech use cases
- Largest cross-platform community (~46 % share)
- BSD-licensed (fully free of charge)
- Dart is quick to pick up for any developer with C-family or TypeScript
  background

Trade-offs: bundle size of ~15–20 MB because the rendering engine ships
with the app; Dart is less common than TypeScript/JavaScript.

### Option B — Tauri v2 (Rust + WebView)

Desktop-first, mobile stable since October 2024.

- Very small bundle (~2–10 MB), low RAM footprint
- All web chart libraries available

Trade-offs: mobile parity is still incomplete (not every plugin is
available on iOS/Android); native features require Rust expertise;
smaller community than Flutter.

### Option C — React Native + Expo (rejected)

JavaScript/TypeScript, mobile-first. Desktop (macOS, Windows) is only
reachable via Electron or Tauri, which would force a multi-framework
setup. Rejected for missing native desktop coverage.

## Decision

**Flutter** is the chosen tech stack.

It is the only framework that covers all five target platforms in a
production-ready state without licence costs. The fl_chart library
covers the chart requirements fully, and the large community secures
long-term support.

## Conventions

| Area | Choice |
|---|---|
| Language | Dart 3.11 |
| State management | Riverpod (classical API, no codegen in MVP) — see [ADR-0004](0004-state-management-riverpod.md) |
| Charts | fl_chart (MIT) |
| HTTP | dio |
| Local cache & settings | Hive (`hive` + `hive_flutter`) — one box for settings, one per cached file |
| Static analysis | `flutter_lints`, `riverpod_lint`, `analysis_options.yaml` with `strict-casts` + `strict-inference` + `strict-raw-types` |
| Internationalisation | `flutter_localizations` + `intl` + ARB files via `gen-l10n` (configured in `l10n.yaml`) |
| Minimum versions | macOS 13, Windows 10, iOS 16, Android 9 (API 28) |
| Web | Internal development target only, not a release target |

## Consequences

**Positive**

- A single codebase covers all platforms
- No platform-specific UI implementations needed
- Strong ecosystem for charts, local data, HTTP, state management

**Negative / risks**

- Bundle size around 15–20 MB (acceptable for a dashboard application)
- macOS / Windows App Store submissions require platform-specific build
  configuration

## Open questions

- [ ] App signing: set up an Apple Developer account (99 USD/year)
