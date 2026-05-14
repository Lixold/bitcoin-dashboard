// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: EN Bitcoin news aggregator.
//
// Replaces the English half of scripts/fetch_news.py. The output schema is
// identical so the Flutter app (newsProvider) consumes it unchanged.
//
// Pipeline:
//   1) Fetch each EN RSS feed in parallel.
//   2) Parse RSS/Atom XML via inline regex helpers (workerd has no DOMParser).
//   3) Keep items < 24h old that mention bitcoin / btc / satoshi / lightning
//      (Unicode-folded substring match).
//   4) Classify by sentiment (positive/neutral/negative) and topic
//      (regulation / technology / market / mining / adoption) via small
//      word-bounded keyword regexes — same coarse lexicon as the Python.
//   5) Deduplicate by SHA-1(url + publishedAt), sort newest first.
//   6) Upload to R2 at data/news-en.json with a 15-min CDN cache.
//
// Per-feed failures are isolated: a failing feed logs via console.error and
// is skipped; the Worker only throws when every feed fails.

const LANG = "en";

// Feed list — identical to the LANGUAGES["en"] block in fetch_news.py. Order
// is preserved so the `validatedFeeds` array in the output stays stable.
const FEEDS = [
  ["Bitcoin Magazine", "https://bitcoinmagazine.com/feed"],
  ["Cointelegraph", "https://cointelegraph.com/rss"],
  ["The Block", "https://www.theblock.co/rss.xml"],
  // Root /feed/ rather than /category/bitcoin/feed/ — the category feed is
  // currently empty; off-topic items from the root feed are filtered out
  // by the Bitcoin keyword filter downstream.
  ["NewsBTC", "https://www.newsbtc.com/feed/"],
  ["CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml"],
];

const POSITIVE = [
  "surge", "jump", "gain", "rally", "bull", "bullish",
  "up", "rise", "growth", "adoption",
];
const NEGATIVE = [
  "crash", "fall", "drop", "decline", "bear", "bearish",
  "down", "loss", "concern", "risk",
];
const TAGS = {
  regulation: [
    "regulation", "regulator", "sec", "kyc", "micar", "mica",
    "law", "compliance", "ban", "license", "government", "court",
  ],
  technology: [
    "lightning", "protocol", "upgrade", "taproot", "segwit",
    "bitcoin core", "fork", "vulnerability", "security",
  ],
  market: [
    "price", "trade", "trading", "market", "volatility",
    "etf", "futures", "options", "rally", "sell-off",
  ],
  mining: [
    "mining", "miner", "hashrate", "difficulty", "asic",
    "pool", "hash",
  ],
  adoption: [
    "adoption", "accept", "payment", "mainstream", "treasury",
    "retail", "integration", "user",
  ],
};

// Pipeline-wide constants — kept in sync with fetch_news.py.
const KEYWORD_FILTER = ["bitcoin", "btc", "satoshi", "lightning"];
const MAX_ITEMS_PER_FEED = 30;
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const DESC_MAX_CHARS = 150;
const NEWS_CACHE_CONTROL = "public, max-age=900";

// === Text helpers ==========================================================

// NFKD + strip combining diacritics + lowercase. Equivalent to the Python
// `unicodedata.normalize("NFKD", t.lower())` filter — "Bärenmarkt" folds to
// "barenmarkt", plain ASCII passes through unchanged.
function fold(text) {
  return text.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

const HTML_TAG_RE = /<[^>]*>/g;
const WS_RE = /\s+/g;
const HTML_ENTITY_MAP = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
};

// Minimal HTML entity decode — covers the named entities feedparser unescapes
// for free, plus numeric refs. Anything exotic survives as-is, which the
// Flutter UI is happy to render.
function decodeEntities(s) {
  return s
    .replace(/&#x([0-9a-fA-F]+);/g, (_, h) =>
      String.fromCodePoint(parseInt(h, 16)),
    )
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&([a-zA-Z]+);/g, (m, name) =>
      Object.prototype.hasOwnProperty.call(HTML_ENTITY_MAP, name)
        ? HTML_ENTITY_MAP[name]
        : m,
    );
}

