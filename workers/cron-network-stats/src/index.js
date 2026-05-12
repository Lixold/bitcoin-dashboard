// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: Bitcoin network-health snapshot.
//
// Replaces scripts/fetch_network_stats.py. Pulls two free, no-key public
// sources and writes a single JSON snapshot to R2:
//
//   Bitnodes.io      — reachable full-node count + 24h trend
//   Mempool.space    — mining-pool block share over the last 24 h
//
// The aggregated `aggregatedHealth` label combines both signals into a
// single indicator the dashboard surfaces under "Netzwerk-Gesundheit":
//
//   good      stable/growing node count AND no pool > 30 %
//   warning   shrinking node count (<5 %)  OR  largest pool 30–40 %
//   critical  shrinking node count >5 %    OR  largest pool > 40 %
//
// Per-source isolation: if Bitnodes fails we still ship mining-pool data
// (and vice versa). The Worker only throws when both upstreams fail —
// the previous network-health.json on R2 then remains as fallback.

const BITNODES_SNAPSHOTS_URL = "https://bitnodes.io/api/v1/snapshots/";
const MEMPOOL_POOLS_24H_URL = "https://mempool.space/api/v1/mining/pools/24h";

// === Tunables — kept in sync with scripts/fetch_network_stats.py ===========

// Bitnodes snapshots are typically ~10 min apart; 100 entries cover ~16 h.
// To reach back ~24 h we paginate up to MAX_PAGES, with an early-stop once
// we've crossed the 24h-ago target.
const BITNODES_PAGE_SIZE = 100;
const BITNODES_MAX_PAGES = 5;

// How far the historical snapshot may sit from the exact 24h-ago target
// before we treat the trend as unknown rather than report a misleading
// value computed against, say, a 6h-old data point.
const TREND_TARGET_TOLERANCE_SECONDS = 6 * 3600;

// Symmetric dead band on percent-change before flipping the textual trend
// label. Avoids flapping between "up" and "down" when the network is
// essentially flat day-to-day.
const TREND_FLAT_THRESHOLD_PCT = 0.5;

// Pool-share thresholds. 40 % is the long-standing community line for
// "majority threat watch"; 30 % is a softer "concentration concern".
const POOL_ALERT_PCT = 40.0;
const POOL_WARNING_PCT = 30.0;

// Daily node-count drop > 5 % is highly unusual and worth surfacing red.
const NODE_CRITICAL_DROP_PCT = -5.0;

// Top N pools to include in the output. Mempool currently lists ~15; the
// long tail is mostly "Unknown" and small operators the dashboard does
// not need to render.
const TOP_POOLS = 10;

const NETWORK_CACHE_CONTROL = "public, max-age=86400";

// === Helpers ==============================================================

function isoUtcSeconds(d) {
  return d.toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

function trendLabel(pct) {
  if (pct > TREND_FLAT_THRESHOLD_PCT) return "up";
  if (pct < -TREND_FLAT_THRESHOLD_PCT) return "down";
  return "stable";
}

const FETCH_HEADERS = {
  Accept: "application/json",
  "User-Agent":
    "Mozilla/5.0 (compatible; BitcoinDashboardBot/1.0; +https://bitcoin-dashboard.app)",
};

// Retries once after a short delay on transient 5xx responses. A single
// retry is enough to survive brief Cloudflare / origin hiccups (e.g. HTTP
// 530 "origin unreachable") without burning significant wall-clock time.
async function getJson(url, retries = 1) {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url, { headers: FETCH_HEADERS });
    if (res.ok) return res.json();

    const isTransient = res.status >= 500;
    if (isTransient && attempt < retries) {
      console.warn(`GET ${url} → HTTP ${res.status}, retrying (${attempt + 1}/${retries})…`);
      await new Promise((r) => setTimeout(r, 2000));
      continue;
    }
    throw new Error(`GET ${url} failed: HTTP ${res.status}`);
  }
}

// === Bitnodes: full-node count + 24h trend ================================

async function fetchFullNodes() {
  // Walk pages until we've crossed the 24h-ago timestamp or hit MAX_PAGES.
  // Bitnodes' `next` URL already encodes page_size, so after the first
  // request we hand control to that URL verbatim.
  const snapshots = [];
  let url = `${BITNODES_SNAPSHOTS_URL}?page_size=${BITNODES_PAGE_SIZE}`;
  let pagesFetched = 0;

  const targetTsInitial = Math.floor(Date.now() / 1000) - 24 * 3600;

  while (url && pagesFetched < BITNODES_MAX_PAGES) {
    const raw = await getJson(url);
    const results = Array.isArray(raw.results) ? raw.results : [];
    for (const r of results) snapshots.push(r);
    pagesFetched += 1;

    const last = results[results.length - 1];
    if (last && (last.timestamp || 0) <= targetTsInitial) break;

    url = raw.next || null;
  }

  if (snapshots.length === 0) {
    throw new Error("Bitnodes returned no snapshots");
  }

  const latest = snapshots[0];
  const latestCount = latest.total_nodes;
  const latestTs = latest.timestamp;
  if (latestCount == null || latestTs == null) {
    throw new Error(
      `Bitnodes latest snapshot missing fields: ${JSON.stringify(latest)}`,
    );
  }

  console.log(
    `Bitnodes: ${snapshots.length} snapshots over ${pagesFetched} page(s), ` +
      `latest count=${latestCount}`,
  );

  if (snapshots.length < 2) {
    return { count: latestCount, percentChange24h: null, trend: "unknown" };
  }

  // Re-anchor the target on the latest snapshot's actual timestamp rather
  // than wall clock — the latest may itself be a few minutes in the past,
  // and we want a consistent 24h window relative to it.
  const targetTs = latestTs - 24 * 3600;
  let closest = snapshots[1];
  let closestDelta = Math.abs((closest.timestamp || 0) - targetTs);
  for (let i = 2; i < snapshots.length; i++) {
    const d = Math.abs((snapshots[i].timestamp || 0) - targetTs);
    if (d < closestDelta) {
      closest = snapshots[i];
      closestDelta = d;
    }
  }

  if (closestDelta > TREND_TARGET_TOLERANCE_SECONDS) {
    console.warn(
      `Bitnodes 24h reference is ${closestDelta} s off target — trend=unknown`,
    );
    return { count: latestCount, percentChange24h: null, trend: "unknown" };
  }

  const prevCount = closest.total_nodes;
  if (!prevCount || prevCount <= 0) {
    return { count: latestCount, percentChange24h: null, trend: "unknown" };
  }

  const pct = Math.round(((latestCount - prevCount) / prevCount) * 100 * 100) / 100;
  return { count: latestCount, percentChange24h: pct, trend: trendLabel(pct) };
}

