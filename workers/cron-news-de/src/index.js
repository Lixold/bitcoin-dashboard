// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: DE Bitcoin news aggregator.
//
// Thin language shell around the shared news pipeline. See cron-news-en
// for the architectural rationale; only the feed list and lexicon below
// differ between languages.
//
// All keyword strings are lowercase and diacritic-free. The matcher
// Unicode-folds both keyword and haystack before comparing, so
// "Bärenmarkt" / "barenmarkt" / "BAERENMARKT" all hit the same entry.

import { runNewsPipeline } from "../../_shared/news_pipeline.js";

const FEEDS = [
  ["Blocktrainer", "https://www.blocktrainer.de/feed/"],
  ["BitcoinBlog.de", "https://bitcoinblog.de/feed/"],
  ["BTC-ECHO", "https://www.btc-echo.de/feed/"],
  ["CryptoMonday", "https://cryptomonday.de/feed/"],
];

const LEXICON = {
  positive: [
    "anstieg", "gewinne", "rally", "bullenmarkt", "hoch",
    "wachstum", "adoption",
  ],
  negative: [
    "crash", "absturz", "verlust", "barenmarkt", "ruckgang",
    "sorge", "risiko",
  ],
  tags: {
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
  },
};

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      runNewsPipeline({ lang: "de", feeds: FEEDS, lexicon: LEXICON }, env),
    );
  },
};
