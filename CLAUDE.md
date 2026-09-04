# CLAUDE.md

Working notes for contributors and coding agents. Read this before
touching the repository — it describes how this project is built, not
what it is marketed as. For the user-facing overview see
[README.md](README.md); for architecture decisions see
[docs/adr/](docs/adr/).

---

## 1. Purpose and product values

Bitcoin Dashboard is a cross-platform Flutter app that shows live BTC
price, on-chain metrics, network health, sentiment, multilingual news,
and (roadmap) valuation models on macOS, Windows, iOS, Android, and
Linux.

The following values are architectural constraints, not slogans. Code
that violates them does not get merged:

- **No login, no accounts.** There is no auth layer, no session, no
  user identity anywhere in the codebase.
- **No tracking, no analytics, no telemetry.** Nothing is reported to
  third parties, to the maintainer, or to FinHood. Do not add crash
  reporters, analytics SDKs, ad SDKs, remote logging, or "anonymous
  usage statistics". Test coverage is printed into the CI job log
  precisely so it does not have to be uploaded to an external service.
- **No personal data leaves the device.** Settings and cached payloads
  live in local Hive boxes inside the platform sandbox.
- **No origin server, no write path.** The app reads public APIs and
  read-only static JSON from a CDN. There is no endpoint the app can
  write to.
- **Outbound network calls are an API decision.** Every new host the
  app talks to must be justified and documented in
  [ADR-0002](docs/adr/0002-data-sources-and-apis.md). No silent new
  endpoints.

See [SECURITY.md](SECURITY.md) for the threat model that follows from
these constraints.

---

## 2. Tech stack and minimum versions

### App

| Area | Technology | Minimum |
|---|---|---|
| Framework | Flutter (stable) | 3.41.9 (CI-pinned) |
| Language | Dart | SDK `^3.11.5` |
| State management | `flutter_riverpod` ([ADR-0004](docs/adr/0004-state-management-riverpod.md)) | ^3.3.1 |
| Routing | `go_router` | ^17.5.0 |
| HTTP | `dio` | ^5.9.2 |
| Local cache / settings | `hive`, `hive_flutter` | ^2.2.3 / ^1.1.0 |
| Charts | `fl_chart` | ^1.2.0 |
| i18n / formatting | `intl`, `flutter_localizations` | ^0.20.2 |
| Lints | `flutter_lints`, `riverpod_lint` | ^6.0.0 / ^3.1.3 |

Riverpod is used with the classic API — no codegen for now
(`riverpod_annotation` / `riverpod_generator` may be added later; if
you add it, do it in its own PR).

### Workers

| Area | Technology | Minimum |
|---|---|---|
| Runtime | Cloudflare Workers (JS, ESM) | — |
| Local toolchain | Node.js | >= 24 |
| Deploy | Wrangler | v4 |
| Test runner | `node --test` | Node 24 built-in |
| XML/RSS parsing | `fast-xml-parser` | ^5.5.7 |

### Release targets

macOS 13+, Windows 10+, iOS 16+, Android 9+ (API 28), Linux. Web is a
development and preview target only (`flutter run -d chrome`), not a
shipped product — do not add web-only features or web-only workarounds
to shared code.

### Static analysis

[`analysis_options.yaml`](analysis_options.yaml) enables
`strict-casts`, `strict-inference`, and `strict-raw-types`, promotes
`unawaited_futures` and `missing_return` to errors, and runs
`custom_lint` (Riverpod misuse detection). Enforced style includes
single quotes, `const` constructors and declarations, `final` locals,
trailing commas, and no `print`. Generated code (`*.g.dart`,
`*.freezed.dart`, `lib/l10n/generated/`) is excluded.

---

## 3. Repository structure

