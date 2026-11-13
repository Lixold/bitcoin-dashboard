# ADR-0006 — News: Bitcoin keyword filter, lexicon tagging, one Worker per language

- **Date:** 2026-05-10 (Workers deployed); recorded 2026-11-13
- **Status:** Accepted
- **Decider:** Lixold
- **Related:** [ADR-0002](0002-data-sources-and-apis.md),
  [ADR-0003](0003-backend-cloudflare-workers-r2.md),
  [ADR-0005](0005-static-json-api-via-cdn.md)

This ADR records a decision that was taken when the news Workers shipped
and until now lived only in the code and in a feature note. Nothing in it
changes behaviour.

## Context

The news section is meant to show Bitcoin news only, in the reader's
language, each item with a topic and a sentiment (functional requirements
F08.1, F08.7). The sources are public RSS feeds. In most languages the
well-known outlets are general crypto publications; a Bitcoin-only feed is
the exception (Bitcoin Magazine, Blocktrainer, BitcoinBlog.de). The feeds
have to be read on a schedule and published as static JSON, because there
is no server (ADR-0003, ADR-0005). The free Workers tier allows about 10 ms
of CPU per invocation (ADR-0003).

## Options considered

### Option A — Bitcoin-only feeds, no filter

Use only sources that publish nothing but Bitcoin. Simple, but there are too
few such sources per language to fill a feed, and the language plan
(15 languages, see [news feed sources](../research/news-feed-sources.md))
would stop at the first one that has none.

### Option B — Third-party sentiment and aggregation API

The feature note of 2026-05-06 planned per-article bullish/bearish labels
through CryptoPanic in a later phase. That adds an outbound dependency and
an API key to the pipeline, and its classification cannot be reproduced in a
test without the vendor.

### Option C — Keyword filter and per-language lexicon inside the Worker — chosen

Read the feeds, keep the items that mention Bitcoin, derive topic and
sentiment from word lists, and publish one JSON file per language.

## Decision

Option C, built as one shared pipeline with one thin Worker per language.

**Filter.** An item is kept when its title or description contains one of
`bitcoin`, `btc`, `satoshi` or `lightning` (`KEYWORD_FILTER` in
`workers/_shared/news_pipeline.js`). The text is Unicode-folded first, so
diacritics and case do not matter. "blockchain" is deliberately not a
keyword: it is too generic and lets general crypto news through.

**Sentiment.** Count the positive and the negative lexicon hits in title and
description. More positive hits give `positive`, more negative hits
`negative`, otherwise `neutral`. Matching is on whole words after folding
(`compileAlternation` in `workers/_shared/lib.js`).

**Topics.** Five tags — `regulation`, `technology`, `market`, `mining`,
`adoption` — each with its own word list. An item carries every tag whose
list it hits, or none.

**Per-language shells.** `workers/cron-news-<lang>/src/index.js` holds only
the feed list and the lexicon for its language and calls
`runNewsPipeline` from `workers/_shared/news_pipeline.js`. Everything that is
not language-specific — parsing, filtering, de-duplication, payload shape,
upload — lives in the shared pipeline. It reads at most 30 entries per feed,
drops items older than 24 hours, skips a feed that fails and publishes the
rest; a run fails only when every feed fails. A new language is a new
shell with its own `wrangler.toml`, its own payload `data/news-<lang>.json`
and a row in `tools/cdn-watchdog/payloads.js`; the app needs no release for a
language whose payload it already knows how to read.

**Rollout.** Languages go live in five waves — EN and DE; TR and PT-BR; ES,
FR and JA; ZH, KO and IT; AR, RU, HI, BN and UR — ordered by source quality
and reach. Bengali and Urdu have no usable source yet. The feeds per language
are listed in [news feed sources](../research/news-feed-sources.md).

## Consequences

**Positive**

- No extra host and no key: the pipeline calls the feeds and nothing else.
- Deterministic. Parsing, filtering and classification are pure functions
  with `node --test` coverage in `workers/_shared/*.test.js`; no test needs
  a vendor or the live feeds.
- One Worker per language keeps each language inside its own CPU budget
  and gives it its own failure domain: a broken feed in one language leaves
  the others published.
- Languages and feeds are added without an app release.

**Negative / risks**

- The lexicon is a coarse instrument. Word lists know nothing about negation
  or context, and short cues such as "up" or "down" carry little signal.
  Sentiment describes the wording of a headline, not the market, and the app
  must present it as that.
- The filter keeps general crypto articles that happen to mention Bitcoin and
  drops Bitcoin articles that avoid all four words.
- How many items a language publishes depends on its feed mix and the
  filter. The English feed has published as few as one item per run;
  a floor and a feed mix are a policy question tracked in issue #60.
- Every language needs its own word lists, ideally reviewed by a native
  speaker. German has them; further languages start without.

## Open questions

- [ ] Floor and feed mix for the news list (issue #60).
