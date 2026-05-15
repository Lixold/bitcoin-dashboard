// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: EN Bitcoin news aggregator.
//
// Thin language shell around the shared news pipeline. Everything that is
// not English-specific (RSS parsing, sentiment classifier, dedup, R2
// upload) lives in `workers/_shared/news_pipeline.js` — keep this file
// limited to the EN feed list and the EN keyword lexicon.
//
// The "one Worker per language" topology is preserved deliberately so each
// language keeps its own ~10 ms CPU budget on the Cloudflare Free tier
// (see ADR-0003). Adding a new language means a new dünner Worker with
// its own config, not a fatter pipeline.

import { runNewsPipeline } from "../../_shared/news_pipeline.js";

const FEEDS = [
  ["Bitcoin Magazine", "https://bitcoinmagazine.com/feed"],
  ["Cointelegraph", "https://cointelegraph.com/rss"],
  ["The Block", "https://www.theblock.co/rss.xml"],
  // Root /feed/ rather than /category/bitcoin/feed/ — the category feed
  // is currently empty; off-topic items from the root feed are filtered
  // out by the Bitcoin keyword filter inside the pipeline.
  ["NewsBTC", "https://www.newsbtc.com/feed/"],
  ["CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml"],
];

const LEXICON = {
  positive: [
    "surge", "jump", "gain", "rally", "bull", "bullish",
    "up", "rise", "growth", "adoption",
  ],
  negative: [
    "crash", "fall", "drop", "decline", "bear", "bearish",
    "down", "loss", "concern", "risk",
  ],
  tags: {
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
  },
};

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      runNewsPipeline({ lang: "en", feeds: FEEDS, lexicon: LEXICON }, env),
    );
  },
};