```
bitcoin-dashboard/
├── lib/                        # Flutter app source
│   ├── core/                   # Cross-feature infrastructure
│   │   ├── http/               # dio provider / HTTP setup
│   │   ├── router/             # GoRouter: one shell branch per section
│   │   └── theme/              # theme tokens, AppTheme
│   ├── features/               # One directory per feature
│   │   └── <feature>/
│   │       ├── data/           # API clients, providers, caching
│   │       ├── domain/         # Models, enums, pure logic
│   │       └── presentation/   # Screens and widgets
│   ├── l10n/                   # app_en.arb, app_de.arb (+ generated/)
│   ├── app.dart                # Root widget, routing/shell wiring
│   └── main.dart               # Entry point, Hive + ProviderScope init
├── test/                       # Mirrors lib/ path-for-path
├── workers/                    # Cloudflare Workers (cron-triggered)
│   ├── _shared/                # lib.js, news_pipeline.js (+ *.test.js)
│   ├── cron-history/           # CoinGecko → history-*.json + market.json
│   ├── cron-fx-rates/          # ECB XML → fx-rates.json (daily)
│   ├── cron-news-en/           # RSS EN → news-en.json
│   ├── cron-news-de/           # RSS DE → news-de.json
│   ├── cron-network-stats/     # Bitnodes + mempool.space → network-stats.json
│   └── package.json            # Shared deps + `npm test` for all Workers
├── docs/adr/                   # Architecture Decision Records (English mirror)
├── .github/workflows/          # ci.yml, deploy_workers.yml
└── android/ ios/ macos/ windows/ linux/ web/   # Platform projects
```

Conventions:

- **Feature-first, not layer-first.** New UI, its providers, and its
  models live under `lib/features/<feature>/`. Only code used by more
  than one feature belongs in `lib/core/`.
- **`test/` mirrors `lib/`.** `lib/features/price/data/x.dart` →
  `test/features/price/data/x_test.dart`. Repository-hygiene checks
  are the exception: a test that covers `assets/`, the build files
  or the shape of the tree has no `lib/` counterpart to mirror, so
  it sits beside the check it belongs with rather than at a mirrored
  path — `test/core/widgets/asset_hygiene_test.dart` next to the
  bundling test in `brand_icon_test.dart`.
- **`workers/_shared/`** holds everything used by more than one Worker
  (R2 writes, fetch-with-retry, logging, the RSS/news pipeline). Each
  Worker under `workers/cron-*/` is `src/index.js` + `wrangler.toml`
  and resolves shared deps through the root `workers/package.json`.
  Put new cross-Worker logic in `_shared/` with a `*.test.js` next to
  it — never copy-paste it between Workers.
- **Localisation:** `lib/l10n/app_en.arb` is the template; every
  user-facing string goes into both `app_en.arb` and `app_de.arb`.
  `lib/l10n/generated/` is produced by `flutter gen-l10n` (runs
  automatically on `flutter pub get`) — never edit it by hand.

---

## 4. Backend architecture

Live data (price, mempool, fees, sentiment) is fetched **directly by
the app** from public APIs — there is no API server in between.
Aggregated or rate-limited data (price history, market snapshot, FX
rates, news, network stats) is produced by cron-triggered Cloudflare
Workers and published as static, read-only JSON to R2, served via the
CDN at `data.bitcoin-dashboard.app`.

Details — why Workers instead of GitHub Actions cron, the R2 bucket
layout, and the deploy path — are in
[ADR-0003](docs/adr/0003-backend-cloudflare-workers-r2.md); the client
↔ CDN payload contract is in
[ADR-0005](docs/adr/0005-static-json-api-via-cdn.md).

---

## 5. Development workflow: vertical slices

**Ship features as vertical slices.** One slice = one user-visible
capability, complete from data source to pixels, in one PR.

**Do not build screen shells with placeholder content.** A screen that
renders `—`, `TODO`, lorem ipsum, hard-coded sample numbers, or a
disabled control "until the provider lands" is not a slice and does
not get merged. If the data for a section is not ready, the section is
not in the PR.

Order of work within a slice:

1. **Data contract first.** Define where the data comes from and what
   it looks like: the public API endpoint or the CDN JSON shape, plus
   the Dart model in `domain/`. Payload changes must be reflected in
   [ADR-0005](docs/adr/0005-static-json-api-via-cdn.md); new sources
   in [ADR-0002](docs/adr/0002-data-sources-and-apis.md). If a Worker
   has to produce the data, that Worker change ships first or in the
   same PR.
2. **Design.** A design for this slice exists and is linked in the
   issue before any widget work starts. **The input to a slice design
   is a thesis, not an existing screen.** Brief it as thesis,
   statement, evidence, states, components, and what is out of scope.
   A design briefed from an existing layout reproduces that layout's
   omissions. Resolve layout, states, and tokens before writing
   widgets. Every screen needs its loading, empty, and error states
   defined up front — they are part of the slice, not a follow-up.
   Use the tokens in `lib/core/theme/`; do not hard-code colours,
   type, or spacing in widgets.
