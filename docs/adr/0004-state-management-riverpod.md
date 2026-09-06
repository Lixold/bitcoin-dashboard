# ADR-0004 — Riverpod for state management

- **Date:** 2026-05-06
- **Status:** Accepted (amended 2026-09-06 with the retry policy)
- **Decider:** Daniel Nagel

## Context

Bitcoin Dashboard is a reactive, read-heavy app with several independent
data streams that refresh at different cadences (live price every 60 s,
on-chain every 5 min, news every 15 min, FX rates daily). State
management has to:

- Natively support async data loading (API calls).
- Express scheduled auto-refresh / polling.
- Cleanly represent loading / error / data states.
- Express dependencies between providers (the news provider depends on
  the language picked in settings).
- Be straightforward to test.

## Options considered

### Option A — Riverpod — chosen

- `AsyncNotifier` / `FutureProvider` / `StreamProvider` model async data
  natively.
- `ref.invalidate()` triggers a precise re-fetch (e.g. on language
  change, the news provider re-fetches automatically).
- `ref.watch()` builds dependency graphs at compile time.
- No `BuildContext` in business logic.
- Excellent test ergonomics via `ProviderContainer`.

Trade-offs: medium learning curve; the code-generation variant
(`@riverpod` annotations + `build_runner`) is opt-in and not required
for the MVP.

### Option B — BLoC (rejected)

Overkill for a read-heavy dashboard. Forces a triplet of Event / State
/ BLoC classes per stream — about three times the boilerplate Riverpod
requires.

### Option C — GetX (rejected)

Weak type safety, harder to test, less suited to a long-lived OSS
project.

## Decision

**Riverpod** (`flutter_riverpod`) is the state-management framework.
The MVP uses the classical API (no codegen) to keep the build pipeline
short; the annotation-based variant (`riverpod_generator`,
`riverpod_annotation`) can be adopted later without breaking existing
providers.

## Retry policy: providers state their own, or decline one

**Riverpod 3 retries a failed provider by default, and the default is
wrong for this app.** `ProviderContainer.defaultRetry` makes up to ten
attempts with exponential backoff from 200 ms to a 6.4 s cap — roughly
38 seconds before an error reaches the screen. Until then the state is
`AsyncLoading` *carrying* the error, so a screen that renders
`AsyncValue.when` shows its loading state throughout and its error state
only at the end.

Three consequences, all of them against how this app is built:

- **The error state stops being reachable in practice.** The Definition
  of Done requires loading, empty and error to be implemented *and
  reachable*; a state that appears after 38 seconds of spinner is not.
- **The retries are not free.** Eleven requests for one screen view is a
  lot to spend on a document a cron job rewrites once a day, and it is
  spent hardest exactly when the network is already failing.
- **It hides the resilience we actually built.** The CDN-backed providers
  answer a failed fetch with the cached copy and an age hint. A retry
  storm in front of that delays the fallback without improving it.

The rule that follows, and it applies to every provider, not only the
one that surfaced it:

> A provider states its retry cadence explicitly, or declines retries by
> passing `retry: (_, _) => null`. Inheriting the framework default is
> not a decision this repository accepts by silence.

Where a provider does want retries, they are written out and justified
in the provider, the way `priceLiveProvider` writes its own 60 s → 5 min
backoff — that one is unaffected by the default because it reports
failures into a `StreamController` rather than throwing out of the
provider body, so it never enters the framework's retry path.

`networkPoolsProvider` is the first `FutureProvider` in the app and
declines retries: its fallback is the cache, and a reader who is offline
is better served by yesterday's shares plus an age hint than by half a
minute of spinner.

## Provider hierarchy

```
settingsProvider                  Hive-persisted: language, currency, theme

priceLiveProvider                 Binance direct, 60 s polling
onChainProvider                   mempool.space direct, 5 min polling
fearGreedProvider                 alternative.me direct, 1 h polling

marketProvider                    CDN market.json, 15 min
historyProvider(range)            CDN history-{range}.json
currenciesProvider                CDN fx-rates.json, one-shot + 24 h cache
newsProvider(langs)               CDN news-{lang}.json
                                   ↳ depends on settingsProvider.languages,
                                     re-fetches on change via ref.invalidate
networkPoolsProvider              CDN network-health.json, 60 min cache,
                                   stale past 26 h, no retries
prognosisProvider(model)          CDN prognosis-{model}.json, daily (Phase 4)
```

## Packages

| Package | Purpose |
|---|---|
| `flutter_riverpod` | Core state management |
| `riverpod_lint` | Riverpod-specific lints (compile-time provider-misuse detection) |
| `custom_lint` | Lint runner (pulled in transitively by `riverpod_lint`) |
| `riverpod_generator` *(later)* | `@riverpod` codegen |
| `riverpod_annotation` *(later)* | Annotations for the generator |
| `build_runner` *(later)* | Run the generator |

## Consequences

**Positive**

- Clean separation between UI and business logic
- Polling and cache invalidation live inside their provider
- Language change triggers automatic re-fetching across all dependent
  providers
- High testability via `ProviderContainer`

**Negative / risks**

- Once code generation is adopted, `build_runner` becomes a required
  step after provider changes
- Framework defaults can change behaviour without a code change on our
  side. The retry default was found by a test that hung rather than by
  reading a changelog; a Riverpod major upgrade deserves a pass over the
  defaults it ships
- Initial onboarding cost for contributors new to Riverpod's mental
  model

## Open questions

- [ ] Should the local Hive cache live as its own provider, or be
  embedded inside each `AsyncNotifier`?
- [ ] When to migrate to the `@riverpod` annotation flavour — at the
  first provider hitting >50 LOC, or earlier?
