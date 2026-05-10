#!/usr/bin/env python3
# ARCHIVED: replaced by Cloudflare Worker in workers/cron-fx-rates/
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
Fetch the European Central Bank's daily foreign-exchange reference rates,
build a cross-rate matrix for ~30 currencies, and upload the result to
Cloudflare R2 as a static JSON file served via the CDN.

Output (under the bucket root, key matches the path the Flutter app reads):
    data/fx-rates.json     {
                              "_meta": {
                                  "fetchedAt": "...",      ISO-8601 UTC, runtime
                                  "date":      "YYYY-MM-DD", ECB publication date
                                  "source":    "ECB",
                                  "currencies": ["AUD", "BGN", ...]
                              },
                              "EUR": { "USD": 1.08, "CHF": 0.92, ..., "EUR": 1.0 },
                              "USD": { "EUR": 0.926, ..., "USD": 1.0 },
                              ...
                            }

ECB endpoint:
    https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml

Publication cadence: TARGET2 banking days, around 16:00 CET. We schedule the
GitHub Actions cron at 16:15 UTC, which sits safely after publish in both
CET (UTC+1, 17:15 local) and CEST (UTC+2, 18:15 local). On non-banking days
(weekends, ECB holidays) the feed simply still returns the previous day's
rates with the previous day's `time=` attribute — that is exactly the
behaviour we want, so no special-casing is required.

This script is intended to run as a GitHub Actions cron job once per day;
see `.github/workflows/fetch_fx_rates.yml`.
"""

from __future__ import annotations

import logging
import sys
from datetime import datetime, timezone
from typing import Any
from xml.etree import ElementTree as ET

# Local utils — `scripts/` is on the import path when run from the repo
# root (PYTHONPATH=scripts in the workflow), so `from utils...` works.
from utils.http_client import get_text
from utils.r2_client import upload_json

ECB_URL = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"

# The ECB feed declares two namespaces. We only navigate the inner one
# (`ecb:`) — the outer `gesmes:Envelope` is the SDMX wrapper and we do
# not need any of its attributes.
NS = {
    "gesmes": "http://www.gesmes.org/xml/2002-08-01",
    "ecb": "http://www.ecb.int/vocabulary/2002-08-01/eurofxref",
}

# Cross rates derived from 4-decimal ECB inputs do not justify arbitrary
# precision, but high-magnitude pairs (e.g. JPY ~ 184 EUR-base) lose
# ~0.7% in a round-trip A -> B -> A at 6 decimals. 8 decimals keeps the
# worst-case round-trip deviation under 1e-4 for every pair while only
# adding ~15 % to the JSON payload size — still well under 20 kB.
RATE_DECIMALS = 8

# fx-rates change once per day, so an hour of CDN cache is plenty and
# protects upstream during a brief R2 outage.
FX_CACHE_CONTROL = "public, max-age=3600"

log = logging.getLogger(__name__)


def parse_ecb_xml(xml_text: str) -> tuple[str, dict[str, float]]:
    """
    Parse an ECB eurofxref-daily XML document.

    Structure (single-day form):
        <gesmes:Envelope ...>
          <Cube>
            <Cube time="YYYY-MM-DD">
              <Cube currency="USD" rate="1.08"/>
              <Cube currency="JPY" rate="..."/>
              ...
            </Cube>
          </Cube>
        </gesmes:Envelope>

    Returns:
        (date, rates) where `date` is the ECB publication date and `rates`
        maps each currency code (including EUR=1.0) to its rate against EUR
        (1 EUR = X units of `currency`).

    Raises:
        ValueError: If the XML structure does not match the expected layout.
    """
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        raise ValueError(f"ECB feed is not valid XML: {exc}") from exc

    cube_root = root.find("ecb:Cube", NS)
    if cube_root is None:
        raise ValueError("ECB feed: missing root <Cube> element")

    cube_day = cube_root.find("ecb:Cube", NS)
    if cube_day is None or "time" not in cube_day.attrib:
        raise ValueError("ECB feed: missing dated <Cube time=...> element")

    date = cube_day.attrib["time"]

    # EUR is the implicit base in the ECB feed and not listed as a row;
    # add it explicitly so the cross-rate matrix can treat it uniformly.
    rates: dict[str, float] = {"EUR": 1.0}
    for cube in cube_day.findall("ecb:Cube", NS):
        currency = cube.attrib.get("currency")
        rate_str = cube.attrib.get("rate")
        if not currency or not rate_str:
            log.warning("Skipping malformed Cube element: %s", cube.attrib)
            continue
        try:
            rates[currency] = float(rate_str)
        except ValueError:
            log.warning(
                "Skipping non-numeric rate for %s: %r", currency, rate_str
            )

    if len(rates) <= 1:
        raise ValueError("ECB feed contained no usable currency rates")

    return date, rates


def compute_cross_rates(
    eur_rates: dict[str, float],
) -> dict[str, dict[str, float]]:
    """
    Build a full base -> quote cross-rate matrix from EUR-based rates.

    For any pair (A, B):  rate(A -> B) = eur_rates[B] / eur_rates[A]
    because eur_rates[X] expresses "1 EUR = X units of currency X".

    The matrix is symmetric in size but not in values; we materialise both
    directions so the Flutter app can do `fx_rates[fromCcy][toCcy]` without
    any reciprocal logic on the client.
    """
    cross: dict[str, dict[str, float]] = {}
    for base, base_rate in eur_rates.items():
        cross[base] = {
            quote: round(quote_rate / base_rate, RATE_DECIMALS)
            for quote, quote_rate in eur_rates.items()
        }
    return cross


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    # Single upstream call + single upload: one try/except wraps the whole
    # pipeline. There is no partial-success granularity to preserve here
    # (unlike fetch_history, where each range stands on its own). On a
    # transient failure the previous fx-rates.json on R2 stays in place,
    # and the next cron tick (or a manual workflow_dispatch) refreshes it.
    try:
        log.info("Fetching ECB daily reference rates from %s", ECB_URL)
        xml_text = get_text(ECB_URL)

        date, eur_rates = parse_ecb_xml(xml_text)
        log.info(
            "Parsed ECB feed: date=%s currencies=%d", date, len(eur_rates)
        )

        cross = compute_cross_rates(eur_rates)

        payload: dict[str, Any] = {
            "_meta": {
                "fetchedAt": datetime.now(timezone.utc).isoformat(
                    timespec="seconds"
                ),
                "date": date,
                "source": "ECB",
                "currencies": sorted(eur_rates.keys()),
            },
            **cross,
        }

        upload_json(
            "data/fx-rates.json", payload, cache_control=FX_CACHE_CONTROL
        )
        log.info("FX rates uploaded successfully (date=%s)", date)
        return 0

    except Exception as exc:  # noqa: BLE001 — top-level guard for the cron job
        # `exc_info=True` keeps the stack trace in the GitHub Actions log so
        # we can diagnose without re-running. Returning 1 surfaces the
        # failure via GitHub's failed-workflow notifications.
        log.error("FX rates fetch failed: %s", exc, exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