3. **Provider + UI in the same PR.** The Riverpod provider and the
   widgets that consume it land together. No UI without its data
   source, no provider without a consumer.
4. **Tests.** See §7.
5. **PR.** See §6.

**Definition of Done** — all of these, or it is not done:

- No placeholders anywhere in the shipped code: no dummy values, no
  dead controls, no commented-out branches, no `TODO`/`FIXME` left in
  the diff for the feature being shipped.
- Every figure sits inside a Statement with its insight sentence — no
  bare numbers. A number without a sentence is a placeholder by
  another name and does not ship.
- Loading, empty, and error states are implemented and reachable.
- User-facing strings are localised in `app_en.arb` **and**
  `app_de.arb` — no literals in widgets.
- Insight-sentence categories are translation keys, not hard-coded
  copy.
- Tests for the new code exist and pass.
- `dart format .`, `flutter analyze`, and `flutter test` are clean
  locally; Worker changes additionally pass `npm --prefix workers test`.
- No new outbound host, dependency, or stored field that is not
  covered by §1 and documented.

---

## 6. Pull requests and CI

- **Never push directly to `main`.** `main` is protected. Work on a
  branch (`feat/…`, `fix/…`, `docs/…`, `chore/…`, `ci/…`) and open a
  PR.
- **All 15 required checks must be green before merge.** From
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml):

  | # | Check |
  |---|---|
  | 1 | Dart Format |
  | 2 | Flutter Analyze |
  | 3 | Flutter Test & Coverage |
  | 4–8 | Flutter Build — linux, windows, macos, android, ios |
  | 9 | Dependency Review |
  | 10–14 | Workers Lint — cron-history, cron-fx-rates, cron-network-stats, cron-news-en, cron-news-de |
  | 15 | Workers Tests |

  The Flutter jobs are chained (`format` → `analyze` → `test`/`build`),
  so an unformatted file skips every downstream job. Run
  `dart format .` before pushing.
- **Actions run under an allow-list.** This repository is configured
  with *Allow select actions* under Settings → Actions → General;
  there is no blanket permission for `actions/*`. Adding an action
  that is not on the list, or bumping one whose entry pins a version,
  therefore needs a repository-settings change alongside the workflow
  edit — a maintainer task that cannot be done from a PR. When that is
  missed, the run ends as `startup_failure` with no jobs, no
  annotations and no check runs, so `gh pr checks` says `no checks
  reported on the branch`: it reads like the workflow was never
  triggered rather than like a failing check, and neither `actionlint`
  nor any local command can see the constraint. The list itself is a
  settings value and is deliberately not copied into this repository —
  read it in the settings page.
- **One PR, one topic.** Keep unrelated refactors, dependency bumps,
  and housekeeping in their own PRs.
- **Describe the slice in the PR body:** what ships, what is
  deliberately out of scope, and how it was verified.
- Worker deploys are manual via the `Deploy Cloudflare Workers`
  workflow — merging a Worker change does not deploy it.

### Local pre-flight

```bash
dart format .
flutter analyze
flutter test
npm --prefix workers test     # only when workers/ changed
```

---

## 7. Testing

**New code ships with tests in the same PR.** A PR that adds behaviour
and no tests is incomplete.

- **Dart:** `flutter_test`, files under `test/` mirroring `lib/`,
  named `*_test.dart`. Unit-test domain logic and providers (override
  providers in a `ProviderContainer`; no real network in tests);
  widget-test screens for layout, responsive breakpoints, and the
  loading/empty/error states.
- **Workers:** Node's built-in runner (`node --test`), files named
  `*.test.js` next to the code they cover. Extract pure functions
  (parsers, aggregators, formatters) so they are testable without a
  `fetch` or an R2 binding; test those directly.
- Tests must be deterministic and offline: no live API calls, no
  reliance on wall-clock time or on ordering of real feeds.
- Coverage is reported in the CI job log only — never wire up an
  external coverage service (§1).

---

## 8. Language

- **Code, identifiers, filenames, comments, and commit messages are
  English.** This includes branch names, PR titles, PR descriptions,
  ADRs, and every file in this repository.
- **German exists only as user-facing copy** in `lib/l10n/app_de.arb`
  (and in future locale ARBs). A German word must never appear as a
  class, variable, file, or asset name.
