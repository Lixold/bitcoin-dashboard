// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: Bitcoin network-health snapshot.
//
// Replaces scripts/fetch_network_stats.py. Pulls two free, no-key public
// sources and writes a single JSON snapshot to R2:
//
//   BTCNodes.io      — reachable full-node count + 24h trend
//   Mempool.space    — mining-pool block share over the last 24 h
//
// The aggregated `aggregatedHealth` label combines both signals into a
// single indicator the dashboard surfaces under "Netzwerk-Gesundheit":
//
//   good      stable/growing node count AND no pool > 30 %
//   warning   shrinking node count (<5 %)  OR  largest pool 30–40 %
//   critical  shrinking node count >5 %    OR  largest pool > 40 %
//   unknown   one dimension has no reading and the other sees nothing
//             wrong — "good" would claim more than we know
//
// Per-source isolation: if one source fails we still ship the other's
// data. The Worker only throws when both upstreams fail — the previous
// network-health.json on R2 then remains as fallback. What isolation must
// not do is let half a picture read as a clean bill of health; that is
// what `unknown` is for.

import { getJson, isoUtcSeconds, putJson, roundTo } from "../../_shared/lib.js";

// The node census moved in September 2026: bitnodes.io answers 302 to
// btcnodes.io, which ignores the old `page_size` parameter in favour of
// `limit` and returns `next` as a path rather than an absolute URL. We
// address the new host directly — following a redirect would make the
// pipeline quietly dependent on someone else's routing, and the host has
// to be named for the privacy note (#38) either way.
const BTCNODES_SNAPSHOTS_URL = "https://btcnodes.io/api/v1/snapshots/";
const MEMPOOL_POOLS_24H_URL = "https://mempool.space/api/v1/mining/pools/24h";

// === Tunables =============================================================

// Snapshots are ~25 min apart: measured 2026-09-13, 100 entries spanned
// 44.3 h. One request therefore covers the 24 h this function needs with
// ~1.8x headroom and there is no pagination to do. Should that headroom
// fall below ~1.3x, the 24h reference drifts out of the tolerance below
// and the trend degrades to "unknown" with the count intact — the honest
// failure, and the signal to page again after all.
const BTCNODES_LIMIT = 100;

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

export function trendLabel(pct) {
  if (pct > TREND_FLAT_THRESHOLD_PCT) return "up";
  if (pct < -TREND_FLAT_THRESHOLD_PCT) return "down";
  return "stable";
}

// === BTC Nodes: full-node count + 24h trend ===============================

/**
 * Derive the full-node reading from one page of BTC Nodes snapshots.
 *
 * Pure on purpose: the fetch is what CI cannot exercise, the arithmetic
 * here is where the reading is decided. `snapshots` may arrive in any
 * order — the upstream serves newest first, but that is its convention
 * rather than a promise, and an unwritten convention of this upstream is
 * exactly what broke in #29.
 */
export function fullNodesFromSnapshots(snapshots) {
  const ordered = snapshots
    .filter((s) => s && s.timestamp != null && s.total_nodes != null)
    .sort((a, b) => b.timestamp - a.timestamp);

  if (ordered.length === 0) {
    throw new Error("BTC Nodes returned no usable snapshots");
  }

  const latest = ordered[0];
  const latestCount = latest.total_nodes;
  const latestTs = latest.timestamp;
  const spanHours = roundTo(
    (latestTs - ordered[ordered.length - 1].timestamp) / 3600,
    1,
  );

  console.log(
    `BTC Nodes: ${ordered.length} snapshots spanning ${spanHours} h, ` +
      `latest count=${latestCount}`,
  );

  if (ordered.length < 2) {
    return { count: latestCount, percentChange24h: null, trend: "unknown" };
  }

  // Re-anchor the target on the latest snapshot's actual timestamp rather
  // than wall clock — the latest may itself be a few minutes in the past,
  // and we want a consistent 24h window relative to it.
  const targetTs = latestTs - 24 * 3600;
  let closest = ordered[1];
  let closestDelta = Math.abs(closest.timestamp - targetTs);
  for (let i = 2; i < ordered.length; i++) {
    const d = Math.abs(ordered[i].timestamp - targetTs);
    if (d < closestDelta) {
      closest = ordered[i];
      closestDelta = d;
    }
  }

  if (closestDelta > TREND_TARGET_TOLERANCE_SECONDS) {
    console.warn(
      `BTC Nodes 24h reference is ${closestDelta} s off target — trend=unknown`,
    );
    return { count: latestCount, percentChange24h: null, trend: "unknown" };
  }

  const prevCount = closest.total_nodes;
  if (prevCount <= 0) {
    return { count: latestCount, percentChange24h: null, trend: "unknown" };
  }

  const pct = roundTo(((latestCount - prevCount) / prevCount) * 100, 2);
  return { count: latestCount, percentChange24h: pct, trend: trendLabel(pct) };
}

async function fetchFullNodes() {
  const raw = await getJson(
    `${BTCNODES_SNAPSHOTS_URL}?limit=${BTCNODES_LIMIT}`,
  );
  return fullNodesFromSnapshots(Array.isArray(raw.results) ? raw.results : []);
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

/**
 * Combine both dimensions into the one label the payload carries.
 *
 * A null argument means that dimension has no reading — its source failed,
 * or it answered but the 24h reference sat outside tolerance. Only "good"
 * is a claim about the whole picture, so only "good" gives way to
 * "unknown": a pool share over the line stays "critical" whether or not
 * the node count arrived. "unknown" is therefore not a fourth severity
 * between "warning" and "good" — it means the question cannot be
 * answered, and the first consumer (#34) has to render it that way.
 */
export function aggregateHealth(nodesPctChange, maxPoolPct) {
  const hasNodes = nodesPctChange !== null && nodesPctChange !== undefined;
  const hasPools = maxPoolPct !== null && maxPoolPct !== undefined;

  let critical = false;
  let warning = false;

  if (hasNodes) {
    if (nodesPctChange < NODE_CRITICAL_DROP_PCT) critical = true;
    else if (nodesPctChange < 0) warning = true;
  }

  if (hasPools) {
    if (maxPoolPct > POOL_ALERT_PCT) critical = true;
    else if (maxPoolPct >= POOL_WARNING_PCT) warning = true;
  }

  if (critical) return "critical";
  if (warning) return "warning";
  if (!hasNodes || !hasPools) return "unknown";
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
    console.log("Fetching BTC Nodes snapshots");
    fullNodes = await fetchFullNodes();
  } catch (exc) {
    console.error("BTC Nodes fetch failed:", exc);
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
      sources: ["BTCNodes.io", "Mempool.space"],
    },
    fullNodes: fullNodesPayload,
    miningPools: poolsPayload,
    poolConcentrationAlert: poolAlert,
    aggregatedHealth: health,
  };

  await putJson(env, "data/network-health.json", payload, NETWORK_CACHE_CONTROL);

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
