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
//
// XML parsing uses fast-xml-parser (see workers/package.json). The
// regex-based parser that used to live in this file was ~100 LOC of
// hand-rolled CDATA / tag / atom-link extraction; fast-xml-parser is
// bundle-clean in the workerd runtime, covers more feed shapes out of
// the box, and removes a long tail of feed-specific failure modes.

import { XMLParser } from "fast-xml-parser";

import {
  compileAlternation,
  countMatches,
  decodeEntities,
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

// === XML parsing (fast-xml-parser) =========================================
//
// A single parser instance is reused across feeds — fast-xml-parser is
// stateless once constructed, so this is purely a startup optimisation.
//
// Options of note:
//   * `ignoreAttributes: false`  — Atom <link href="..."/> only lives
//                                   in attributes; we need them.
//   * `attributeNamePrefix: "@_"` — fast-xml-parser default; keeps
//                                   attributes namespaced apart from
//                                   child elements.
//   * `isArray`                  — RSS items/Atom entries/Atom links can
//                                   appear once or many times; forcing
//                                   array shape removes a long if/else
//                                   spiral downstream.
//   * `trimValues: true`         — feed bodies are noisy with whitespace
//                                   we have no use for.

const _xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  trimValues: true,
  isArray: (_name, jpath) =>
    /\.(item|entry|link)$/.test(jpath),
});

export function asText(node) {
  // fast-xml-parser collapses CDATA to text by default. A field may still
  // arrive as an object when the source feed wraps it (e.g. an empty tag
  // with attributes), in which case `#text` carries the body.
  if (node === undefined || node === null) return "";
  if (typeof node === "string") return node;
  if (typeof node === "number" || typeof node === "boolean") return String(node);
  if (typeof node === "object" && typeof node["#text"] === "string") {
    return node["#text"];
  }
  return "";
}

export function atomLinkHref(links) {
  // Atom: prefer rel="alternate" (or rel absent). Self-links sometimes
  // arrive first; without this we'd surface the feed URL rather than the
  // article URL.
  if (!Array.isArray(links)) return "";
  for (const l of links) {
    if (!l || typeof l !== "object") continue;
    const href = l["@_href"];
    if (!href) continue;
    const rel = l["@_rel"];
    if (!rel || rel === "alternate") return href;
  }
  return links[0]?.["@_href"] ?? "";
}

export function rssLink(link) {
  // RSS: usually a plain string. Because the parser is configured to
  // coerce every `link` field to an array (for Atom feeds with multiple
  // entry-links), a plain RSS `<link>` arrives here as `["https://..."]`.
  // First plain string wins; we fall through to atomLinkHref only when
  // every entry is an object (Atom-style `<link rel="..." href="..."/>`
  // smuggled into an RSS channel).
  if (typeof link === "string") return link;
  if (Array.isArray(link)) {
    for (const l of link) {
      if (typeof l === "string" && l) return l;
    }
    return atomLinkHref(link);
  }
  if (link && typeof link === "object") {
    return link["@_href"] || asText(link);
  }
  return "";
}

export function parseDate(s) {
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Parse a feed XML body into a uniform `[{ title, url, description,
 * publishedAt }]` shape across both RSS and Atom flavours.
 *
 * Returns an empty array (rather than throwing) when the XML is
 * unrecognisable — the caller's per-feed isolation logic logs and skips
 * accordingly. Item-level field issues are handled lazily in the caller
 * by checking for empty title/url and skipping.
 */
export function parseFeed(xmlText) {
  let doc;
  try {
    doc = _xmlParser.parse(xmlText);
  } catch (exc) {
    console.warn(`Feed XML parse failed: ${exc}`);
    return [];
  }

  // RSS 2.0
  const channel = doc?.rss?.channel;
  if (channel && Array.isArray(channel.item)) {
    return channel.item.map((it) => {
      const title = asText(it.title).trim();
      const url = rssLink(it.link).trim();
      const description = asText(
        it["content:encoded"] ?? it.description ?? it.summary ?? it.content,
      ).trim();
      const dateStr = asText(it.pubDate ?? it["dc:date"]);
      return {
        title,
        url,
        description,
        publishedAt: parseDate(dateStr),
      };
    });
  }

  // Atom 1.0
  const entries = doc?.feed?.entry;
  if (Array.isArray(entries)) {
    return entries.map((it) => {
      const title = asText(it.title).trim();
      const url = atomLinkHref(it.link).trim();
      const description = asText(it.summary ?? it.content).trim();
      const dateStr = asText(it.published ?? it.updated);
      return {
        title,
        url,
        description,
        publishedAt: parseDate(dateStr),
      };
    });
  }

  return [];
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
    const title = entry.title;
    const link = entry.url;
    if (!title || !link) continue;
    if (!entry.publishedAt) continue;
    if (entry.publishedAt.getTime() < cutoffMs) continue;

    // fast-xml-parser already unwraps CDATA and resolves the five basic
    // XML entities (&amp; &lt; &gt; &quot; &apos;). Publisher feeds
    // occasionally smuggle HTML markup or German named entities
    // (&auml; …) inside the description — `stripHtml` handles both.
    const descriptionFull = stripHtml(decodeEntities(entry.description || ""));
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
