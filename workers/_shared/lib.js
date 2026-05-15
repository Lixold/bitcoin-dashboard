// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Shared helpers for all bitcoin-dashboard Cloudflare Workers.
//
// Imported via relative path; wrangler's esbuild-based bundler inlines the
// module into each Worker's deploy artifact, so there's no module resolution
// concern at runtime. Each Worker keeps its own domain-specific constants
// and handler — only the boring plumbing lives here.

// === Time formatting ========================================================

/**
 * Format a Date as `YYYY-MM-DDTHH:MM:SS+00:00` (ISO-8601 with seconds and
 * explicit UTC offset).
 *
 * Native `Date.toISOString()` produces `…Z` with milliseconds; we normalise
 * to the Python-compatible shape that the Flutter client originally parsed
 * during the GitHub-Actions era. Keeping a single string format across all
 * outputs avoids client-side double-parsing logic.
 */
export function isoUtcSeconds(d) {
  return d.toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

// === Numeric helpers ========================================================

/**
 * Round `n` to `decimals` digits using half-away-from-zero behaviour.
 *
 * `Math.round((n * 10**decimals)) / 10**decimals` is enough for the
 * precision we care about (FX rates, percentages) and avoids pulling in a
 * decimal library for what's effectively presentation rounding.
 */
export function roundTo(n, decimals) {
  const f = Math.pow(10, decimals);
  return Math.round(n * f) / f;
}

// === HTTP =================================================================

const DEFAULT_USER_AGENT =
  "Mozilla/5.0 (compatible; BitcoinDashboardBot/1.0; +https://bitcoin-dashboard.app)";

/**
 * GET `url` and return the parsed JSON body. Throws on non-2xx.
 *
 * `extraHeaders` lets callers add API-specific bits (e.g. CoinGecko's
 * `x-cg-demo-api-key`) without re-implementing the boilerplate.
 *
 * Note: this helper deliberately does not retry. Worker cron triggers
 * already fire on a schedule, and any retry budget worth having should be
 * orchestrated at the task level (per-feed, per-range) so a stuck retry
 * loop cannot starve other independent units of work.
 */
export async function getJson(url, extraHeaders = {}) {
  const res = await fetch(url, {
    headers: {
      Accept: "application/json",
      "User-Agent": DEFAULT_USER_AGENT,
      ...extraHeaders,
    },
  });
  if (!res.ok) {
    throw new Error(`GET ${url} failed: HTTP ${res.status}`);
  }
  return res.json();
}

/**
 * GET `url` and return the response body as text.
 *
 * Used for XML (ECB feed) and RSS bodies. The Worker runtime decodes the
 * payload to a JS string using whatever charset the response declares.
 */
export async function getText(url, extraHeaders = {}) {
  const res = await fetch(url, {
    headers: {
      "User-Agent": DEFAULT_USER_AGENT,
      ...extraHeaders,
    },
  });
  if (!res.ok) {
    throw new Error(`GET ${url} failed: HTTP ${res.status}`);
  }
  return res.text();
}

// === R2 ===================================================================

/**
 * Serialise `payload` to JSON and write it to the R2 bucket bound as
 * `env.BUCKET`. All Workers publish under the same bucket; the key fully
 * determines the public CDN URL.
 *
 * `cacheControl` is forwarded as the object's `Cache-Control` header so the
 * Cloudflare CDN respects the per-file freshness policy.
 */
export async function putJson(env, key, payload, cacheControl) {
  await env.BUCKET.put(key, JSON.stringify(payload), {
    httpMetadata: {
      contentType: "application/json",
      cacheControl,
    },
  });
}

// === Text normalisation (news pipeline) =====================================

/**
 * NFKD + strip combining marks + lowercase. Used everywhere we want a
 * diacritic-insensitive substring match — `Bärenmarkt` and `barenmarkt`
 * fold to the same string, plain ASCII passes through unchanged.
 *
 * We use the Unicode-property regex `\p{M}` to cover the full set of
 * combining marks, not just the basic Latin block. This is safer than the
 * literal `[̀-ͯ]` form that earlier copies of the news Worker shipped:
 * code-formatters and editors occasionally garble that literal range.
 */
export function fold(text) {
  return text.normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase();
}

// === Regex helpers (news pipeline) ==========================================

const REGEX_META = /[.*+?^${}()|[\]\\]/g;

function escRegExp(s) {
  return s.replace(REGEX_META, "\\$&");
}

/**
 * Compile a word-bounded alternation regex over a list of keywords.
 *
 * Returns an object with two regexes — one global (for counting matches)
 * and one non-global (for boolean tests). This split avoids the classic
 * `RegExp.lastIndex` footgun where calling `.test()` on a `/g` regex
 * mutates state across calls.
 *
 * Word boundaries on both sides prevent `up` from matching `upgrade` or
 * `supply` — a real source of sentiment noise in the early prototype.
 * Multi-word keywords like `bitcoin core` work fine because `\b` only
 * requires a word/non-word transition.
 */
export function compileAlternation(keywords) {
  const escaped = keywords.map((k) => escRegExp(fold(k)));
  const pattern = `\\b(?:${escaped.join("|")})\\b`;
  return {
    test: new RegExp(pattern),
    count: new RegExp(pattern, "g"),
  };
}

/**
 * Count matches of a `/g` regex against `text`.
 *
 * Resets `lastIndex` defensively even though the helper above always
 * exposes the count regex via a fresh object — cheap insurance against a
 * caller stashing the regex elsewhere.
 */
export function countMatches(re, text) {
  re.lastIndex = 0;
  const m = text.match(re);
  return m ? m.length : 0;
}

// === Hashing (news pipeline) ================================================

/**
 * SHA-1 hex digest of an input string. Used for stable per-news-item IDs
 * (truncated to 16 hex chars by callers) and not for any cryptographic
 * security concern — collision resistance on 64-bit prefixes is plenty
 * for deduplicating ~50 items per language.
 */
export async function sha1Hex(input) {
  const buf = await crypto.subtle.digest(
    "SHA-1",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// === HTML & entity decoding (news pipeline) ================================

const HTML_TAG_RE = /<[^>]*>/g;
const WS_RE = /\s+/g;

// Named-entity subset we explicitly handle. Anything else falls through as
// the raw `&name;` form — acceptable for plain-text rendering in the
// Flutter UI, which doesn't interpret HTML anyway.
const HTML_ENTITY_MAP = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  auml: "ä", ouml: "ö", uuml: "ü", Auml: "Ä", Ouml: "Ö", Uuml: "Ü",
  szlig: "ß",
};

/**
 * Decode a small set of HTML entities + numeric character references.
 *
 * Feed bodies arrive with mixed entity escaping conventions; this is the
 * smallest decoder that covers what publishers in our curated feed list
 * actually emit. We do not parse HTML — `stripHtml` does that.
 */
export function decodeEntities(s) {
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

/**
 * Reduce an HTML fragment to a single line of plain text.
 *
 * Order matters: strip tags first (so `&lt;script&gt;` survives as literal
 * text rather than being mistaken for a tag), then decode entities, then
 * collapse whitespace. Empty input returns empty string.
 */
export function stripHtml(text) {
  if (!text) return "";
  const noTags = text.replace(HTML_TAG_RE, " ");
  const decoded = decodeEntities(noTags);
  return decoded.replace(WS_RE, " ").trim();
}
