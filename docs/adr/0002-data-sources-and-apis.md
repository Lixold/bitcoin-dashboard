# ADR-0002 — Public data sources and APIs

- **Date:** 2026-05-06
- **Status:** Accepted (updated 2026-05-10 to reflect Cloudflare Workers;
  2026-09-06 to record the CDN as an app-side host)
- **Decider:** Daniel Nagel
- **Depends on:** [ADR-0003](0003-backend-cloudflare-workers-r2.md)

## Context

The Flutter app pulls live data straight from public APIs (no API key
required) and consumes batch data — price history, news, FX rates,
network statistics, prognoses, comparison data — as static JSON files
produced by Cloudflare Workers and served via Cloudflare R2 / CDN.

## Decision

### Live data (Flutter fetches directly)

| Data point | Source | Cadence |
|---|---|---|
| Live BTC price | Binance public API (`GET /api/v3/ticker/price?symbol=BTCUSDT`) | 60 s |
| Mempool, fees | mempool.space | 60 s |
| Hashrate, difficulty, block info | mempool.space | 5 min |
| Fear & Greed Index | alternative.me (`GET /fng/?limit=30`) | 1 h |

All four endpoints are key-less and rate-limit-friendly for client-side
polling. No vendor sees user identity beyond standard request metadata.

### Published data (Flutter reads the CDN)

| Data point | Source | Client cache |
|---|---|---|
| Mining pool shares, network health | `https://data.bitcoin-dashboard.app/data/network-health.json` | 60 min |

Until the mining-pool slice the app spoke only to the four live APIs
above; the CDN was a Worker output that nothing in `lib/` read. It is now
an **outbound host of the app**, which CLAUDE.md §1 requires to be
recorded here rather than left implicit because the domain is ours.

Being ours changes nothing about the privacy posture, and that is worth
stating rather than assuming:

- The bucket serves world-readable static JSON. Every reader receives the
  identical document, so a request reveals only that some client asked
  for a public file.
- There is no write path, no cookie, no auth header and no query string —
  the app issues a bare `GET` through the shared `dio` instance with the
  same `User-Agent` it sends everywhere else.
- Nothing is logged back to us that a CDN does not log for any static
  asset. No identifier travels with the request, and the app has no
  identity to attach to one.

The client cache above is the app's, not the CDN's: a payload is reused
for 60 minutes before it is re-requested, and is kept and shown at any
age when a fetch fails — see
[ADR-0005](0005-static-json-api-via-cdn.md) for the payload contract and
the staleness rule that goes with it.

### Batch data (Cloudflare Workers → R2 → CDN)

| Data point | Worker | Source | Output |
|---|---|---|---|
| Price history | `cron-history` (every 15 min) | CoinGecko Demo API | `data/history-{range}.json` |
| Market snapshot | `cron-history` (every 15 min) | CoinGecko Demo API | `data/market.json` |
| FX rates (~30 currencies) | `cron-fx-rates` (daily) | ECB XML feed | `data/fx-rates.json` |
| News (EN / DE; more languages planned) | `cron-news-en`, `cron-news-de` (every 15 min) | RSS feeds | `data/news-{lang}.json` |
| Network health | `cron-network-stats` (daily) | Bitnodes.io, mempool.space | `data/network-health.json` |
| Prognosis models *(Phase 4)* | TBD | CoinGecko + computed | `data/prognosis-{model}.json` |

### News feeds (MVP and planned)

| Language | Sources (selection) |
|---|---|
| English | Bitcoin Magazine, Cointelegraph, The Block, NewsBTC, CoinDesk |
| German | Blocktrainer, BitcoinBlog.de, BTC-ECHO, CryptoMonday |
| *(Roadmap)* Spanish, Portuguese (BR), French, Italian, Japanese, Korean, Chinese, Turkish | TBD |

Each language ships as its own JSON file. Topic tags (regulation,
technology, market, mining, adoption) and sentiment (positive / neutral
/ negative) are derived from a small per-language keyword lexicon
applied on a Unicode-folded copy of title + description.

### Currency conversion

Client-side only: `price_in_local = price_usd × fx_rates["LOCAL"]`. The
ECB feed publishes rates against EUR; the Worker materialises the full
cross-rate matrix so the app needs no inversion logic.

## Open data points (under evaluation)

- MVRV, NUPL, Realized Price — CoinMetrics Community API is the primary
  candidate. Glassnode's free tier is insufficient (weekly only).
- Whale activity, exchange flows, HODL waves — no fully free,
  daily-resolution source yet.
- Yahoo Finance via `yfinance` (gold, S&P 500) — ToS for commercial use
  still to be confirmed.
- CoinGlass ETF flows — ToS for open-source display still to be
  confirmed.
- S2F model attribution (PlanB, CC BY-SA) — requires authorship credit.

## Consequences

**Positive**

- CoinGecko key kept inside Cloudflare Workers (not reverse-engineerable
  from the client)
- New languages and news sources land without an app release
- Multi-currency works without paid FX APIs
- All live endpoints are key-less — no tracking surface for end users
- The CDN adds no identity surface: static, world-readable, read-only

**Negative / risks**

- RSS feed URLs occasionally change; manual monitoring needed
- CoinGecko Demo tier is 10 000 requests/month — comfortably enough for
  the cron cadence but a regression to one-per-minute would not fit
- Some Phase 4 features depend on data sources that are still
  unconfirmed
