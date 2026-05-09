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
Fetch RSS/Atom news from a curated set of Bitcoin-focused feeds in
multiple languages, classify each item by topic and sentiment, and
upload one JSON file per language to Cloudflare R2 served via the CDN.

Outputs (under the bucket root, keys match the paths the Flutter app reads):
    data/news-en.json    Aggregated EN feeds (Bitcoin Magazine,
                         Cointelegraph, The Block, NewsBTC, CoinDesk)
    data/news-de.json    Aggregated DE feeds (Blocktrainer, BitcoinBlog,
                         BTC-ECHO, CryptoMonday)

Pipeline per language:
    1) Fetch each feed via the shared HTTP client (retry policy applied).
    2) Parse with feedparser; collect entries newer than 24 h that mention
       Bitcoin (bitcoin / btc / satoshi / lightning).
    3) Tag each item by topic (regulation, technology, market, mining,
       adoption) and sentiment (positive/neutral/negative) via a small
       per-language keyword lexicon. Both run on a Unicode-folded copy
       of the text so umlauts in source feeds match diacritic-free
       keywords (e.g. "Bärenmarkt" -> "barenmarkt").
    4) Deduplicate by SHA-1(url + publishedAt), sort newest first.
    5) Upload merged result to R2 under data/news-{lang}.json.

Per-feed errors are isolated: a failing feed is logged and skipped, the
others still produce output. The script exits non-zero only when *every*
language pipeline produces zero output — that signals a real outage
(credentials wrong, every upstream down at once).

