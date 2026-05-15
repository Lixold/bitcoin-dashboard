// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Reusable news pipeline used by the per-language news Workers
// (cron-news-en, cron-news-de, …).
//
// Why this module exists:
// The news Workers were near-identical copies (>95 % overlap) of the same
// fetch → parse → fold → classify → dedup → upload pipeline; only the feed
// list and keyword lexicon differed. Centralising the pipeline keeps the
// per-language Workers as thin configuration shells while preserving the
// "one Worker per language" deployment topology required by the
// Cloudflare Free-Tier 10 ms CPU budget (see ADR-0003).

import {
  compileAlternation,
  countMatches,
  fold,
  isoUtcSeconds,
  putJson,
  sha1Hex,
  stripHtml,
} from "./lib.js";

// === Pipeline-wide constants ================================================
//
// These are policy decisions shared by every language. Per-language tuning
// happens via the `lexicon` argument; per-pipeline tuning lives here so all
// languages stay in lockstep on cadence, age, and payload shape.

const KEYWORD_FILTER = ["bitcoin", "btc", "satoshi", "lightning"];
const MAX_ITEMS_PER_FEED = 30;
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const DESC_MAX_CHARS = 150;
const NEWS_CACHE_CONTROL = "public, max-age=900";

// === XML parsing (regex-based, no DOMParser) ===============================
//
// The workerd runtime does not ship a DOMParser. The feeds in our curated
// list are well-formed RSS or Atom; a tight set of regexes is more than
// enough and avoids pulling in an XML library. Each helper is non-greedy
// and uses `[\s\S]` in place of the `s` flag for portability.

const CDATA_RE = /<!\[CDATA\[([\s\S]*?)\]\]>/g;

function stripCdata(s) {
  return s.replace(CDATA_RE, "$1");
}

function escTagName(tag) {
  // RSS uses prefixed tags like `content:encoded` / `dc:date`. The colon is
  // not a regex metacharacter, but escape defensively anyway in case the
  // caller passes something exotic.
  return tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractTag(block, tag) {
  const t = escTagName(tag);
  const re = new RegExp(`<${t}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${t}>`, "i");
  const m = block.match(re);
  if (!m) return "";
  return stripCdata(m[1]).trim();
}

function atomLinkHref(block) {
  // Atom: `<link rel="alternate" href="..."/>`. Prefer rel="alternate" or
  // no rel attribute — otherwise we'd accidentally surface the feed's
  // self-link instead of the article URL.
  const linkRe = /<link\s+([^>]*?)\/?>/gi;
  let m;
  let fallback = "";
  while ((m = linkRe.exec(block)) !== null) {
    const attrs = m[1];
    const hrefMatch = attrs.match(/href\s*=\s*"([^"]+)"/i);
    if (!hrefMatch) continue;
    const href = hrefMatch[1];
    const relMatch = attrs.match(/rel\s*=\s*"([^"]+)"/i);
    if (!relMatch || relMatch[1] === "alternate") return href;
    if (!fallback) fallback = href;
  }
  return fallback;
}

function getLink(block) {
  // RSS first: `<link>URL</link>`. Atom feeds use self-closing
  // `<link href="..."/>` with no text content, so the RSS extractor
  // returns empty and we fall through to the Atom helper.
  const rss = extractTag(block, "link");
  if (rss) return rss;
  return atomLinkHref(block);
}

function getDescription(block) {
  // First non-empty wins. `content:encoded` carries the richest body in
  // RSS but is also the most likely to contain markup; downstream
  // `stripHtml` normalises any of these into clean plain text.
  return (
    extractTag(block, "description") ||
    extractTag(block, "content:encoded") ||
    extractTag(block, "summary") ||
    extractTag(block, "content")
  );
}

function getDate(block) {
  return (
    extractTag(block, "pubDate") ||
    extractTag(block, "published") ||
    extractTag(block, "updated") ||
    extractTag(block, "dc:date")
  );
}

function parseFeed(xmlText) {
  // Returns a normalised array of `{ title, url, description, publishedAt }`
  // entries regardless of RSS or Atom flavour. A regex failure on one
  // block must not poison the others — each block is wrapped in
  // try/catch so a single malformed item never blanks an entire feed.
  const blocks = [];
  let isAtom = false;

  const itemRe = /<item(?:\s[^>]*)?>([\s\S]*?)<\/item>/gi;
  let m;
  while ((m = itemRe.exec(xmlText)) !== null) {
    blocks.push(m[1]);
  }
  if (blocks.length === 0) {
    isAtom = true;
    const entryRe = /<entry(?:\s[^>]*)?>([\s\S]*?)<\/entry>/gi;
    while ((m = entryRe.exec(xmlText)) !== null) {
      blocks.push(m[1]);
    }
  }

  const out = [];
  for (const block of blocks) {
    try {
      const title = extractTag(block, "title");
      const url = isAtom
        ? atomLinkHref(block) || extractTag(block, "link")
        : getLink(block);
      const description = getDescription(block);
      const dateStr = getDate(block);
      const d = dateStr ? new Date(dateStr) : null;
      out.push({
        title,
        url,
        description,
        publishedAt: d && !Number.isNaN(d.getTime()) ? d : null,
      });
    } catch (exc) {
      // Defensive — regexes don't throw, but malformed input could still
      // surprise us. Drop the block and continue.
      console.warn("Skipping malformed item block:", exc);
    }
  }
  return out;
}

// === Per-feed processing ===================================================

