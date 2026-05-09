# MIT License
#
# Copyright (c) 2026 Daniel Nagel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, subject to the conditions in the LICENSE
# file in the project root.
"""
Shared HTTP client with retry logic.

All data-fetching scripts (CoinGecko, ECB, RSS feeds, …) talk to public APIs
that occasionally rate-limit, time out, or return 5xx during deploys. Rather
than handling that in every script, we centralise the retry policy here.

Usage:
    from utils.http_client import get_json
    data = get_json("https://api.coingecko.com/api/v3/coins/bitcoin")
"""

from __future__ import annotations

import logging
from typing import Any, Mapping, Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Conservative timeout: 10 s connect, 30 s read. Most public APIs answer in
# well under a second; 30 s read protects against slow CoinGecko responses
# during global market events without hanging GitHub Actions runners.
DEFAULT_TIMEOUT = (10, 30)

# Retry on the transient failures we typically see from public APIs:
#   429 — rate limit (CoinGecko Demo API: 30 req/min)
#   500, 502, 503, 504 — gateway / upstream errors
# `backoff_factor=1` produces sleeps of 1s, 2s, 4s between retries.
_RETRY_POLICY = Retry(
    total=4,
    connect=3,
    read=3,
    status=4,
    backoff_factor=1.0,
    status_forcelist=(429, 500, 502, 503, 504),
    allowed_methods=frozenset(["GET", "HEAD"]),
    respect_retry_after_header=True,
    raise_on_status=False,
)

log = logging.getLogger(__name__)


def _build_session() -> requests.Session:
    """Build a `requests.Session` with the shared retry policy mounted."""
    session = requests.Session()
    adapter = HTTPAdapter(max_retries=_RETRY_POLICY)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    # Identify ourselves so upstream operators can contact us if needed.
    session.headers.update(
        {"User-Agent": "bitcoin-dashboard-fetcher/1.0 (+https://bitcoin-dashboard.app)"}
    )
    return session


def get_json(
    url: str,
    *,
    params: Optional[Mapping[str, Any]] = None,
    headers: Optional[Mapping[str, str]] = None,
    timeout: tuple[float, float] = DEFAULT_TIMEOUT,
) -> Any:
    """
    GET `url` and return the parsed JSON response.

    Raises:
        requests.HTTPError:     For non-2xx responses after retries are exhausted.
        requests.RequestException: For network-level failures.
        ValueError:             If the response body is not valid JSON.
    """
    session = _build_session()
    log.debug("GET %s params=%s", url, params)

    response = session.get(url, params=params, headers=headers, timeout=timeout)
    response.raise_for_status()
    return response.json()


def get_text(
    url: str,
    *,
    params: Optional[Mapping[str, Any]] = None,
    headers: Optional[Mapping[str, str]] = None,
    timeout: tuple[float, float] = DEFAULT_TIMEOUT,
) -> str:
    """
    GET `url` and return the response body as decoded text.

    Used for non-JSON sources (ECB XML feed, RSS feeds, …). The retry policy
    is identical to `get_json`; only the body decoding differs — `requests`
    derives the encoding from the `Content-Type` header (with a UTF-8 default).

    Raises:
        requests.HTTPError:        For non-2xx responses after retries are exhausted.
        requests.RequestException: For network-level failures.
    """
    session = _build_session()
    log.debug("GET %s params=%s (text)", url, params)

    response = session.get(url, params=params, headers=headers, timeout=timeout)
    response.raise_for_status()
    return response.text


def get_bytes(
    url: str,
    *,
    params: Optional[Mapping[str, Any]] = None,
    headers: Optional[Mapping[str, str]] = None,
    timeout: tuple[float, float] = DEFAULT_TIMEOUT,
) -> bytes:
    """
    GET `url` and return the raw response body as bytes.

    Preferred over `get_text` when the consumer parses encoding from the
    payload itself — e.g. feedparser inspects the XML declaration
    (`<?xml version="1.0" encoding="..."?>`) and would otherwise be fed
    text already decoded under whatever charset `requests` guessed.

    Raises:
        requests.HTTPError:        For non-2xx responses after retries are exhausted.
        requests.RequestException: For network-level failures.
    """
    session = _build_session()
    log.debug("GET %s params=%s (bytes)", url, params)

    response = session.get(url, params=params, headers=headers, timeout=timeout)
    response.raise_for_status()
    return response.content