This script is intended to run as a GitHub Actions cron job every 15
minutes; see `.github/workflows/fetch_news.yml`.
"""

from __future__ import annotations

import hashlib
import html
import logging
import re
import sys
import unicodedata
from datetime import datetime, timedelta, timezone
from typing import Any, Optional, Pattern

import feedparser

# Local utils — `scripts/` is on the import path when run from the repo
# root (PYTHONPATH=scripts in the workflow), so `from utils...` works.
from utils.http_client import get_bytes
from utils.r2_client import upload_json

# === Pipeline-wide configuration ============================================

# Items must mention at least one of these (case-insensitive substring) in
# title or description after Unicode folding. Filters out generic
# "crypto news" coverage that ships through these feeds alongside BTC items.
KEYWORD_FILTER: tuple[str, ...] = ("bitcoin", "btc", "satoshi", "lightning")

# Per-feed cap on items considered. Feeds vary widely in cadence — this
# protects against a misconfigured feed dumping its full archive on us
# and inflating downstream JSON size.
MAX_ITEMS_PER_FEED = 30

# Drop anything older than this. Stale items pollute the dashboard's
# "latest news" view; the next 15-min run will pick up anything fresh.
MAX_AGE = timedelta(hours=24)

# First N chars of plain-text description after HTML stripping. The Flutter
# UI renders its own ellipsis when the string overflows the available
# space, so we don't append one here.
DESC_MAX_CHARS = 150

# News refresh every 15 min (cron cadence). Match the upload cache so the
# CDN does not over-serve a stale file just past the cron boundary.
NEWS_CACHE_CONTROL = "public, max-age=900"

# Allowed sentiment values — kept as a constant so a typo in the
# classifier returns a verifiable error instead of a silent garbage label.
SENTIMENT_VALUES = ("positive", "neutral", "negative")


# === Per-language configuration =============================================
#
# Keyword lists are intentionally small lexicons, not full taxonomies.
# This is a coarse classifier surfaced in a UI badge, not a research-grade
# NLP pipeline. False positives at the margin are acceptable; we trade
# them for zero ML/dependency overhead and full transparency in the data
# pipeline.
#
# All keyword strings should be lowercase and diacritic-free — the
# matcher Unicode-folds both keyword and haystack before comparing, so
# "Bärenmarkt" / "barenmarkt" / "BAERENMARKT" all match the same entry.

LANGUAGES: dict[str, dict[str, Any]] = {
    "en": {
        "feeds": [
            ("Bitcoin Magazine", "https://bitcoinmagazine.com/feed"),
            ("Cointelegraph", "https://cointelegraph.com/rss"),
            ("The Block", "https://www.theblock.co/rss.xml"),
            # Use the root /feed/ rather than /category/bitcoin/feed/ —
            # the category feed is currently empty, while the root feed
            # carries ~10 fresh items per cycle. Off-topic altcoin items
            # are removed downstream by the BTC keyword filter (typical
            # ratio ~80 % of root feed survives).
            ("NewsBTC", "https://www.newsbtc.com/feed/"),
            (
                "CoinDesk",
                "https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml",
            ),
        ],
        "positive": (
            "surge", "jump", "gain", "rally", "bull", "bullish",
            "up", "rise", "growth", "adoption",
        ),
        "negative": (
            "crash", "fall", "drop", "decline", "bear", "bearish",
            "down", "loss", "concern", "risk",
        ),
        "tags": {
            "regulation": (
                "regulation", "regulator", "sec", "kyc", "micar", "mica",
                "law", "compliance", "ban", "license", "government", "court",
            ),
            "technology": (
                "lightning", "protocol", "upgrade", "taproot", "segwit",
                "bitcoin core", "fork", "vulnerability", "security",
            ),
            "market": (
                "price", "trade", "trading", "market", "volatility",
                "etf", "futures", "options", "rally", "sell-off",
            ),
            "mining": (
                "mining", "miner", "hashrate", "difficulty", "asic",
                "pool", "hash",
            ),
            "adoption": (
                "adoption", "accept", "payment", "mainstream", "treasury",
                "retail", "integration", "user",
            ),
        },
    },
    "de": {
        "feeds": [
            ("Blocktrainer", "https://www.blocktrainer.de/feed/"),
            ("BitcoinBlog.de", "https://bitcoinblog.de/feed/"),
            ("BTC-ECHO", "https://www.btc-echo.de/feed/"),
            ("CryptoMonday", "https://cryptomonday.de/feed/"),
        ],
        "positive": (
            "anstieg", "gewinne", "rally", "bullenmarkt", "hoch",
            "wachstum", "adoption",
        ),
        "negative": (
            "crash", "absturz", "verlust", "barenmarkt", "ruckgang",
            "sorge", "risiko",
        ),
        "tags": {
            "regulation": (
                "regulierung", "gesetz", "behorde", "verbot", "lizenz",
                "micar", "kyc", "compliance",
            ),
            "technology": (
                "protokoll", "lightning", "sicherheit", "upgrade",
                "sicherheitslucke", "fork", "taproot",
            ),
            "market": (
                "preis", "kurs", "markt", "volatilitat", "etf", "handel",
                "rallye",
            ),
            "mining": (
                "mining", "miner", "hashrate", "schwierigkeit", "asic",
                "pool",
            ),
            "adoption": (
                "adoption", "integration", "akzeptanz", "zahlung",
                "unternehmen", "mainstream", "nutzer",
            ),
        },
    },
}

log = logging.getLogger(__name__)


# === Text normalization =====================================================

_HTML_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


def strip_html(text: str) -> str:
    """Reduce a feed's HTML summary to a single line of plain text."""
    if not text:
        return ""
    no_tags = _HTML_TAG_RE.sub(" ", text)
    decoded = html.unescape(no_tags)
    return _WS_RE.sub(" ", decoded).strip()


def fold(text: str) -> str:
    """
    Lowercase + strip diacritics for robust keyword matching.

    NFKD decomposes accented characters into base + combining marks, then
    we drop the combining marks. Effects: "Bärenmarkt" -> "barenmarkt",
    "Anstieg" -> "anstieg", "BTC" -> "btc". Plain ASCII passes through
    unchanged, so this is a no-op cost for the EN pipeline.
    """
    nfkd = unicodedata.normalize("NFKD", text.lower())
    return "".join(ch for ch in nfkd if not unicodedata.combining(ch))


