// MIT License — Copyright (c) 2026 Daniel Nagel
//
// The watchdog's configuration table: every file published to the CDN,
// where its timestamp lives, how old it may get, and how much content it
// must carry.
//
// **This is the canonical list.** A new published payload is not watched
// until it appears here, and nothing else in this tool enumerates the
// files. Adding a Worker output means adding a row.
//
// Two things in here are easy to get wrong and are therefore declared
// rather than guessed:
//
//   1. The timestamp is not in the same place in every file. `market.json`
//      and the `history-*.json` set carry it top-level as `fetchedAt`;
//      `fx-rates.json`, `news-*.json` and `network-health.json` carry it
//      as `_meta.fetchedAt`. A heuristic that tries both reads `undefined`
//      for the shape it does not expect, turns that into an age of `NaN`,
//      and `NaN > threshold` is `false` — the file would be waved through
//      as healthy. So the location is per-file configuration.
//
//   2. `fx-rates.json` has two ages and only one of them is about the
//      Worker. See FX_SOURCE_MAX_AGE below.

import {
  allPresent,
  currencyMatrix,
  minItems,
  sameLength,
  selfCount,
} from "./checks.js";

export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;

// === Freshness thresholds ==================================================

/**
 * Age at which a 15-minute payload counts as silent.
 *
 * The same 45 minutes the app uses as `marketStaleAge` in
 * `lib/features/price/domain/market_snapshot.dart` — three missed runs.
 * One number for one cadence, written down in two languages rather than
 * two numbers for the same fact.
 */
export const FAST_MAX_AGE = 45 * MINUTE;

/**
 * Age at which a daily payload counts as silent.
 *
 * The same 26 hours the app uses as `stalePayloadAge` in
 * `lib/features/network/domain/network_health_snapshot.dart` — one
 * certainly-missed run plus two hours of slack.
 */
export const DAILY_MAX_AGE = 26 * HOUR;

/**
 * Age at which the *ECB* — not the Worker — counts as silent.
 *
 * `cron-fx-rates` rewrites the file every day with a fresh
 * `_meta.fetchedAt` whether or not the ECB published anything new, so
 * that timestamp only proves the Worker ran. `_meta.date` is the ECB's
 * own reference day and is the only value in the file that would notice
 * the source going quiet.
 *
 * The number has to clear every *scheduled* gap, because a watchdog that
 * cries on a bank holiday gets muted and then it protects nothing. The
 * gaps, measured from midnight UTC of the last published day (the date is
 * day-granular, so that is the only anchor it offers) to the last moment
 * the stale value is still legitimately on the CDN — 16:14 UTC, one
 * minute before the Worker's 16:15 run picks the new day up:
 *
 * | Closure | Last published | Seen until | Gap |
 * |---|---|---|---|
 * | Ordinary weekend | Fri | Mon 16:14 | 88 h |
 * | Weekend + TARGET Monday | Fri | Tue 16:14 | 112 h |
 * | Christmas 2026 (25th Fri, 26th Sat) | Thu 24th | Mon 28th 16:14 | 112 h |
 * | Easter 2027 (Good Fri 26.3., Easter Mon 29.3.) | Thu 25th | Tue 30th 16:14 | 136 h |
 *
 * So 144 h — six days. The handover for #43 proposed 100 h on the
 * assumption that the gap is measured from the ECB's publication hour;
 * measured from the only anchor the payload actually carries, 100 h fires
 * on every TARGET-holiday Monday. Raising the number is what that
 * decision's own abort criterion asks for, and it is preferred to
 * carrying a TARGET holiday calendar that would itself go stale.
 *
 * What this costs: an ECB outage is reported within six days instead of
 * one. What it does not cost: a dead Worker is still caught in 26 hours
 * by `_meta.fetchedAt`, which is the far likelier failure.
 */
export const FX_SOURCE_MAX_AGE = 144 * HOUR;

// === The table =============================================================

/**
 * Volume floors sit below the readings measured live on 2026-09-13 with
 * room for normal variation; the `history-*` densities have been stable
 * since the 2026-08-30 reading in #43. They are floors, not equality
 * checks — ADR-0005 does not guarantee the counts constant.
 */
export const PAYLOADS = [
  {
    key: "market",
    path: "data/market.json",
    freshness: [{ at: ["fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" }],
    // No array to count. The four scalars the price screen reports are
    // the volume signal: CoinGecko answering with nulls is this file's
    // version of collapsing.
    volume: [allPresent([["marketCap"], ["volume24h"], ["ath"], ["athDate"]])],
  },
  ...historyRow("1D", 200),
  ...historyRow("1W", 120),
  ...historyRow("1M", 500),
  ...historyRow("3M", 1500),
  ...historyRow("1Y", 300),
  {
    key: "fx-rates",
    path: "data/fx-rates.json",
    freshness: [
      { at: ["_meta", "fetchedAt"], maxAge: DAILY_MAX_AGE, watches: "producer" },
      {
        at: ["_meta", "date"],
        maxAge: FX_SOURCE_MAX_AGE,
        watches: "source",
        anchor: "date",
      },
    ],
    // The matrix check also holds `_meta.currencies` against the rows
    // that are actually in the file, so the header-vs-body consistency
    // `selfCount` gives the news files is covered here too.
    volume: [currencyMatrix(25)],
  },
  ...newsRow("en"),
  ...newsRow("de"),
  {
    key: "network-health",
    path: "data/network-health.json",
    freshness: [
      { at: ["_meta", "fetchedAt"], maxAge: DAILY_MAX_AGE, watches: "producer" },
    ],
    volume: [
      minItems(["miningPools"], 5),
      // `fullNodes.count` is checked but `percentChange24h` is not: since
      // #101 the Worker legitimately degrades the trend to "unknown" when
      // the 24h reference sits outside tolerance, and that is an honest
      // reading, not a collapse. A null *count* is the collapse — half the
      // network section has nothing to render.
      allPresent([["fullNodes", "count"]]),
    ],
  },
];

function historyRow(range, floor) {
  return [
    {
      key: `history-${range}`,
      path: `data/history-${range}.json`,
      freshness: [
        { at: ["fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" },
      ],
      volume: [
        // Equal length first: a mismatch is corruption the app would
        // render as a chart shifted against its own time axis, and #43
        // asks for it by name.
        sameLength(["timestamps"], ["prices"]),
        minItems(["timestamps"], floor),
      ],
    },
  ];
}

function newsRow(language) {
  return [
    {
      key: `news-${language}`,
      path: `data/news-${language}.json`,
      freshness: [
        { at: ["_meta", "fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" },
      ],
      volume: [
        // Two, not five. This floor reports a collapse, not a thin day:
        // the EN list has legitimately read 1, 3, 4, 5 and 24 over the
        // last fortnight, and a floor that fires on a quiet Sunday
        // teaches the reader to ignore the watchdog. What the *product*
        // needs the list to carry is a different number and a different
        // issue (#60).
        minItems(["news"], 2),
        selfCount(["news"], ["_meta", "itemCount"]),
      ],
    },
  ];
}
