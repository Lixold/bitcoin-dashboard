# ADR-0005 — Client ↔ CDN API: static JSON objects

- **Date:** 2026-05-06
- **Updated:** 2026-09-13 — v4: `aggregatedHealth` gains `unknown`
- **Status:** Accepted (v4 — aligned with [ADR-0003](0003-backend-cloudflare-workers-r2.md))
- **Decider:** Daniel Nagel

## Version history

| Version | Date | Change |
|---|---|---|
| v1 | 2026-05-06 | Initial contract: static JSON on R2 behind the CDN |
| v2 | 2026-05-10 | Aligned with ADR-0003 (Cloudflare Workers) |
| v3 | 2026-08-28 | Time representation stated explicitly (see below) |
| v4 | 2026-09-13 | `aggregatedHealth` gains `unknown`; node source is BTCNodes.io |

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

## Time representation

Two forms, and no others:

- **Instants that describe a payload** (`fetchedAt`, `publishedAt`, `date`)
  are ISO-8601 strings with an explicit UTC offset:
  `YYYY-MM-DDTHH:MM:SS+00:00`, produced by `isoUtcSeconds` in
  `workers/_shared/lib.js`.
- **Numeric epochs inside data series** are **milliseconds, UTC**. The only
  such field today is `timestamps` in `history-{range}.json`.

One documented exception: `athDate` and `atlDate` in `market.json` are passed
through from CoinGecko unchanged and arrive in the `Z` form with milliseconds
(`2025-10-06T10:57:42.000Z`) rather than the `+00:00` form above. They are not
produced by `isoUtcSeconds`, and normalising them in the Worker would rewrite a
source value for cosmetics. Clients parse both — `DateTime.parse` in the app
accepts either — so this is a note about what the payload *is*, not a licence
for new fields to pick a form.

Numeric epochs must never be passed through a bitwise operator in a Worker:
JavaScript converts to a signed 32-bit integer first, and a millisecond
epoch (~1.79e12) wraps. `Number(p[0]) | 0` in `cron-history` shipped exactly
that corruption — timestamps decoded to 2006-2009 and the 3M and 1Y series
lost monotonicity because the wraparound fell inside the array.

## CDN file formats

### `data/market.json`

```json
{
  "fetchedAt": "2026-09-09T18:30:59+00:00",
  "currency": "usd",
  "marketCap": 1578083556466,
  "volume24h": 34469991545,
  "ath": 126080,
  "athDate": "2025-10-06T10:57:42.000Z",
  "atl": 67.81,
  "atlDate": "2013-07-05T16:00:00.000Z",
  "circulatingSupply": 20081962,
  "totalSupply": 20081975,
  "maxSupply": 21000000,
  "btcDominance": 58.38111273322796
}
```

Verified against the live CDN on 2026-09-09; `test/support/fixtures/market.json`
is the capture that reading is taken from.

Three things this example is here to pin down, because each one has already
been read the other way:

- **`ath` is an integer**, and `marketCap`, `volume24h` and the supply figures
  are too. Only `atl`, `btcDominance` and any future ratio arrive fractional.
  A client that types `ath` as a floating-point field is right by accident;
  one that types it as `int` breaks the day CoinGecko returns a fraction. Parse
  the numeric fields as numbers.
- **`circulatingSupply` and `totalSupply` are no longer equal.** They were on
  2026-08-28 and are not now. Whoever shows them must not treat them as one
  value.
- **`currency` says what every amount in the file is quoted in.** It is the
  field a client formats against; the app does not assume USD, and until FX
  conversion ships it renders what this field says.

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

`timestamps` are **milliseconds since the Unix epoch, UTC** — the unit
CoinGecko returns, passed through unmodified. The client reads them with
`DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)`; the values are
exactly representable as `double`, so fl_chart can use them as x-values
without remapping.

The two arrays are index-aligned and equally long: a pair whose timestamp
or price is not a finite number is dropped from both, never emitted as
`null`. Within one file the series is strictly increasing. Spacing follows
the range (1D 5 min, 1W/1M/3M 1 h, 1Y 1 d) but is not guaranteed constant —
the client must not derive a timestamp from an index.

Currency conversion happens client-side using `fx-rates.json`.

### `data/fx-rates.json`