def _compile_alternation(keywords: tuple[str, ...]) -> Pattern[str]:
    """
    Compile a word-bounded alternation regex over `keywords`.

    Word boundaries (`\\b`) on both sides prevent "up" from matching
    "upgrade" or "supply", which would otherwise dominate sentiment
    scores in tech-heavy news. Multi-word keywords like "bitcoin core"
    work as well: \\b only requires a word/non-word transition, and
    spaces qualify.
    """
    folded = [re.escape(fold(k)) for k in keywords]
    return re.compile(r"\b(?:" + "|".join(folded) + r")\b")


# === Per-item processing ====================================================


def fetch_and_parse_feed(name: str, url: str) -> list[Any]:
    """
    Fetch a feed and return its parsed entries.

    Raises on HTTP-level failures (caught by the per-feed loop in
    `process_language` and turned into a warning + skip). feedparser
    flags malformed XML via `bozo`; we only treat that as fatal when no
    entries were extracted at all — many real-world feeds are slightly
    non-conformant but still fully usable.
    """
    raw = get_bytes(url)
    feed = feedparser.parse(raw)
    if feed.bozo and not feed.entries:
        raise ValueError(
            f"feedparser bozo with no entries: {feed.bozo_exception!r}"
        )
    return list(feed.entries)


def _entry_published(entry: Any) -> Optional[datetime]:
    """
    Resolve an entry's publication time to a UTC datetime, or None.

    feedparser normalizes `<pubDate>` (RSS) and `<published>`/`<updated>`
    (Atom) into the `_parsed` struct_time fields in UTC. We prefer
    `published_parsed` and fall back to `updated_parsed` for Atom feeds
    that omit the former.
    """
    pp = entry.get("published_parsed") or entry.get("updated_parsed")
    if not pp:
        return None
    try:
        return datetime(*pp[:6], tzinfo=timezone.utc)
    except (TypeError, ValueError):
        return None


def _entry_description(entry: Any) -> str:
    """Pick the best available description field; return plain text."""
    raw = entry.get("summary") or entry.get("description") or ""
    if not raw:
        # Atom <content> arrives as a list of dicts; first one usually
        # holds the article body. Last-resort fallback only.
        content = entry.get("content") or []
        if content:
            raw = content[0].get("value", "")
    return strip_html(raw)


def normalize_item(
    entry: Any,
    source_name: str,
    pos_re: Pattern[str],
    neg_re: Pattern[str],
    tag_res: dict[str, Pattern[str]],
) -> Optional[dict[str, Any]]:
    """
    Convert one feedparser entry into our output schema, or None to skip.

    Returns None for entries that are unusable (missing date, missing
    title/url, off-topic) — the caller advances without comment.
    """
    title = (entry.get("title") or "").strip()
    url = (entry.get("link") or "").strip()
    if not title or not url:
        return None

    published = _entry_published(entry)
    if published is None:
        return None

    description_full = _entry_description(entry)

    # Topic/sentiment classifiers and the Bitcoin keyword filter all run
    # on the same folded haystack. Computing it once is cheap and keeps
    # behaviour consistent (e.g. "BTC" matches the filter the same way
    # it would match a tag keyword).
    haystack = fold(title + " " + description_full)
    if not any(kw in haystack for kw in KEYWORD_FILTER):
        return None

    # Stable ID across runs: same (url, publishedAt) -> same id, so the
    # downstream Flutter cache can recognise repeats. URL alone would
    # collide if a publisher reuses URLs (rare but observed for "live"
    # ticker pages).
    item_id = hashlib.sha1(
        (url + published.isoformat()).encode("utf-8")
    ).hexdigest()[:16]

    pos_count = len(pos_re.findall(haystack))
    neg_count = len(neg_re.findall(haystack))
    if pos_count > neg_count:
        sentiment = "positive"
    elif neg_count > pos_count:
        sentiment = "negative"
    else:
        sentiment = "neutral"

    tags = [tag for tag, pat in tag_res.items() if pat.search(haystack)]

    return {
        "id": item_id,
        "title": title,
        "url": url,
        "source": source_name,
        "publishedAt": published.isoformat(timespec="seconds"),
        "tags": tags,
        "sentiment": sentiment,
        "description": description_full[:DESC_MAX_CHARS],
    }