async function fetchFeed(name, url) {
  const res = await fetch(url, {
    headers: {
      // A browser-shaped User-Agent unblocks publishers (NewsBTC,
      // BTC-ECHO) that 403 on the default Worker UA.
      "User-Agent":
        "Mozilla/5.0 (compatible; BitcoinDashboardBot/1.0; +https://bitcoin-dashboard.app)",
      Accept:
        "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.5",
    },
  });
  if (!res.ok) {
    throw new Error(`${name} HTTP ${res.status}`);
  }
  const xml = await res.text();
  return parseFeed(xml);
}

async function processFeed(name, url, classifiers, cutoffMs) {
  const { posAlt, negAlt, tagAlts } = classifiers;
  const entries = await fetchFeed(name, url);
  const inCount = entries.length;
  const kept = [];

  for (const entry of entries.slice(0, MAX_ITEMS_PER_FEED)) {
    const title = (entry.title || "").trim();
    const link = (entry.url || "").trim();
    if (!title || !link) continue;
    if (!entry.publishedAt) continue;
    if (entry.publishedAt.getTime() < cutoffMs) continue;

    const descriptionFull = stripHtml(entry.description || "");
    const haystack = fold(title + " " + descriptionFull);

    if (!KEYWORD_FILTER.some((kw) => haystack.includes(kw))) continue;

    const publishedAt = isoUtcSeconds(entry.publishedAt);
    const id = (await sha1Hex(link + publishedAt)).slice(0, 16);

    const pos = countMatches(posAlt.count, haystack);
    const neg = countMatches(negAlt.count, haystack);
    let sentiment = "neutral";
    if (pos > neg) sentiment = "positive";
    else if (neg > pos) sentiment = "negative";

    const tags = [];
    for (const [tag, alt] of Object.entries(tagAlts)) {
      if (alt.test.test(haystack)) tags.push(tag);
    }

    kept.push({
      id,
      title,
      url: link,
      source: name,
      publishedAt,
      tags,
      sentiment,
      description: descriptionFull.slice(0, DESC_MAX_CHARS),
    });
  }

  return { name, inCount, kept };
}

// === Public entry point ====================================================

/**
 * Run the full news pipeline for one language.
 *
 * @param {object}  cfg              Language configuration
 * @param {string}  cfg.lang         Two-letter language code ("en", "de", …)
 * @param {Array<[string,string]>} cfg.feeds  Feed list as `[name, url]` tuples
 * @param {object}  cfg.lexicon      Per-language keyword lists
 * @param {string[]} cfg.lexicon.positive
 * @param {string[]} cfg.lexicon.negative
 * @param {Object.<string,string[]>} cfg.lexicon.tags
 * @param {object}  env              Worker `env` binding (must expose BUCKET)
 *
 * Side effect: writes `data/news-{lang}.json` to R2. The function returns
 * the upload payload so callers (or future tests) can inspect what was
 * shipped without re-parsing R2.
 *
 * Throws only when every feed in the language fails — partial successes
 * are normal and produce a payload with whatever did arrive.
 */
export async function runNewsPipeline({ lang, feeds, lexicon }, env) {
  // Compile regexes once per invocation. Cheap, and keeps every feed
  // working against the same set of regex objects (no per-feed compile
  // churn). The per-tag entries are exposed as `{ test, count }` pairs so
  // the per-feed loop can use the safe non-global `.test()` path.
  const classifiers = {
    posAlt: compileAlternation(lexicon.positive),
    negAlt: compileAlternation(lexicon.negative),
    tagAlts: Object.fromEntries(
      Object.entries(lexicon.tags).map(([tag, kws]) => [
        tag,
        compileAlternation(kws),
      ]),
    ),
  };

  const cutoffMs = Date.now() - MAX_AGE_MS;

  // Independent feeds in parallel — `Promise.allSettled` keeps a single
  // slow or failing feed from blocking the rest. Each feed lands in its
  // own settled result; we tally successes and failures below.
  const settled = await Promise.allSettled(
    feeds.map(([name, url]) =>
      processFeed(name, url, classifiers, cutoffMs),
    ),
  );

  const items = [];
  const seenIds = new Set();
  const validatedFeeds = [];
  let failureCount = 0;

  settled.forEach((res, idx) => {
    const [name] = feeds[idx];
    if (res.status === "rejected") {
      failureCount += 1;
      // 429 (rate-limited) is a publisher policy decision, not a Worker
      // failure — surface as warn to keep the dashboard noise low.
      const msg = res.reason && res.reason.message ? res.reason.message : String(res.reason);
      const level = /HTTP 429\b/.test(msg) ? "warn" : "error";
      console[level](`[${lang}] ${name} FAIL: ${msg}`);
      return;
    }
    const { kept, inCount } = res.value;
    let added = 0;
    for (const item of kept) {
      if (seenIds.has(item.id)) continue;
      seenIds.add(item.id);
      items.push(item);
      added += 1;
    }
    validatedFeeds.push(name);
    console.log(
      `[${lang}] ${name} OK  (${added}/${inCount} kept after filter)`,
    );
  });

  if (validatedFeeds.length === 0) {
    throw new Error(`[${lang}] All ${feeds.length} feeds failed`);
  }

  items.sort((a, b) => (a.publishedAt < b.publishedAt ? 1 : -1));

  const payload = {
    _meta: {
      fetchedAt: isoUtcSeconds(new Date()),
      language: lang,
      feedCount: feeds.length,
      itemCount: items.length,
      validatedFeeds,
    },
    news: items,
  };

  await putJson(env, `data/news-${lang}.json`, payload, NEWS_CACHE_CONTROL);

  console.log(
    `[${lang}] Uploaded ${items.length} items from ` +
      `${validatedFeeds.length}/${feeds.length} feeds ` +
      `(failures=${failureCount})`,
  );

  return payload;
}
