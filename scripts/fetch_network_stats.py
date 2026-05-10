#!/usr/bin/env python3
# ARCHIVED: replaced by Cloudflare Worker in workers/cron-network-stats/
# Kept as reference for data shapes and business logic.
# MIT License
#
# Copyright (c) 2026 Daniel Nagel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, subject to the conditions in the LICENSE
# file in the project root.
"""
Fetch Bitcoin network-health metrics from two public sources and upload
a single JSON snapshot to Cloudflare R2 served via the CDN.

Output (under the bucket root, key matches the path the Flutter app reads):
    data/network-health.json

Sources (both free, no API key):
    Bitnodes.io       — reachable Bitcoin full-node count and 24h trend.
                         GET https://bitnodes.io/api/v1/snapshots/
    Mempool.space     — mining-pool block share over the last 24 h.
                         GET https://mempool.space/api/v1/mining/pools/24h

The aggregated `aggregatedHealth` field combines both signals into a single
indicator the dashboard surfaces under "These 4 — Netzwerk-Gesundheit":

    "good"      stable/growing node count AND no pool > 30 %
    "warning"   shrinking node count (<5 %)  OR  largest pool 30–40 %
    "critical"  shrinking node count >5 %    OR  largest pool > 40 %

Per-source errors are isolated: if Bitnodes is down we still ship
mining-pool data (and vice versa). The script exits non-zero only when
*both* sources fail — the previous file on R2 then remains as fallback.

This script is intended to run as a GitHub Actions cron job once per day;
see `.github/workflows/fetch_network_stats.yml`.
"""

from __future__ import annotations

import logging
import sys
import time
from datetime import datetime, timezone
from typing import Any, Optional

# Local utils — `scripts/` is on the import path when run from the repo
# root (PYTHONPATH=scripts in the workflow), so `from utils...` works.
from utils.http_client import get_json
from utils.r2_client import upload_json

# === Endpoints ==============================================================

BITNODES_SNAPSHOTS_URL = "https://bitnodes.io/api/v1/snapshots/"
MEMPOOL_POOLS_24H_URL = "https://mempool.space/api/v1/mining/pools/24h"


# === Tunables ===============================================================

# Bitnodes snapshots are typically taken every ~10 min; 100 entries cover
# ~16 h. To reach back ~24 h we paginate up to MAX_PAGES — caps runaway
# walks if the API returns small pages.
BITNODES_PAGE_SIZE = 100
BITNODES_MAX_PAGES = 5

# How far the historical snapshot may sit from the exact 24h-ago target
# before we treat the trend as unknown rather than report a misleading
# value computed against, say, a 6h-old data point.
TREND_TARGET_TOLERANCE_SECONDS = 6 * 3600

# Symmetric dead band on the percent-change before flipping the textual
# trend label. Avoids flapping between "up" and "down" when the network
# is essentially flat day-to-day.
TREND_FLAT_THRESHOLD_PCT = 0.5

# Pool-share thresholds for the network-health alert. The 40 % mark is
# the long-standing community line for "majority threat watch"; the
# 30 % mark is a softer "concentration concern".
POOL_ALERT_PCT = 40.0
POOL_WARNING_PCT = 30.0

# Critical threshold for daily node-count drop. A single-day drop > 5 %
# is highly unusual and worth surfacing red, not amber.
NODE_CRITICAL_DROP_PCT = -5.0

# How many top pools to include in the output. Mempool currently lists
# ~15; the long tail is mostly "Unknown" and small operators that the
# dashboard does not need to render.
TOP_POOLS = 10

# Network metrics change at most once per day; cache aggressively so the
# CDN does not hammer R2 for unchanged content.
NETWORK_CACHE_CONTROL = "public, max-age=86400"

log = logging.getLogger(__name__)


# === Bitnodes: full-node count + 24h trend ==================================


def _trend_label(percent_change: float) -> str:
    """Map a percent change to one of {up, stable, down}."""
    if percent_change > TREND_FLAT_THRESHOLD_PCT:
        return "up"
    if percent_change < -TREND_FLAT_THRESHOLD_PCT:
        return "down"
    return "stable"


