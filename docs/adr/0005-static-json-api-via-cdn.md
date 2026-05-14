# ADR-0005 — Client ↔ CDN API: static JSON objects

- **Date:** 2026-05-06
- **Status:** Accepted (v2 — aligned with [ADR-0003](0003-backend-cloudflare-workers-r2.md))
- **Decider:** Daniel Nagel

## Context

Following [ADR-0003](0003-backend-cloudflare-workers-r2.md), there is no
API server. The Flutter app reads pre-computed JSON files from the CDN
and live data straight from public APIs. The "API design" therefore
covers three concerns:

1. The shape of the static JSON files on R2 / CDN.
2. The direct HTTP calls the app makes against public APIs.
3. The Hive cache strategy on the client.

## Data access matrix

| Data point | Source | Type | Cadence |
|---|---|---|---|
| Live BTC price | Binance direct | Live | 60 s |
| Mempool / fees | mempool.space direct | Live | 60 s |
| Fear & Greed | alternative.me direct | Live | 1 h |
| Hashrate / difficulty | mempool.space direct | Live | 5 min |
| Price history | CDN `data/history-{range}.json` | Batch | 15–60 min |
| Market snapshot | CDN `data/market.json` | Batch | 15 min |
| FX rates | CDN `data/fx-rates.json` | Batch | daily |
| News | CDN `data/news-{lang}.json` | Batch | 15 min |
| Prognosis models *(Phase 4)* | CDN `data/prognosis-{model}.json` | Batch | daily |
| Network health | CDN `data/network-health.json` | Batch | daily |
| Meta / supported languages *(planned)* | CDN `data/meta.json` | Batch | on change |

## CDN file formats

### `data/market.json`

```json
{
  "fetchedAt": "2026-05-12T08:00:00+00:00",
  "currency": "usd",
  "marketCap": 1873000000000,
  "volume24h": 42000000000,
  "ath": 109000,
  "athDate": "2025-01-20",
  "atl": 67.81,
  "atlDate": "2013-07-06",
  "circulatingSupply": 19750000,
  "totalSupply": 19750000,
  "maxSupply": 21000000,
  "btcDominance": 54.3
}
```

### `data/history-{range}.json`

```json
{
  "range": "1M",
  "currency": "usd",
  "fetchedAt": "2026-05-12T08:00:00+00:00",
  "timestamps": [1743531600000, 1743618000000],
  "prices": [82450.20, 83120.50]
}
```

The two parallel arrays are sized for direct consumption by fl_chart
without remapping. Currency conversion happens client-side using
`fx-rates.json`.

### `data/fx-rates.json`

```json
{
  "_meta": {
    "fetchedAt": "2026-05-12T16:25:00+00:00",
    "date": "2026-05-12",
    "source": "ECB",
    "currencies": ["AUD","BGN","...","ZAR"]
  },
  "EUR": { "USD": 1.08, "CHF": 0.92, "...": 0, "EUR": 1.0 },
  "USD": { "EUR": 0.926, "...": 0, "USD": 1.0 }
}
```

The Worker materialises the full base→quote matrix so the app does not
have to invert rates.

### `data/news-{lang}.json`

```json
{
  "_meta": {
    "fetchedAt": "2026-05-12T08:00:00+00:00",
    "language": "en",
    "feedCount": 5,
    "itemCount": 42,
    "validatedFeeds": ["Bitcoin Magazine", "Cointelegraph", "..."]
  },
  "news": [
    {
      "id": "9a3c7e1f8b0d5a2e",
      "title": "Bitcoin crosses 95,000 USD",
      "url": "https://example.org/article",
      "source": "BTC-ECHO",
      "publishedAt": "2026-05-12T07:30:00+00:00",
      "tags": ["market"],
      "sentiment": "positive",
      "description": "Short plain-text excerpt up to 150 chars …"
    }
  ]
}
```

`id` is `SHA1(url + publishedAt)` truncated to 16 hex chars. Items are
sorted newest first. Each language ships its own file.

### `data/network-health.json`

```json
{
  "_meta": {
    "fetchedAt": "2026-05-12T01:13:00+00:00",
    "date": "2026-05-12",
    "sources": ["Bitnodes.io", "Mempool.space"]
  },
  "fullNodes": { "count": 17234, "percentChange24h": 0.21, "trend": "stable" },
  "miningPools": [
    { "name": "Foundry USA", "hashratePercent": 28.4, "blockCount": 41, "alert": false }
  ],
  "poolConcentrationAlert": false,
  "aggregatedHealth": "good"
}
```

## Direct live calls

```
GET https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT
GET https://mempool.space/api/v1/fees/recommended
GET https://mempool.space/api/v1/mining/hashrate/3d
GET https://mempool.space/api/v1/difficulty-adjustment
GET https://api.alternative.me/fng/?limit=30
```

The app reads `fx-rates.json` once per session and converts client-side:
`price_local = price_usd × fx_rates["USD"][selected_currency]`.

## Hive cache strategy

| Hive key | Content | TTL |
|---|---|---|
| `settings` | language, currency, theme, news languages | persistent |
| `cache_market` | last `market.json` | 15 min |
| `cache_history_{range}` | last `history-{range}.json` | range-dependent |
| `cache_fx_rates` | last `fx-rates.json` | 24 h |
| `cache_news_{lang}` | last `news-{lang}.json` | 15 min |
| `cache_network_health` | last `network-health.json` | 24 h |
| `cache_feargreed` | last F&G value | 1 h |

Offline behaviour: the app boots from cache first, then refreshes in
the background. With no connectivity it surfaces a "Last updated X min
ago" notice and keeps the cached values.

## Versioning

Breaking schema changes go to a parallel path:

```
data/v1/market.json    (current — implicit v1)
data/v2/market.json    (new shape published alongside until clients update)
```

A future `meta.json` will expose `api_version` so the app can switch
deliberately.

## Consequences

**Positive**

- No server, no API code, no auth surface — only static files
- Easy to debug: open the JSON URL in any browser
- Additive field changes are non-breaking

**Negative / risks**

- No parameterised queries; client-side conversion compensates for
  currency
- Multiple files for multiple news languages; a single combined file
  would bloat the per-request payload

## Open questions

- [ ] Pagination strategy if a single language ever exceeds ~50
      items
- [ ] WebSocket for live price via Binance Stream as a polling
      alternative — to be evaluated in Phase 2