```json
{
  "_meta": {
    "fetchedAt": "2026-09-10T16:15:46+00:00",
    "date": "2026-09-10",
    "source": "ECB",
    "currencies": ["AUD","BRL","...","ZAR"]
  },
  "EUR": { "EUR": 1, "USD": 1.1616, "...": 0 },
  "USD": { "EUR": 0.86088154, "USD": 1, "...": 0 }
}
```

Verified against the live CDN on 2026-09-10; `test/support/fixtures/fx-rates.json`
is the capture that reading is taken from, kept whole rather than reduced to the
row the app reads.

The Worker materialises the full base→quote matrix so the app does not
have to invert rates. Three properties the client depends on:

- **`_meta.currencies` lists 30 codes and the matrix is 30 × 30.** Every code
  appears both as a base and as a quote of every base, so a conversion is one
  lookup and never a walk through a base currency.
- **An identity rate is the integer `1`**, not `1.0`. A row is therefore `num`
  and a client that casts to `double` throws on the diagonal.
- **`_meta.fetchedAt` is the only field the client treats as required.** It is
  what dates the rate on screen, and a rate whose age cannot be stated is worse
  than an absent one.

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
    "sources": ["BTCNodes.io", "Mempool.space"]
  },
  "fullNodes": { "count": 17234, "percentChange24h": 0.21, "trend": "stable" },
  "miningPools": [
    { "name": "Foundry USA", "hashratePercent": 28.4, "blockCount": 41, "alert": false }
  ],
  "poolConcentrationAlert": false,
  "aggregatedHealth": "good"
}
```

`fullNodes` is always present as an object, never dropped: when the node
census cannot be read it is `{ "count": null, "percentChange24h": null,
"trend": "unknown" }`, so the client keeps one code path. `trend` is one
of `up`, `down`, `stable`, `unknown`; `unknown` also covers a count that
arrived without a usable 24h reference point.

`aggregatedHealth` is one of `good`, `warning`, `critical`, `unknown` —
and `unknown` is **not** a fourth step on the severity scale. It means
one of the two dimensions had no reading, so the reassuring answer cannot
honestly be given. The verdict of the dimension that did arrive still
wins: a pool share above 40 % reads `critical` whether or not the node
count came in. A consumer must never render `unknown` as "not bad".

## Direct live calls

```
GET https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT
GET https://mempool.space/api/v1/fees/recommended
GET https://mempool.space/api/v1/mining/hashrate/3d
GET https://mempool.space/api/v1/difficulty-adjustment
GET https://api.alternative.me/fng/?limit=30
```

The app converts client-side: `price_local = price_usd ×
fx_rates["USD"][selected_currency]`. One document serves every currency, so
changing the selection is immediate and costs no request — the fetch is
governed by the cache below, not by the picker.

## Hive cache strategy

| Hive key | Content | TTL |
|---|---|---|
| `settings` | language, currency, theme, news languages | persistent |
| `cache_market` | last `market.json` | 15 min |
| `cache_history_{range}` | last `history-{range}.json` | 15 min |
| `cache_fx_rates` | last `fx-rates.json` | 3 h |
| `cache_news_{lang}` | last `news-{lang}.json` | 15 min |
| `cache_network_health` | last `network-health.json` | 24 h |
| `cache_feargreed` | last F&G value | 1 h |

The history TTL is not range-dependent, although it reads as though it
should be. `cron-history` writes all five range documents on the same
fifteen-minute run, so a longer TTL for the long ranges would not save a
stale-free request — it would serve `1Y` as current while a newer copy of
it sat on the CDN. The span a document covers and the rate it is rewritten
at are different things.

The FX TTL is the one that does **not** follow its producer's cadence, and
deliberately. Everywhere else the two coincide: a document rewritten every
fifteen minutes is asked for every fifteen minutes, and a copy is never more
than one run behind. `cron-fx-rates` runs once a day at 16:15 UTC, and there a
matching TTL comes apart — a copy taken at 16:00 would be held until 16:00 the
next day and would miss the rate published fifteen minutes after it was stored,
by almost a full day. Three hours bounds that miss to part of an afternoon, at
a cost of at most eight requests a day for an 18 kB document, without making
the cache reason about the publication time. It is not the staleness threshold:
that one asks whether the ECB is still current and is four days.

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