- Commit messages follow Conventional Commits:
  `type(scope): summary` — e.g. `feat(price): add ATH card`,
  `fix(cron-news-en): tolerate missing pubDate`. Imperative mood,
  lower case, no trailing period.

---

## 9. Where knowledge lives

One subject, one canonical place. Everything else links to it.

| Subject | Canonical location |
|---|---|
| Architecture decisions | `docs/adr/` |
| Working rules, Definition of Done, conventions | this file |
| Executable step sequences for agents | `.claude/skills/` |
| Backlog, tasks, status | GitHub Issues and the project board |
| Product strategy and roadmap | maintained outside this repository |
| Glyphs, logos and design tokens | the design-system project in Claude Design |

**Precedence.** This repository is authoritative for how the project is built. If an
external note, an earlier session, or a private document says otherwise, this file
wins. Private local notes may add context; they never override anything here.

**Design-system sync.** The design system is the one store outside this repository that
is canonical for files inside it, so its boundary is fixed here rather than decided per
pull:

- **One direction.** `/design-sync` pulls; it never pushes. Claude Design is the source
  for glyph geometry, this repository executes it. A push from the CLI would reverse
  that precedence.
- **One boundary.** Drawing crosses: geometry, `viewBox`, attributes, path data.
  Generator metadata does not — no C2PA manifest, no editor annotations, no export
  timestamps. Claude Design re-signs a manifest into every file it saves, so stripping
  it is a step of every pull, not a one-off; `test/core/widgets/asset_hygiene_test.dart`
  fails when one reaches `assets/`.
- **Normalised comparison.** Byte-identity with the design system is not the goal — that
  serialiser is not ours and can change at any time. Compare the two stores by
  normalising empty-element serialisation (`<path/>` against `<path></path>`) and the
  trailing newline first, never by comparing bytes.

---

## 10. How work starts

- **GitHub Issues and the project board are the only backlog.** No task lists in
  markdown files, no work items living in a chat transcript.
- A slice may start only when all five are true. Otherwise stop and open the
  prerequisite issue (`needs-data`, `needs-design`) instead of improvising:
  1. the data contract is verified against the live CDN, not assumed;
  2. a design for this slice is linked in the issue;
  3. the statement the slice makes is written in one sentence;
  4. the evidence is named — which figure backs which part of the statement;
  5. the issue carries the Definition of Done checklist.
- Branch `slice/<issue-number>-<short-topic>`; the PR body closes the issue.
- `.claude/skills/slice/SKILL.md` is the enforced implementation sequence and
  `.claude/skills/review/SKILL.md` the pre-merge check. Follow them rather than
  improvising an order.
- **Acceptance is human.** Someone runs the app and looks at the change. When you
  finish, summarise in two sentences what is now visible and what to look at when
  running it.
- **The target is part of the acceptance.** Which one counts follows from what changed:
  - **Chrome is enough** for layout, navigation, interaction, and the loading, empty and
    error states.
  - **A native target is required** for anything platform-dependent — fonts, platform
    menus, window chrome, file paths, platform APIs. Chrome resolves these through the
    browser engine, not through the platform the shipped app sits on, so a browser run
    can show something the product never renders.
  - **A change that renders nothing** — CI, Workers, docs, this file — has no
    acceptance target. Say that in the PR instead of claiming a run.

  Platform-dependent work names its target in the issue before the work starts, not in
  the PR afterwards. Where that target is not available, the PR records acceptance as
  **deferred** — which target is missing, why, and what stays unseen. Deferred is a
  state the change carries until someone runs it there; it is not a box to tick, and a
  run on a target that could not have shown the change does not clear it. A claim from
  such a target fails the review gate. `README.md` covers how to run each target; this
  rule only says which one counts.

---

## 11. Repository hygiene

- `pubspec.lock` and `workers/package-lock.json` are committed. Never add `*.lock` to
  `.gitignore` — reproducible builds depend on both.
- The architecture in ADR-0001 to ADR-0005 is settled: no VPS, no orchestration server,
  no API server, no GitHub Actions cron for data. Do not renavigate without a new ADR.
- Shared Worker logic lives in `workers/_shared/`. Never copy it into a Worker.

---

## 12. Scope of this repository

This repository covers the Flutter app and the Cloudflare Workers that feed it.
Commercial topics — pricing, positioning, market analysis, other products — are
maintained elsewhere and are not discussed in code, documentation, or commit messages
here.
