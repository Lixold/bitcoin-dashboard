# System overview

Bitcoin Dashboard is a **purely client-side Flutter application with no origin
server**. Live data the app fetches directly from public APIs. Aggregated
batch data — price history, market snapshot, FX rates, news, network
statistics — is produced by **Cloudflare Workers** on a cron schedule, written
as static JSON to **Cloudflare R2** and delivered worldwide by the
**Cloudflare CDN** at `data.bitcoin-dashboard.app`. There is no VPS, no
orchestration server, no Redis and no API server ([CLAUDE.md §11](../../CLAUDE.md)).

The decisions behind this page: [ADR-0001](../adr/0001-flutter-tech-stack.md)
(Flutter), [ADR-0002](../adr/0002-data-sources-and-apis.md) (data sources),
[ADR-0003](../adr/0003-backend-cloudflare-workers-r2.md) (Workers, R2, CDN),
[ADR-0004](../adr/0004-state-management-riverpod.md) (Riverpod),
[ADR-0005](../adr/0005-static-json-api-via-cdn.md) (payload contract),
[ADR-0006](../adr/0006-news-filtering-and-lexicon-tagging.md) (news) and
[ADR-0007](../adr/0007-information-architecture-and-navigation.md)
(sections and navigation).

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│ Flutter app (macOS / Windows / iOS / Android / Linux)        │
│                                                              │
│   Sections: price · market · forecast · network · miner ·    │
│             news   (a section appears with its first slice)  │
│                                                              │
│   features/<feature>/presentation   screens, widgets         │
│   features/<feature>/domain         models, bands, logic     │
│   features/<feature>/data           API clients, providers,  │
│                                     cache                    │
│                       │                      │               │
│              dio + Hive cache        dio + Hive cache        │
└───────────────────────┼──────────────────────┼───────────────┘
                        │ live, direct         │ batch, static
                        ▼                      ▼
        ┌───────────────────────┐   ┌─────────────────────────┐
        │ Public APIs           │   │ Cloudflare CDN          │
        │ Binance (price)       │   │ data.bitcoin-dashboard  │
        │ mempool.space         │   │ .app                    │
        │ alternative.me        │   └────────────┬────────────┘
        └───────────────────────┘                │ cache miss
                                                 ▼
                                    ┌─────────────────────────┐
                                    │ Cloudflare R2           │
                                    │ data/*.json             │
                                    └────────────▲────────────┘
                                                 │ R2 binding
                                    ┌────────────┴────────────┐
                                    │ Cloudflare Workers      │
                                    │ cron-history            │
                                    │ cron-fx-rates           │
                                    │ cron-news-en / -de      │
                                    │ cron-network-stats      │
                                    └────────────┬────────────┘
                                                 │
                         CoinGecko · ECB · RSS feeds · BTC Nodes ·
                         mempool.space
```

The CDN watchdog (`tools/cdn-watchdog/`) runs from GitHub Actions, not from
Cloudflare, and reads what the Workers publish
([CLAUDE.md §6](../../CLAUDE.md)).

## Who fetches what

The full matrix, with cadences, is in
[ADR-0005](../adr/0005-static-json-api-via-cdn.md#data-access-matrix); the
sources and the hosts the app is allowed to call are in ADR-0002. In short:

| Kind | Data | Fetched by |
|---|---|---|
| Live | BTC price, mempool and fees, hashrate and difficulty, Fear & Greed | The app, directly from the public API |
| Batch | Price history, market snapshot, FX rates, news, network health | The app, from the CDN; produced by a Worker |
| Client-side | Currency conversion, the mining calculator, every statement | The app, from data it already holds |

## Batch pipeline

Each Worker is a `scheduled` handler that reads its sources, writes JSON to R2
through a native binding and exposes no public route. Shared code —
fetch-with-retry, logging, R2 writes, the RSS pipeline — lives in
`workers/_shared/` and is never copied into a Worker. A merge does not deploy;
the Workers are deployed by hand through the `Deploy Cloudflare Workers`
workflow. Schedules, file layout, `Cache-Control` values, cost and the scaling
path are in ADR-0003.

**Planned Workers** (see the [roadmap](../product/roadmap.md)). Each publishes
under the contract of ADR-0005 and gets a row in
`tools/cdn-watchdog/payloads.js` in the pull request that adds it.

| Worker | Output | Source |
|---|---|---|
| `cron-prognosis` | `data/prognosis-{model}.json` | Computed: Stock-to-Flow, Rainbow, Power Law, halving cycle, moving averages |
| `cron-onchain-valuation` | `data/onchain-valuation.json` | MVRV, NUPL, Realized Price; source to be chosen |
| `cron-comparisons` | `data/comparisons.json` | Gold, S&P 500, inflation; sources to be chosen |
| `cron-etf-flows` | `data/etf-flows.json` | CoinGlass API |
| `cron-github-activity` | `data/github-activity.json` | GitHub REST API (Bitcoin Core) |
| `cron-whale-data` | `data/whale-flows.json` | To be chosen |

## In the app

**State.** Riverpod, classic API without code generation
([ADR-0004](../adr/0004-state-management-riverpod.md)). A provider per data
source lives in the feature's `data/` directory and states its retry cadence or
declines one. A provider that depends on a setting watches it and is
invalidated when the setting changes.

**Cache.** The app starts from the Hive cache and refreshes in the background.
Without a connection the cache stays active and the screen says how old the
data is. Keys and lifetimes are in ADR-0005.

**Statements.** The comment text for a metric is produced in Dart from a
declared `BandScale`; every text is a localised ARB key
([CLAUDE.md §5](../../CLAUDE.md)).

**Localisation.** Language and currency are settings, persisted locally;
they start as English and USD. Detecting the device locale on first launch is
requirement F09.3. Currency conversion happens on the device:
`price_usd × fx_rates["USD"][currency]`, from one matrix document that serves
every currency, so changing the currency is immediate and costs no request. See
[internationalisation](../features/internationalisation.md).

**Local data.** Settings and cached payloads live in Hive boxes inside the
platform sandbox. Nothing leaves the device
([CLAUDE.md §1](../../CLAUDE.md)).

## Cost and scaling

About 0–1 EUR per month, on the free tiers of Cloudflare plus the domain. The
upgrade path, if a Worker ever exceeds its CPU budget, and why the app never has
to change for it, are in ADR-0003.
