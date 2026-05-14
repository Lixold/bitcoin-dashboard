# ADR-0003 — Backend: Cloudflare Workers + R2 + CDN

- **Date:** 2026-05-06
- **Updated:** 2026-05-10 — v4: migration to Cloudflare Workers
- **Status:** Accepted (v4, deployed 2026-05-10)
- **Decider:** Daniel Nagel
- **Supersedes:** v1–v3 (GitHub Actions cron jobs)
- **Related:** [ADR-0005](0005-static-json-api-via-cdn.md)

## Version history

| Version | Date | Change |
|---|---|---|
| v1 | 2026-05-06 | Initial decision: GitHub Actions + Cloudflare R2 |
| v2 | 2026-05-07 | Re-evaluation, scaling path |
| v3 | 2026-05-09 | Off-beat cron schedule, `fetch_network_stats.py` |
| v4 | 2026-05-10 | Migration to Cloudflare Workers (JS); GitHub Actions removed; deployed |

## Context

The backend aggregates Bitcoin data from several sources (CoinGecko,
ECB, multilingual RSS feeds, Bitnodes, mempool.space) and exposes them
to the Flutter app as static JSON files. Constraints: minimal cost
(~0 EUR/month), maintainable by a single developer, reliable.

**Trigger for v4:** GitHub Actions `schedule:` triggers proved
unreliable in production observation — measured hit rate of 2–4 % over
a 12.5 h window, a full daily slot missed at one point. Cloudflare
Workers cron triggers ship with a documented "executed within the
minute" guarantee and a 99.9 % SLA.

## Decision: Cloudflare Workers + R2 + CDN

Two data categories, two retrieval paths:

**Live data → Flutter fetches public APIs directly (no backend).** See
[ADR-0002](0002-data-sources-and-apis.md) for the endpoints.

**Batch data → Cloudflare Workers produce JSON on a schedule.**

### Cron plan

| Worker | Cron (UTC) | Output | Secret |
|---|---|---|---|
| `cron-history` | `7,22,37,52 * * * *` | `data/history-*.json`, `data/market.json` | `COINGECKO_API_KEY` (optional) |
| `cron-news-en` | `7,22,37,52 * * * *` | `data/news-en.json` | — |
| `cron-news-de` | `7,22,37,52 * * * *` | `data/news-de.json` | — |
| `cron-fx-rates` | `23 16 * * *` | `data/fx-rates.json` | — |
| `cron-network-stats` | `13 1 * * *` | `data/network-health.json` | — |

Off-beat minutes (7, 22, 37, 52 instead of round quarters) spread the
load and avoid the herd-of-cron-jobs effect on Cloudflare's scheduler.

### Architecture

```
Flutter App
   │                              │
   │ Live data (direct)           │ Batch data (static)
   ▼                              ▼
Binance                  Cloudflare CDN
mempool.space                 │ cache miss (rare)
alternative.me                ▼
                          Cloudflare R2 (object storage)
                              ▲
                          Cloudflare Workers (cron, JS)
                          ├─ cron-history        every 15 min
                          ├─ cron-news-en        every 15 min
                          ├─ cron-news-de        every 15 min
                          ├─ cron-fx-rates       daily
                          └─ cron-network-stats  daily
                              │
                          Public APIs (CoinGecko, ECB, RSS, Bitnodes, mempool)
```

### Technology choices

- **Language:** JavaScript (ES modules). No Python rewrite needed —
  business logic was lifted from the archived Python reference scripts
  under `scripts/`.
- **R2 access:** native R2 binding (`env.BUCKET.put(...)`). No boto3,
  no S3 credentials, no signing keys.
- **XML parsing (ECB feed):** regex-based — the feed is tightly
  structured and DOMParser is not available in the workerd runtime.
- **Deduplication (news):** Web Crypto API (`crypto.subtle.digest`).
- **Secrets:** only `COINGECKO_API_KEY` for `cron-history` (optional),
  managed via `wrangler secret put`.

### R2 file layout

```
bitcoin-dashboard-data/data/
├── market.json
├── history-{1D,1W,1M,3M,1Y}.json
├── fx-rates.json
├── news-{en,de,...}.json
├── network-health.json
└── prognosis-{model}.json        (Phase 4, planned)
```

### Cache-Control policy

| File | `max-age` |
|---|---|
| `market.json`, `history-1D.json`, `news-*.json` | 900 s (15 min) |
| `history-1W.json`, `history-1M.json` … `history-1Y.json` | 900–3600 s |
| `fx-rates.json` | 86 400 s (1 d) |
| `network-health.json` | 86 400 s (1 d) |

## Cost

| Service | Free tier | Expected use | Cost |
|---|---|---|---|
| Cloudflare Workers | 100 000 requests/day | ~200/day across 5 Workers | 0 EUR |
| Cloudflare R2 storage | 10 GB | <5 MB | 0 EUR |
| Cloudflare R2 writes | 1 M ops/month | ~23 000/month | 0 EUR |
| Cloudflare CDN | unlimited | global | 0 EUR |
| Domain (`bitcoin-dashboard.app`) | n/a | 1 | ~0.80 EUR/month |
| **Total** | | | **~0–1 EUR/month** |

## Scaling path

```
Now:          CF Workers + R2 — enough for thousands of users
Optional 1:   Workers Paid ($5/month) if CPU per invocation exceeds 10 ms
Optional 2:   Add new news Workers per language (linear scale)
```

The R2 file layout and the app's consumer code are stable across all
options — no client change is forced by a scale-up.

## Consequences

**Positive**

- Cost: ~0–1 EUR/month, all on Cloudflare's free tier
- Reliability: documented 99.9 % SLA, "executed within the minute"
  cron guarantee, vs. GitHub Actions' best-effort
- No boto3, no R2 credentials in app or Worker code — the binding
  handles authentication natively
- Fully versioned in Git under `workers/`, MIT-licensed
- Auto-scales from 100 to 100 000 users with no configuration change

**Negative / risks**

- Free-tier CPU limit per invocation is 10 ms (async `fetch()` does not
  count, post-processing does). Exceeding it terminates the worker
  (Cloudflare error 1102), but does not auto-bill.
- JavaScript instead of Python — the archived Python scripts remain in
  `scripts/` as functional reference.
- `COINGECKO_API_KEY` rotation is now a Cloudflare-side concern, not
  GitHub Actions.

## Archived Python scripts

The original Python scripts under `scripts/` are kept as reference
material (MIT-licensed, open source). They are no longer part of the
active data pipeline. Each script header carries
`# ARCHIVED: replaced by Cloudflare Worker in workers/cron-<name>/`.

| Script | Replaced by |
|---|---|
| `scripts/fetch_history.py` | `workers/cron-history/` |
| `scripts/fetch_news.py` | `workers/cron-news-en/` + `workers/cron-news-de/` |
| `scripts/fetch_fx_rates.py` | `workers/cron-fx-rates/` |
| `scripts/fetch_network_stats.py` | `workers/cron-network-stats/` |