def fetch_full_nodes() -> dict[str, Any]:
    """
    Fetch the latest Bitnodes snapshot and a snapshot from ~24 h earlier,
    return count + percent-change + textual trend label.

    Always returns a dict shaped like the output schema, with `None` /
    "unknown" values when a 24h comparison cannot be made (single
    snapshot available, or the closest historical snapshot is too far
    from the 24h-ago target). Never returns None for the wrapper —
    raises only on hard upstream failure (HTTP error, malformed JSON).
    """
    snapshots: list[dict[str, Any]] = []
    url: Optional[str] = BITNODES_SNAPSHOTS_URL
    params: Optional[dict[str, Any]] = {"page_size": BITNODES_PAGE_SIZE}
    pages_fetched = 0

    target_ts = int(time.time()) - 24 * 3600

    while url and pages_fetched < BITNODES_MAX_PAGES:
        raw = get_json(url, params=params)
        results = raw.get("results") or []
        snapshots.extend(results)
        pages_fetched += 1

        # Stop early as soon as we have a snapshot at or before the
        # 24h-ago target — paginating further is wasted bandwidth.
        if results and results[-1].get("timestamp", 0) <= target_ts:
            break

        url = raw.get("next")
        # Bitnodes' `next` URL already encodes page_size; clearing
        # `params` avoids accidentally double-appending.
        params = None

    if not snapshots:
        raise ValueError("Bitnodes returned no snapshots")

    latest = snapshots[0]
    latest_count = latest.get("total_nodes")
    latest_ts = latest.get("timestamp")

    if latest_count is None or latest_ts is None:
        raise ValueError(f"Bitnodes latest snapshot missing fields: {latest!r}")

    log.info(
        "Bitnodes: %d snapshots over %d page(s), latest count=%d",
        len(snapshots),
        pages_fetched,
        latest_count,
    )

    # Need at least two snapshots to compute any trend at all.
    if len(snapshots) < 2:
        return {
            "count": latest_count,
            "percentChange24h": None,
            "trend": "unknown",
        }

    # Re-anchor the target on the latest snapshot's actual timestamp
    # rather than wall clock — the latest may itself be a few minutes
    # in the past, and we want a consistent 24h window relative to it.
    target_ts = latest_ts - 24 * 3600
    closest = min(
        snapshots[1:],
        key=lambda s: abs((s.get("timestamp") or 0) - target_ts),
    )
    delta = abs((closest.get("timestamp") or 0) - target_ts)

    if delta > TREND_TARGET_TOLERANCE_SECONDS:
        log.warning(
            "Bitnodes 24h reference is %d s off target — reporting trend=unknown",
            delta,
        )
        return {
            "count": latest_count,
            "percentChange24h": None,
            "trend": "unknown",
        }

    prev_count = closest.get("total_nodes")
    if not prev_count or prev_count <= 0:
        return {
            "count": latest_count,
            "percentChange24h": None,
            "trend": "unknown",
        }

    pct = round((latest_count - prev_count) / prev_count * 100, 2)
    return {
        "count": latest_count,
        "percentChange24h": pct,
        "trend": _trend_label(pct),
    }


# === Mempool.space: mining-pool concentration ===============================


def fetch_mining_pools() -> list[dict[str, Any]]:
    """
    Fetch the 24h mining-pool distribution and return the top N pools as
    list of dicts shaped to the output schema.

    Hashrate share is derived from blockCount / total blockCount (the
    exact same way Mempool.space themselves render the chart). The
    upstream's `avgMatchRate` field is consensus-match telemetry, NOT
    a hashrate share, so we don't use it here.
    """
    raw = get_json(MEMPOOL_POOLS_24H_URL)
    pools_in = raw.get("pools") or []
    total_blocks = raw.get("blockCount") or sum(
        (p.get("blockCount", 0) or 0) for p in pools_in
    )

    if not pools_in or total_blocks <= 0:
        raise ValueError(
            f"Mempool returned no usable pool data (pools={len(pools_in)}, "
            f"blockCount={total_blocks})"
        )

    pools_sorted = sorted(
        pools_in, key=lambda p: p.get("blockCount", 0) or 0, reverse=True
    )

    out: list[dict[str, Any]] = []
    for p in pools_sorted[:TOP_POOLS]:
        block_count = p.get("blockCount", 0) or 0
        share = round(block_count / total_blocks * 100, 2)
        out.append({
            "name": p.get("name") or "Unknown",
            "hashratePercent": share,
            "blockCount": block_count,
            "alert": share > POOL_ALERT_PCT,
        })

    log.info(
        "Mempool: %d pools, total %d blocks in 24h, top share %.2f %% (%s)",
        len(pools_in),
        total_blocks,
        out[0]["hashratePercent"],
        out[0]["name"],
    )
    return out


