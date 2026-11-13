# Roadmap

What each phase of the project covers. This page is the plan of the work, not
its status. The backlog, what is open, blocked or done, lives in
[GitHub Issues](https://github.com/Lixold/bitcoin-dashboard/issues) and the
[project board](https://github.com/users/Lixold/projects/1)
([CLAUDE.md §10](../../CLAUDE.md)). A phase here names what belongs to it;
whether a given piece has shipped is answered there.

Work is delivered as vertical slices
([CLAUDE.md §5](../../CLAUDE.md)): one user-visible capability, from data
source to pixels, in one pull request. The theses are the ones in the
[functional requirements](functional-requirements.md).

| Phase | Theme |
|---|---|
| 1 | Foundation |
| 2 | Infrastructure and app scaffold |
| 3 | MVP features |
| 4 | Forecasts, comparisons, full build-out |
| 5 | Launch |
| 6 | Operations and community |

## Phase 1 — Foundation

Project definition and requirements, the documentation structure, and the
architecture decisions: [Flutter](../adr/0001-flutter-tech-stack.md),
[data sources](../adr/0002-data-sources-and-apis.md),
[Cloudflare Workers, R2 and CDN](../adr/0003-backend-cloudflare-workers-r2.md),
[Riverpod](../adr/0004-state-management-riverpod.md) and
[static JSON via CDN](../adr/0005-static-json-api-via-cdn.md).

## Phase 2 — Infrastructure and app scaffold

The public repository, the R2 bucket and the CDN domain
`data.bitcoin-dashboard.app`, the first data pipeline (price history), the
Flutter scaffold with navigation, theme and dark/light mode, and the first
screen with a live price.

## Phase 3 — MVP features

Covers theses 1, 4 and 8 and part of thesis 2.

**Data pipeline.** Workers for news (EN, DE), FX rates and network statistics,
shared pipeline code in `workers/_shared/`, CI hardening, and the CDN watchdog
that watches what the Workers publish.

**App foundation.** Design system and typography, routing with one branch per
section, settings behind the header gear, adaptive navigation
([ADR-0007](../adr/0007-information-architecture-and-navigation.md)), the
shared test harness, and the declared threshold mechanism for statements
(`BandScale`, [CLAUDE.md §5](../../CLAUDE.md)).

**Slices, by section.**

- *Price:* distance to the all-time high and market share; trend statement and
  chart; currency switch and the sats line.
- *Market:* the sentiment index in five bands with its 30-day history; the
  200-week average as a floor reference.
- *Network:* fees, mempool, hashrate and difficulty; mining-pool
  concentration; the number of reachable full nodes and the aggregated
  health.
- *News:* the EN and DE list from `news-{lang}.json`.

Phase 3 ends with a first internal macOS test version.

## Phase 4 — Forecasts, comparisons, full build-out

Covers theses 2, 3, 5, 6 and 7 and the remaining part of thesis 4.

**Data pipeline.** New Workers, each following
[ADR-0003](../adr/0003-backend-cloudflare-workers-r2.md) and publishing under
the contract of [ADR-0005](../adr/0005-static-json-api-via-cdn.md):

- `cron-prognosis` — Stock-to-Flow, Rainbow, Power Law, halving cycle and
  moving averages.
- `cron-onchain-valuation` — MVRV Z-Score, NUPL, Puell Multiple and Realized
  Price, once a source has been chosen.
- `cron-comparisons` — gold, S&P 500 and inflation.
- `cron-etf-flows` — Bitcoin spot ETF flows.
- `cron-github-activity` — Bitcoin Core commits and contributors.
- `cron-whale-data` — exchange flows and large-wallet trends, once a source
  has been chosen.
- A 30-day mean of the 24-hour volume in `cron-history`, and a source for
  price history beyond the 365 days the CoinGecko Demo API allows. The second
  becomes an ADR when it is decided.

Candidate sources and the open questions about their terms are listed in
[ADR-0002](../adr/0002-data-sources-and-apis.md).

**App.**

- *Valuation signal* (thesis 2): MVRV, NUPL, Realized Price, the Pi Cycle Top
  indicator and the composite market status.
- *Forecasts* (thesis 3): target-year slider, the five models, models
  individually switched on and off.
- *Mining calculator* (thesis 5), entirely client-side.
- *Large holders* (thesis 6): ETF flows first, the rest after source
  evaluation.
- *Relative value* (thesis 7): Bitcoin against gold, shares and inflation, and
  Bitcoin dominance.
- *GitHub activity* of Bitcoin Core (F04.7).
- News in the remaining languages of the first four rollout waves, and UI
  translations for the first ten languages
  ([internationalisation](../features/internationalisation.md)).
- Builds for Windows, iOS and Android, and a public beta through GitHub
  Releases ([distribution](../deployment/distribution.md)).

## Phase 5 — Launch

Store submissions (Mac App Store and App Store, Microsoft Store, Google Play),
GitHub Releases including the Linux package, and a landing page at
`bitcoin-dashboard.app`.

## Phase 6 — Operations and community

**Monitoring outside the app.** Worker run status and error rates, availability
of the CDN endpoints, the external APIs the app and the Workers depend on and
fallbacks for their outages, and the quality of the published JSON (schema
checks and anomalies). Freshness and emptiness of the payloads are already
watched by the CDN watchdog. Nothing is measured or reported from a user's
device ([CLAUDE.md §1](../../CLAUDE.md)).

**Community and feedback.** Issue templates for bugs, GitHub Discussions for
ideas, a label scheme for triage (type, severity, `good first issue`,
`help wanted`) and a routine for working through reports.

**Release communication.** Release notes generated from squash-merged pull
requests, milestones and the project board as the public roadmap, and a
changelog updated with every release.