function stripHtml(text) {
  if (!text) return "";
  const noTags = text.replace(HTML_TAG_RE, " ");
  const decoded = decodeEntities(noTags);
  return decoded.replace(WS_RE, " ").trim();
}

// Word-bounded alternation over the folded keyword list. \b on both sides
// prevents "up" from matching "upgrade" or "supply" — that prefix
// behaviour was a real source of sentiment noise in the Python prototype.
function compileAlternation(keywords) {
  const escaped = keywords.map((k) =>
    fold(k).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"),
  );
  return new RegExp(`\\b(?:${escaped.join("|")})\\b`, "g");
}

function countMatches(re, text) {
  // Reset lastIndex defensively — the regex is global and reused.
  re.lastIndex = 0;
  const matches = text.match(re);
  return matches ? matches.length : 0;
}

async function sha1Hex(input) {
  const buf = await crypto.subtle.digest(
    "SHA-1",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// === ISO formatting ========================================================

// Python emits "2026-05-10T12:34:56+00:00"; JS Date.toISOString() emits
// "2026-05-10T12:34:56.789Z". Normalise to the Python shape so the Flutter
// parser sees identical strings across script and Worker eras.
function isoUtcSeconds(d) {
  return d.toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

// === XML parsing (regex-based, no DOMParser) ===============================
//
// The CF Workers runtime (workerd) does not ship a DOMParser. We use a
// small set of regexes instead — sufficient for the well-formed RSS/Atom
// feeds in our curated list. Each helper is non-greedy and uses `[\s\S]`
// in place of `.s` for portability with older runtimes.

const CDATA_RE = /<!\[CDATA\[([\s\S]*?)\]\]>/g;

function stripCdata(s) {
  // CDATA wrappers can appear standalone or embedded in a tag's content.
  // We unwrap them globally so the downstream HTML stripper sees the
  // payload as plain markup.
  return s.replace(CDATA_RE, "$1");
}

function escTagName(tag) {
  // RSS uses prefixed tags like content:encoded / dc:date. The colon is
  // not a regex special, but we still escape defensively.
  return tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Pull the first occurrence of <tag>...</tag> (with optional attributes).
// Returns CDATA-stripped, trimmed text — or "" if not present.
function extractTag(block, tag) {
  const t = escTagName(tag);
  const re = new RegExp(`<${t}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${t}>`, "i");
  const m = block.match(re);
  if (!m) return "";
  return stripCdata(m[1]).trim();
}

// Atom: <link rel="alternate" href="..."/>. Prefer rel="alternate" (or no
// rel at all) so we don't accidentally surface the feed's self-link.
function atomLinkHref(block) {
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
  // RSS first: <link>URL</link>. Some feeds embed the URL in CDATA, which
  // extractTag already unwraps. Atom feeds use self-closing <link href="..."/>
  // and have no text content for the <link> tag, so we fall through.
  const rss = extractTag(block, "link");
  if (rss) return rss;
  return atomLinkHref(block);
}

function getDescription(block) {
  // First-match wins across the common variants. content:encoded is the
  // richest RSS body field and worth preferring when present, but most
  // feeds ship a usable plain summary in <description>, so we keep the
  // historical order (description -> content:encoded -> summary -> content).
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
  // Returns a normalized [{ title, url, description, publishedAt(Date|null) }]
  // regardless of RSS-vs-Atom flavour. A regex failure on one block must
  // not poison the others — we wrap the per-block extraction in a
  // try/catch and skip the block on error. Per-feed isolation is then
  // preserved one level up via Promise.allSettled.
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
      const url = isAtom ? atomLinkHref(block) || extractTag(block, "link") : getLink(block);
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
      // Defensive — should be unreachable since the regexes don't throw,
      // but malformed input could still surprise us. Drop the block and
      // continue so one bad item never kills the whole feed.
      console.warn("Skipping malformed item block:", exc);
    }
  }
  return out;
}

// === Per-feed pipeline =====================================================

async function fetchFeed(name, url) {
  const res = await fetch(url, {
    headers: {
      // Some publishers (NewsBTC, BTC-ECHO) 403 on default fetch UA;
      // a browser-shaped UA gets us a clean 200 without any other tweaks.
      "User-Agent":
        "Mozilla/5.0 (compatible; BitcoinDashboardBot/1.0; +https://bitcoin-dashboard.app)",
      Accept: "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.5",
    },
  });
  if (!res.ok) {
    throw new Error(`${name} HTTP ${res.status}`);
  }
  const xml = await res.text();
  return parseFeed(xml);
}

async function processFeed(name, url, posRe, negRe, tagRes, cutoffMs) {
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

    // Bitcoin-topic filter — same Unicode-folded substring check as the
    // Python script. Keeps "lightning" hits even when the source feed
    // sneaks them in via altcoin coverage.
    if (!KEYWORD_FILTER.some((kw) => haystack.includes(kw))) continue;

    const publishedAt = isoUtcSeconds(entry.publishedAt);
    const id = (await sha1Hex(link + publishedAt)).slice(0, 16);

    const pos = countMatches(posRe, haystack);
    const neg = countMatches(negRe, haystack);
    let sentiment = "neutral";
    if (pos > neg) sentiment = "positive";
    else if (neg > pos) sentiment = "negative";

    const tags = [];
    for (const [tag, re] of Object.entries(tagRes)) {
      re.lastIndex = 0;
      if (re.test(haystack)) tags.push(tag);
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

// === Main pipeline =========================================================

async function runAll(env) {
  const posRe = compileAlternation(POSITIVE);
  const negRe = compileAlternation(NEGATIVE);
  const tagRes = {};
  for (const [tag, kws] of Object.entries(TAGS)) {
    tagRes[tag] = compileAlternation(kws);
  }

  const cutoffMs = Date.now() - MAX_AGE_MS;

  // All feeds in parallel — independent HTTP calls, no upstream rate-limit
  // concern (each feed is a different host). Promise.allSettled keeps a
  // single slow/failing feed from blocking the rest.
  const settled = await Promise.allSettled(
    FEEDS.map(([name, url]) =>
      processFeed(name, url, posRe, negRe, tagRes, cutoffMs),
    ),
  );

  const items = [];
  const seenIds = new Set();
  const validatedFeeds = [];
  let failureCount = 0;

  settled.forEach((res, idx) => {
    const [name] = FEEDS[idx];
    if (res.status === "rejected") {
      failureCount += 1;
      // 429 = upstream rate-limiting; non-fatal, downgraded to warn.
      if (/429/.test(String(res.reason))) {
        console.warn(`[${LANG}] ${name} SKIP (rate-limited):`, res.reason);
      } else {
        console.error(`[${LANG}] ${name} FAIL:`, res.reason);
      }
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
      `[${LANG}] ${name} OK  (${added}/${inCount} kept after filter)`,
    );
  });

  if (validatedFeeds.length === 0) {
    throw new Error(`[${LANG}] All ${FEEDS.length} feeds failed`);
  }

  items.sort((a, b) => (a.publishedAt < b.publishedAt ? 1 : -1));

  const payload = {
    _meta: {
      fetchedAt: isoUtcSeconds(new Date()),
      language: LANG,
      feedCount: FEEDS.length,
      itemCount: items.length,
      validatedFeeds,
    },
    news: items,
  };

  await env.BUCKET.put(`data/news-${LANG}.json`, JSON.stringify(payload), {
    httpMetadata: {
      contentType: "application/json",
      cacheControl: NEWS_CACHE_CONTROL,
    },
  });

  console.log(
    `[${LANG}] Uploaded ${items.length} items from ` +
      `${validatedFeeds.length}/${FEEDS.length} feeds ` +
      `(failures=${failureCount})`,
  );
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runAll(env));
  },
};