# === Aggregated health signal ===============================================


def aggregate_health(
    nodes_pct_change: Optional[float],
    max_pool_pct: Optional[float],
) -> str:
    """
    Combine the two dimensions into a single label.

    Either input may be None when its source failed; the function falls
    back to whichever dimension is still available. With both None we
    would not be uploading at all (see main()), but the function still
    returns "good" in that pathological case to keep the type contract
    simple — callers can rely on the return always being a known label.
    """
    is_critical = False
    is_warning = False

    if nodes_pct_change is not None:
        if nodes_pct_change < NODE_CRITICAL_DROP_PCT:
            is_critical = True
        elif nodes_pct_change < 0:
            is_warning = True

    if max_pool_pct is not None:
        if max_pool_pct > POOL_ALERT_PCT:
            is_critical = True
        elif max_pool_pct >= POOL_WARNING_PCT:
            is_warning = True

    if is_critical:
        return "critical"
    if is_warning:
        return "warning"
    return "good"


# === Entry point ============================================================


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    full_nodes: Optional[dict[str, Any]] = None
    mining_pools: Optional[list[dict[str, Any]]] = None

    # Independent try/except per source — same isolation pattern as
    # fetch_history.py and fetch_news.py. A 5xx burst on one upstream
    # should not blank out the dashboard's other dimension.
    try:
        log.info("Fetching Bitnodes snapshots")
        full_nodes = fetch_full_nodes()
    except Exception as exc:  # noqa: BLE001 — log + continue
        log.error("Bitnodes fetch failed: %s", exc, exc_info=True)

    try:
        log.info("Fetching Mempool.space mining pools (24h)")
        mining_pools = fetch_mining_pools()
    except Exception as exc:  # noqa: BLE001
        log.error("Mempool fetch failed: %s", exc, exc_info=True)

    if full_nodes is None and mining_pools is None:
        log.error(
            "Both upstreams failed — previous network-health.json on R2 "
            "remains as fallback"
        )
        return 1

    # Materialise the schema-shaped wrapper around whatever did succeed.
    # Using fixed shapes (with null leaves) instead of nullable wrappers
    # keeps the Flutter consumer's code path uniform — no `if (data
    # != null)` branch around fullNodes vs miningPools.
    full_nodes_payload = full_nodes if full_nodes is not None else {
        "count": None,
        "percentChange24h": None,
        "trend": "unknown",
    }
    pools_payload = mining_pools if mining_pools is not None else []

    max_pool_pct = (
        max((p["hashratePercent"] for p in pools_payload), default=None)
        if pools_payload
        else None
    )
    pool_alert = max_pool_pct is not None and max_pool_pct > POOL_ALERT_PCT

    health = aggregate_health(
        full_nodes_payload.get("percentChange24h"), max_pool_pct
    )

    now = datetime.now(timezone.utc)
    payload = {
        "_meta": {
            "fetchedAt": now.isoformat(timespec="seconds"),
            "date": now.strftime("%Y-%m-%d"),
            "sources": ["Bitnodes.io", "Mempool.space"],
        },
        "fullNodes": full_nodes_payload,
        "miningPools": pools_payload,
        "poolConcentrationAlert": pool_alert,
        "aggregatedHealth": health,
    }

    upload_json(
        "data/network-health.json",
        payload,
        cache_control=NETWORK_CACHE_CONTROL,
    )
    log.info(
        "Uploaded network-health.json: nodes=%s pools=%d health=%s",
        "ok" if full_nodes is not None else "missing",
        len(pools_payload),
        health,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
