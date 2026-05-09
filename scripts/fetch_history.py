#!/usr/bin/env python3
# MIT License
#
# Copyright (c) 2026 Daniel Nagel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, subject to the conditions in the LICENSE
# file in the project root.
"""
Fetch Bitcoin price history and market snapshot from CoinGecko, then upload
both to Cloudflare R2 as static JSON files served via the CDN.

Outputs (under the bucket root, keys match the paths the Flutter app reads):
    data/history-{range}.json   for range in {1D, 1W, 1M, 3M, 1Y, ALL}
    data/market.json            with marketCap, volume24h, ath, atl,
                                 circulatingSupply, btcDominance

CoinGecko endpoints used (Demo API tier — 30 req/min, no key required, but a
key raises the limit and is supplied via `COINGECKO_API_KEY`):
    /coins/bitcoin/market_chart?vs_currency=usd&days=N
    /coins/bitcoin?localization=false&tickers=false&community_data=false
                  &developer_data=false&sparkline=false
    /global                          (only for BTC dominance)

This script is intended to run as a GitHub Actions cron job every 15 minutes;
see `.github/workflows/fetch_history.yml`.
"""

from __future__ import annotations

import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any

# Local utils — `scripts/` is on the import path when run as a script from
# the repo root (see workflow), so `from utils...` imports work directly.
from utils.http_client import get_json
from utils.r2_client import upload_json

COINGECKO_BASE = "https://api.coingecko.com/api/v3"

# Mapping from the user-facing range names (used in the JSON file names and in
# the Flutter `historyProvider(range)`) to CoinGecko's `days` parameter.
#
# Note: an "ALL" range mapping to `days=max` would require the CoinGecko Pro
# tier — the Demo tier returns 401 for anything beyond 365 days. Long-term
# history will be backfilled from a different source (planned: one-off seed
# from Yahoo Finance + daily incremental update written to R2 directly).
RANGE_TO_DAYS: dict[str, str] = {
    "1D": "1",
    "1W": "7",
    "1M": "30",
    "3M": "90",
    "1Y": "365",
}

log = logging.getLogger(__name__)


def _coingecko_headers() -> dict[str, str]:
    """Return the auth header for the CoinGecko Demo API key, if present."""
    api_key = os.environ.get("COINGECKO_API_KEY")
    if api_key:
        # Demo tier uses `x-cg-demo-api-key`; Pro tier uses `x-cg-pro-api-key`.
        return {"x-cg-demo-api-key": api_key}
    return {}


def fetch_history(range_key: str) -> dict[str, Any]:
    """Fetch one price-history range from CoinGecko and shape it for the app."""
    days = RANGE_TO_DAYS[range_key]
    raw = get_json(
        f"{COINGECKO_BASE}/coins/bitcoin/market_chart",
        params={"vs_currency": "usd", "days": days},
        headers=_coingecko_headers(),
    )

    # CoinGecko returns parallel arrays of [timestamp_ms, value] pairs. We
    # flatten them to two arrays — timestamps and prices — to keep the JSON
    # small and trivial to plot with fl_chart.
    prices = raw.get("prices") or []
    timestamps = [int(point[0]) for point in prices]
    price_values = [float(point[1]) for point in prices]

    return {
        "range": range_key,
        "currency": "usd",
        "fetchedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "timestamps": timestamps,
        "prices": price_values,
    }


def fetch_market() -> dict[str, Any]:
    """Fetch the market snapshot (caps, ATH/ATL, supply, dominance)."""
    coin = get_json(
        f"{COINGECKO_BASE}/coins/bitcoin",
        params={
            "localization": "false",
            "tickers": "false",
            "community_data": "false",
            "developer_data": "false",
            "sparkline": "false",
        },
        headers=_coingecko_headers(),
    )

    # `/coins/bitcoin` does not expose BTC market dominance directly, so we
    # take it from the `/global` endpoint. One additional request, called
    # only once per run.
    glob = get_json(f"{COINGECKO_BASE}/global", headers=_coingecko_headers())
    market_cap_pct = (
        glob.get("data", {}).get("market_cap_percentage", {}) or {}
    )

    md = coin.get("market_data", {}) or {}

    return {
        "fetchedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "currency": "usd",
        "marketCap": (md.get("market_cap") or {}).get("usd"),
        "volume24h": (md.get("total_volume") or {}).get("usd"),
        "ath": (md.get("ath") or {}).get("usd"),
        "athDate": (md.get("ath_date") or {}).get("usd"),
        "atl": (md.get("atl") or {}).get("usd"),
        "atlDate": (md.get("atl_date") or {}).get("usd"),
        "circulatingSupply": md.get("circulating_supply"),
        "totalSupply": md.get("total_supply"),
        "maxSupply": md.get("max_supply"),
        "btcDominance": market_cap_pct.get("btc"),
    }


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    # Per-task error isolation: a transient upstream hiccup on one range
    # (e.g. a 5xx burst at CoinGecko, or a future endpoint deprecation)
    # should not lose the data we already have for the others. Each
    # fetch+upload runs in its own try/except. The HTTP retry policy in
    # `utils.http_client` has already done its work by the time we land
    # in the except branch, so logging is the right action here.
    successes = 0
    failures: list[str] = []

    # 1) History per range — independent CoinGecko calls. Kept sequential
    #    because the Demo tier is rate limited (30 req/min); 5 history
    #    calls + 2 market calls fit easily within that budget at 15 min.
    for range_key in RANGE_TO_DAYS:
        try:
            log.info("Fetching history range=%s", range_key)
            history = fetch_history(range_key)
            upload_json(f"data/history-{range_key}.json", history)
            successes += 1
        except Exception as exc:  # noqa: BLE001 — log everything, continue
            failures.append(f"history-{range_key}: {exc}")
            log.error("Range %s failed: %s", range_key, exc)

    # 2) Market snapshot
    try:
        log.info("Fetching market snapshot")
        market = fetch_market()
        upload_json("data/market.json", market)
        successes += 1
    except Exception as exc:  # noqa: BLE001
        failures.append(f"market: {exc}")
        log.error("Market snapshot failed: %s", exc)

    log.info("Done. successes=%d failures=%d", successes, len(failures))
    if failures:
        log.warning("Failed tasks: %s", "; ".join(failures))

    # Exit non-zero only if literally nothing succeeded — that signals a
    # real outage (credentials wrong, CoinGecko down) and should page us
    # via GitHub's failed-workflow notifications. Partial successes are
    # logged but treated as success so the next cron tick has a chance.
    return 0 if successes > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
