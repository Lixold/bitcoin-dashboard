// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: Bitcoin price history + market snapshot from CoinGecko.
//
// Replaces scripts/fetch_history.py. The data shapes, range mapping, and R2
// output keys are kept identical so the Flutter app does not need any change.
//
// Outputs (R2 bucket bitcoin-dashboard-data, keys match what the app reads):
//   data/history-1D.json, data/history-1W.json, data/history-1M.json,
//   data/history-3M.json, data/history-1Y.json
//   data/market.json
//
// History timestamps are milliseconds since the Unix epoch (UTC), passed
// through from CoinGecko unmodified. See ADR-0005 and mapPriceSeries below.
//
// CoinGecko Demo tier — 30 req/min, no key required, but COINGECKO_API_KEY
// (if set as a Worker secret) raises the limit and is sent as the
// `x-cg-demo-api-key` header.

import { getJson, isoUtcSeconds, putJson } from "../../_shared/lib.js";

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";

// Range -> CoinGecko `days` parameter. The Demo tier rejects anything beyond
// 365 days, so no "ALL" entry here (matches the Python script).
const RANGE_TO_DAYS = {
  "1D": "1",
  "1W": "7",
  "1M": "30",
  "3M": "90",
  "1Y": "365",
};

// CDN cache for the 15-min files. Matches the cron cadence so a CDN miss is
// at most one cron tick stale.
const HISTORY_CACHE_CONTROL = "public, max-age=900";

function authHeaders(env) {
  // Demo tier uses `x-cg-demo-api-key`. Omit entirely when no key is set so
  // CoinGecko falls back to the public Demo rate limit instead of 401'ing
  // on an empty string.
  return env.COINGECKO_API_KEY
    ? { "x-cg-demo-api-key": env.COINGECKO_API_KEY }
    : {};
}

/**
 * Coerce a CoinGecko field to a finite number, or `null` if it is not one.
 *
 * Deliberately narrower than bare `Number()`: that maps `null`, `""` and `[]`
 * to `0`, which would turn a missing price into a real-looking 0 USD point in
 * the chart. Only actual numbers and numeric strings are accepted.
 */
function toFiniteNumber(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string" && value.trim() !== "") {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

/**
 * Flatten CoinGecko's `[[ts_ms, price], ...]` pairs into the two parallel
 * arrays the client contract specifies (see ADR-0005).
 *
 * **Timestamps are emitted verbatim as milliseconds since the Unix epoch,
 * UTC** — the unit CoinGecko itself returns. Do not coerce them with `| 0`,
 * `>>> 0`, or any other bitwise operator: JavaScript converts to a signed
 * 32-bit integer first, and a millisecond epoch (~1.79e12) wraps. That bug
 * shipped corrupted history for every range — timestamps decoded to 2006-2009
 * and the 3M and 1Y series were no longer monotonic because the wraparound
 * fell inside the array.
 *
 * Pairs whose timestamp or price is not a finite number are dropped, so the
 * two arrays stay index-aligned and no `null` ever reaches the payload.
 */
export function mapPriceSeries(rawPrices) {
  const pairs = Array.isArray(rawPrices) ? rawPrices : [];
  const timestamps = [];
  const prices = [];

  for (const pair of pairs) {
    if (!Array.isArray(pair)) continue;
    const ts = toFiniteNumber(pair[0]);
    const price = toFiniteNumber(pair[1]);
    if (ts === null || price === null) continue;
    timestamps.push(ts);
    prices.push(price);
  }

  return { timestamps, prices };
}

async function fetchHistory(rangeKey, env) {
  const days = RANGE_TO_DAYS[rangeKey];
  const url =
    `${COINGECKO_BASE}/coins/bitcoin/market_chart` +
    `?vs_currency=usd&days=${days}`;
  const raw = await getJson(url, authHeaders(env));

  const { timestamps, prices } = mapPriceSeries(raw.prices);

  return {
    range: rangeKey,
    currency: "usd",
    fetchedAt: isoUtcSeconds(new Date()),
    timestamps,
    prices,
  };
}

async function fetchMarket(env) {
  // /coins/bitcoin doesn't expose BTC dominance, so we make one extra /global
  // call. Both run in parallel — total of two requests for the market block.
  const coinUrl =
    `${COINGECKO_BASE}/coins/bitcoin` +
    "?localization=false&tickers=false&community_data=false" +
    "&developer_data=false&sparkline=false";
  const globalUrl = `${COINGECKO_BASE}/global`;

  const [coin, glob] = await Promise.all([
    getJson(coinUrl, authHeaders(env)),
    getJson(globalUrl, authHeaders(env)),
  ]);

  const md = coin.market_data || {};
  const marketCapPct =
    (glob.data && glob.data.market_cap_percentage) || {};

  return {
    fetchedAt: isoUtcSeconds(new Date()),
    currency: "usd",
    marketCap: md.market_cap ? md.market_cap.usd : null,
    volume24h: md.total_volume ? md.total_volume.usd : null,
    ath: md.ath ? md.ath.usd : null,
    athDate: md.ath_date ? md.ath_date.usd : null,
    atl: md.atl ? md.atl.usd : null,
    atlDate: md.atl_date ? md.atl_date.usd : null,
    circulatingSupply: md.circulating_supply ?? null,
    totalSupply: md.total_supply ?? null,
    maxSupply: md.max_supply ?? null,
    btcDominance: marketCapPct.btc ?? null,
  };
}

async function runAll(env) {
  // Per-task isolation — a transient CoinGecko hiccup on one range must not
  // erase the data we already have for the others. Each task is settled
  // independently; the Worker only throws when literally nothing succeeded.
  const tasks = [];

  for (const rangeKey of Object.keys(RANGE_TO_DAYS)) {
    tasks.push(
      (async () => {
        const history = await fetchHistory(rangeKey, env);
        await putJson(
          env,
          `data/history-${rangeKey}.json`,
          history,
          HISTORY_CACHE_CONTROL,
        );
        return `history-${rangeKey}`;
      })(),
    );
  }

  tasks.push(
    (async () => {
      const market = await fetchMarket(env);
      await putJson(env, "data/market.json", market, HISTORY_CACHE_CONTROL);
      return "market";
    })(),
  );

  const results = await Promise.allSettled(tasks);

  let successes = 0;
  const failures = [];
  results.forEach((r, i) => {
    if (r.status === "fulfilled") {
      successes += 1;
    } else {
      failures.push(r.reason && r.reason.message ? r.reason.message : String(r.reason));
      console.error(`Task ${i} failed:`, r.reason);
    }
  });

  console.log(
    `history Worker done. successes=${successes} failures=${failures.length}`,
  );
  if (failures.length) {
    console.warn(`Failed tasks: ${failures.join("; ")}`);
  }

  if (successes === 0) {
    throw new Error("All history/market tasks failed");
  }
}

export default {
  // The `scheduled` handler is invoked by the cron trigger declared in
  // wrangler.toml. waitUntil keeps the Worker alive past the synchronous
  // return so all R2 writes settle even on slow upstreams.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runAll(env));
  },
};
