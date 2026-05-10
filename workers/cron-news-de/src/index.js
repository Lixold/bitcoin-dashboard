// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: DE Bitcoin news aggregator.
//
// Replaces the German half of scripts/fetch_news.py. The pipeline is
// byte-for-byte identical to cron-news-en — only the feed list and the
// per-language keyword lexicon differ. Kept as a separate self-contained
// Worker (per architectural decision in the migration brief) so each
// language can fail, scale, and be deployed independently.
//
// All keyword strings below are lowercase and diacritic-free. The matcher
// Unicode-folds both keyword and haystack before comparing, so "Bärenmarkt"
// / "barenmarkt" / "BAERENMARKT" all hit the same entry.

const LANG = "de";

const FEEDS = [
  ["Blocktrainer", "https://www.blocktrainer.de/feed/"],
  ["BitcoinBlog.de", "https://bitcoinblog.de/feed/"],
  ["BTC-ECHO", "https://www.btc-echo.de/feed/"],
  ["CryptoMonday", "https://cryptomonday.de/feed/"],
];

const POSITIVE = [
  "anstieg", "gewinne", "rally", "bullenmarkt", "hoch",
  "wachstum", "adoption",
];
const NEGATIVE = [
  "crash", "absturz", "verlust", "barenmarkt", "ruckgang",
  "sorge", "risiko",
];
const TAGS = {
  regulation: [
    "regulierung", "gesetz", "behorde", "verbot", "lizenz",
    "micar", "kyc", "compliance",
  ],
  technology: [
    "protokoll", "lightning", "sicherheit", "upgrade",
    "sicherheitslucke", "fork", "taproot",
  ],
  market: [
    "preis", "kurs", "markt", "volatilitat", "etf", "handel",
    "rallye",
  ],
  mining: [
    "mining", "miner", "hashrate", "schwierigkeit", "asic",
    "pool",
  ],
  adoption: [
    "adoption", "integration", "akzeptanz", "zahlung",
    "unternehmen", "mainstream", "nutzer",
  ],
};

const KEYWORD_FILTER = ["bitcoin", "btc", "satoshi", "lightning"];
const MAX_ITEMS_PER_FEED = 30;
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const DESC_MAX_CHARS = 150;
const NEWS_CACHE_CONTROL = "public, max-age=900";

// === Text helpers ==========================================================

function fold(text) {
  return text.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

const HTML_TAG_RE = /<[^>]*>/g;
const WS_RE = /\s+/g;
const HTML_ENTITY_MAP = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  auml: "ä", ouml: "ö", uuml: "ü", Auml: "Ä", Ouml: "Ö", Uuml: "Ü",
  szlig: "ß",
};

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

function compileAlternation(keywords) {
  const escaped = keywords.map((k) =>
    fold(k).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"),
  );
  return new RegExp(`\\b(?:${escaped.join("|")})\\b`, "g");
}

function countMatches(re, text) {
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
  return s.replace(CDATA_RE, "$1");
}

function escTagName(tag) {
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
  const rss = extractTag(block, "link");
  if (rss) return rss;
  return atomLinkHref(block);
}

function getDescription(block) {
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
  // See workers/cron-news-en/src/index.js for the long-form comment. The
  // pipeline is shared by design — only the per-language feed list and
  // lexicon differ.
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
      console.warn("Skipping malformed item block:", exc);
    }
  }
  return out;
}

// === Per-feed pipeline =====================================================

async function fetchFeed(name, url) {
  const res = await fetch(url, {
    headers: {
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
      console.error(`[${LANG}] ${name} FAIL:`, res.reason);
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