// === Mempool.space: mining-pool concentration =============================

async function fetchMiningPools() {
  // Hashrate share is derived from blockCount / total blockCount — the same
  // way Mempool.space themselves render the chart. The upstream's
  // `avgMatchRate` field is consensus-match telemetry, NOT a hashrate share,
  // so we do not use it here.
  const raw = await getJson(MEMPOOL_POOLS_24H_URL);
  const poolsIn = Array.isArray(raw.pools) ? raw.pools : [];
  let totalBlocks = raw.blockCount;
  if (!totalBlocks) {
    totalBlocks = poolsIn.reduce((acc, p) => acc + (p.blockCount || 0), 0);
  }

  if (poolsIn.length === 0 || totalBlocks <= 0) {
    throw new Error(
      `Mempool returned no usable pool data (pools=${poolsIn.length}, ` +
        `blockCount=${totalBlocks})`,
    );
  }

  const sorted = poolsIn
    .slice()
    .sort((a, b) => (b.blockCount || 0) - (a.blockCount || 0));

  const out = [];
  for (const p of sorted.slice(0, TOP_POOLS)) {
    const blockCount = p.blockCount || 0;
    const share = Math.round((blockCount / totalBlocks) * 100 * 100) / 100;
    out.push({
      name: p.name || "Unknown",
      hashratePercent: share,
      blockCount,
      alert: share > POOL_ALERT_PCT,
    });
  }

  console.log(
    `Mempool: ${poolsIn.length} pools, total ${totalBlocks} blocks in 24h, ` +
      `top share ${out[0].hashratePercent} % (${out[0].name})`,
  );
  return out;
}

// === Aggregated health signal =============================================

function aggregateHealth(nodesPctChange, maxPoolPct) {
  let critical = false;
  let warning = false;

  if (nodesPctChange !== null && nodesPctChange !== undefined) {
    if (nodesPctChange < NODE_CRITICAL_DROP_PCT) critical = true;
    else if (nodesPctChange < 0) warning = true;
  }

  if (maxPoolPct !== null && maxPoolPct !== undefined) {
    if (maxPoolPct > POOL_ALERT_PCT) critical = true;
    else if (maxPoolPct >= POOL_WARNING_PCT) warning = true;
  }

  if (critical) return "critical";
  if (warning) return "warning";
  return "good";
}

// === Entry point ==========================================================

async function runAll(env) {
  // Independent try/catch per source — same isolation pattern as the
  // Python original. A 5xx burst on one upstream must not blank out the
  // dashboard's other dimension.
  let fullNodes = null;
  let miningPools = null;

  try {
    console.log("Fetching Bitnodes snapshots");
    fullNodes = await fetchFullNodes();
  } catch (exc) {
    console.error("Bitnodes fetch failed:", exc);
  }

  try {
    console.log("Fetching Mempool.space mining pools (24h)");
    miningPools = await fetchMiningPools();
  } catch (exc) {
    console.error("Mempool fetch failed:", exc);
  }

  if (fullNodes === null && miningPools === null) {
    throw new Error(
      "Both upstreams failed — previous network-health.json on R2 remains",
    );
  }

  // Fixed-shape payload (null leaves rather than null wrappers) keeps the
  // Flutter consumer's code path uniform — no `if (data != null)` branch
  // around fullNodes vs miningPools.
  const fullNodesPayload = fullNodes ?? {
    count: null,
    percentChange24h: null,
    trend: "unknown",
  };
  const poolsPayload = miningPools ?? [];

  const maxPoolPct =
    poolsPayload.length > 0
      ? poolsPayload.reduce(
          (acc, p) => (p.hashratePercent > acc ? p.hashratePercent : acc),
          poolsPayload[0].hashratePercent,
        )
      : null;
  const poolAlert = maxPoolPct !== null && maxPoolPct > POOL_ALERT_PCT;

  const health = aggregateHealth(
    fullNodesPayload.percentChange24h ?? null,
    maxPoolPct,
  );

  const now = new Date();
  const payload = {
    _meta: {
      fetchedAt: isoUtcSeconds(now),
      date: now.toISOString().slice(0, 10),
      sources: ["Bitnodes.io", "Mempool.space"],
    },
    fullNodes: fullNodesPayload,
    miningPools: poolsPayload,
    poolConcentrationAlert: poolAlert,
    aggregatedHealth: health,
  };

  await env.BUCKET.put("data/network-health.json", JSON.stringify(payload), {
    httpMetadata: {
      contentType: "application/json",
      cacheControl: NETWORK_CACHE_CONTROL,
    },
  });

  console.log(
    `Uploaded network-health.json: nodes=${fullNodes ? "ok" : "missing"} ` +
      `pools=${poolsPayload.length} health=${health}`,
  );
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runAll(env));
  },
};
