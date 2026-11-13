# ADR-0003 — Backend: Cloudflare Workers + R2 + CDN

- **Date:** 2026-05-06
- **Updated:** 2026-11-13 — v5: records the deployed state
- **Status:** Accepted (v5; Workers deployed 2026-05-10)
- **Decider:** Lixold
- **Supersedes:** v1–v3 (GitHub Actions cron jobs)
- **Related:** [ADR-0002](0002-data-sources-and-apis.md), [ADR-0005](0005-static-json-api-via-cdn.md)

## Version history

| Version | Date | Change |
|---|---|---|
| v1 | 2026-05-06 | Initial decision: GitHub Actions + Cloudflare R2 |
| v2 | 2026-05-07 | Re-evaluation, scaling path |
| v3 | 2026-05-09 | Off-beat cron schedule, `fetch_network_stats.py` |
| v4 | 2026-05-10 | Migration to Cloudflare Workers (JS); GitHub Actions removed; deployed |
| v5 | 2026-11-13 | Text brought in line with what is deployed: Python scripts removed, shared helpers in `workers/_shared/`, `fast-xml-parser` for RSS, the cron schedules as configured, BTC Nodes as the node source, the `Cache-Control` values the Workers write, Worker settings (no public URLs, observability), the manual deploy workflow on Node 24 and Wrangler 4, and the CDN watchdog |

## Context

The backend aggregates Bitcoin data from several sources (CoinGecko,
ECB, multilingual RSS feeds, BTC Nodes, mempool.space) and exposes them
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
| `cron-history` | `*/15 * * * *` | `data/history-*.json`, `data/market.json` | `COINGECKO_API_KEY` (optional) |
| `cron-news-en` | `*/15 * * * *` | `data/news-en.json` | — |
| `cron-news-de` | `*/15 * * * *` | `data/news-de.json` | — |
| `cron-fx-rates` | `15 16 * * *` | `data/fx-rates.json` | — |
| `cron-network-stats` | `0 1 * * *` | `data/network-health.json` | — |

The schedules above are the ones in each Worker's `wrangler.toml`. The v4
text planned off-beat minutes (7, 22, 37, 52); the deployed Workers use
the plain quarter-hour schedule. `cron-fx-rates` runs at 16:15 UTC, after
the ECB publication window in both summer and winter time.

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
                          Public APIs (CoinGecko, ECB, RSS, BTC Nodes, mempool)
```

### Technology choices

- **Language:** JavaScript (ES modules). The Python reference scripts
  that preceded the Workers were deleted on 2026-05-15; the Git history
  keeps them.
- **Shared code:** everything used by more than one Worker lives in
  `workers/_shared/` (R2 writes, fetch with retry, logging, the RSS/news
  pipeline) with its tests next to it. Each Worker is `src/index.js` plus
  `wrangler.toml`; dependencies resolve through the root
  `workers/package.json` (Node ≥ 24).
- **R2 access:** native R2 binding (`env.BUCKET.put(...)`). No boto3,
  no S3 credentials, no signing keys.
- **XML parsing:** RSS feeds go through `fast-xml-parser` (v5 line), the
  only direct dependency. The ECB feed is parsed with regular
  expressions — its structure is fixed and DOMParser is not available in
  the workerd runtime.
- **Deduplication (news):** Web Crypto API (`crypto.subtle.digest`).
- **Secrets:** only `COINGECKO_API_KEY` for `cron-history` (optional),
  managed via `wrangler secret put`.
- **Exposure:** every Worker sets `workers_dev = false` and
  `preview_urls = false`. They expose only a `scheduled` handler, so a
  public URL would serve nothing and only leak the cron topology.
- **Observability:** Workers Observability is on with 100 % sampling.
  The volume is tiny (about 96 invocations a day per 15-minute Worker),
  and the per-source isolation logs are only useful if they can be read.

### Deploy and monitoring

- **Deploy:** the manual workflow `.github/workflows/deploy_workers.yml`
  (`workflow_dispatch`) deploys one Worker or all five through
  `wrangler-action` (Wrangler 4 on Node 24). Its credentials are the
  repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`;
  Worker-side secrets are set once with `wrangler secret put` and survive
  later deploys.
- **Monitoring:** `tools/cdn-watchdog/` runs hourly on GitHub Actions
  and opens one issue when a published payload goes stale or empty. It
  deliberately does not run on Cloudflare — a watchdog that lives in the
  infrastructure it watches goes quiet exactly when that infrastructure
  fails. See [CLAUDE.md §6](../../CLAUDE.md).

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

The Workers write these values as the object's `Cache-Control` header:

| File | `Cache-Control` |
|---|---|
| `market.json`, `history-*.json` | `public, max-age=900` (15 min) |
| `news-*.json` | `public, max-age=900` (15 min) |
| `fx-rates.json` | `public, max-age=86400` (1 d) |
| `network-health.json` | `public, max-age=86400` (1 d) |

## Cost

| Service | Free tier | Expected use | Cost |
|---|---|---|---|
| Cloudflare Workers | 100 000 requests/day | ~290/day across 5 Workers | 0 EUR |
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
- `COINGECKO_API_KEY` rotation is a Cloudflare-side concern, not a
  GitHub Actions one.
- The watchdog depends on GitHub's `schedule:` trigger, which is
  best-effort. That costs detection latency, not detections: the check is
  stateless and judges each payload's own timestamp.