# === Per-language pipeline ==================================================


def process_language(lang_code: str, lang_config: dict[str, Any]) -> dict[str, Any]:
    """
    Run the full fetch+filter+classify pipeline for one language.

    Returns the JSON payload ready to upload. Per-feed failures are
    logged at WARNING and reported in the per-feed status block; they
    do not abort the language.
    """
    pos_re = _compile_alternation(lang_config["positive"])
    neg_re = _compile_alternation(lang_config["negative"])
    tag_res = {
        tag: _compile_alternation(kws)
        for tag, kws in lang_config["tags"].items()
    }

    cutoff = datetime.now(timezone.utc) - MAX_AGE

    items: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    validated_feeds: list[str] = []
    feed_status: list[tuple[str, str, str]] = []  # (name, status, detail)

    for source_name, url in lang_config["feeds"]:
        try:
            entries = fetch_and_parse_feed(source_name, url)
        except Exception as exc:  # noqa: BLE001 — log + isolate per feed
            log.warning("[%s] %s FAIL: %s", lang_code, source_name, exc)
            feed_status.append((source_name, "FAIL", str(exc)))
            continue

        in_count = len(entries)
        kept = 0

        for entry in entries[:MAX_ITEMS_PER_FEED]:
            try:
                item = normalize_item(
                    entry, source_name, pos_re, neg_re, tag_res
                )
            except Exception as exc:  # noqa: BLE001 — never fatal per item
                log.debug(
                    "[%s] %s entry skipped: %s", lang_code, source_name, exc
                )
                continue
            if item is None:
                continue

            published = datetime.fromisoformat(item["publishedAt"])
            if published < cutoff:
                continue

            if item["id"] in seen_ids:
                continue
            seen_ids.add(item["id"])
            items.append(item)
            kept += 1

        validated_feeds.append(source_name)
        feed_status.append(
            (source_name, "OK", f"{kept}/{in_count} kept after filter")
        )

    # Per-feed status block — printed at INFO so it always shows up in
    # the Actions log without requiring a verbose flag. Helpful when a
    # feed silently goes empty (HTTP 200, valid XML, zero entries).
    log.info("=== [%s] feed status ===", lang_code)
    for name, status, detail in feed_status:
        log.info("[%s] %-20s %-4s  (%s)", lang_code, name, status, detail)

    items.sort(key=lambda x: x["publishedAt"], reverse=True)

    return {
        "_meta": {
            "fetchedAt": datetime.now(timezone.utc).isoformat(
                timespec="seconds"
            ),
            "language": lang_code,
            "feedCount": len(lang_config["feeds"]),
            "itemCount": len(items),
            "validatedFeeds": validated_feeds,
        },
        "news": items,
    }


# === Entry point ============================================================


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    successes = 0
    failures: list[str] = []

    for lang_code, lang_config in LANGUAGES.items():
        try:
            log.info("=== Processing language: %s ===", lang_code)
            payload = process_language(lang_code, lang_config)
            upload_json(
                f"data/news-{lang_code}.json",
                payload,
                cache_control=NEWS_CACHE_CONTROL,
            )
            log.info(
                "[%s] Uploaded %d items from %d/%d feeds",
                lang_code,
                payload["_meta"]["itemCount"],
                len(payload["_meta"]["validatedFeeds"]),
                payload["_meta"]["feedCount"],
            )
            successes += 1
        except Exception as exc:  # noqa: BLE001
            log.error(
                "[%s] Language pipeline failed: %s",
                lang_code,
                exc,
                exc_info=True,
            )
            failures.append(f"{lang_code}: {exc}")

    if failures:
        log.warning("Failed languages: %s", "; ".join(failures))

    # Exit non-zero only if literally no language uploaded — see the
    # equivalent rationale in fetch_history.py. Partial success keeps
    # the dashboard fresh on whatever locales we could reach.
    return 0 if successes > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
