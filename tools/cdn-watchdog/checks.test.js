// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the watchdog's judgement. Offline by construction: every
// case is either a hand-built payload or the committed capture from
// 2026-09-13, and `now` is always passed in rather than read, so nothing
// here drifts with the day the suite runs on.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  ageMs,
  allPresent,
  at,
  checkFreshness,
  currencyMatrix,
  evaluateAll,
  evaluatePayload,
  humanAge,
  minItems,
  sameLength,
  selfCount,
} from "./checks.js";
import {
  DAILY_MAX_AGE,
  FAST_MAX_AGE,
  FX_SOURCE_MAX_AGE,
  HOUR,
  MINUTE,
  PAYLOADS,
} from "./payloads.js";

const FIXTURES = join(
  dirname(fileURLToPath(import.meta.url)),
  "fixtures",
  "cdn-2026-09-13",
);

const capture = (key) =>
  JSON.parse(readFileSync(join(FIXTURES, `${key}.json`), "utf8"));

/** Ten minutes after the capture's own `fetchedAt`. */
const CAPTURE_NOW = new Date("2026-09-13T20:25:00Z");

describe("at", () => {
  it("walks a nested path", () => {
    assert.equal(at({ _meta: { fetchedAt: "x" } }, ["_meta", "fetchedAt"]), "x");
  });

  it("returns undefined rather than throwing when a hop is missing", () => {
    assert.equal(at({}, ["_meta", "fetchedAt"]), undefined);
    assert.equal(at({ _meta: null }, ["_meta", "fetchedAt"]), undefined);
    assert.equal(at({ _meta: 7 }, ["_meta", "fetchedAt"]), undefined);
  });
});

describe("ageMs", () => {
  const now = new Date("2026-09-13T12:00:00Z");

  it("measures an ISO timestamp", () => {
    assert.equal(ageMs("2026-09-13T11:00:00+00:00", now), HOUR);
  });

  it("reads a date-only value as midnight UTC of that day", () => {
    // The anchor FX_SOURCE_MAX_AGE is calibrated against.
    assert.equal(ageMs("2026-09-13", now), 12 * HOUR);
  });

  it("returns null, never NaN, for a value that is not a timestamp", () => {
    // The whole point: NaN > threshold is false, so a NaN age would wave
    // a broken payload through as healthy.
    for (const bad of [undefined, null, 17, {}, "", "not a date"]) {
      assert.equal(ageMs(bad, now), null, `for ${JSON.stringify(bad)}`);
    }
  });
});

describe("checkFreshness", () => {
  const now = new Date("2026-09-13T20:25:00Z");

  it("reads a top-level fetchedAt", () => {
    const rule = [{ at: ["fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" }];
    assert.deepEqual(
      checkFreshness({ fetchedAt: "2026-09-13T20:15:00+00:00" }, rule, now),
      [],
    );
  });

  it("reads a _meta.fetchedAt", () => {
    const rule = [
      { at: ["_meta", "fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" },
    ];
    assert.deepEqual(
      checkFreshness(
        { _meta: { fetchedAt: "2026-09-13T20:15:00+00:00" } },
        rule,
        now,
      ),
      [],
    );
  });

  it("does not look for the other shape's timestamp", () => {
    // A payload carrying only _meta.fetchedAt, checked with a rule that
    // points at the top level, must be reported — not silently accepted
    // because some heuristic found the other one.
    const rule = [{ at: ["fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" }];
    const findings = checkFreshness(
      { _meta: { fetchedAt: "2026-09-13T20:15:00+00:00" } },
      rule,
      now,
    );
    assert.equal(findings.length, 1);
    assert.equal(findings[0].mode, "stale");
    assert.match(findings[0].detail, /fetchedAt is missing/);
  });

  it("is quiet exactly at the threshold and speaks one millisecond past it", () => {
    const rule = [{ at: ["fetchedAt"], maxAge: FAST_MAX_AGE, watches: "producer" }];
    const exactly = new Date(now.getTime() - FAST_MAX_AGE).toISOString();
    const justOver = new Date(now.getTime() - FAST_MAX_AGE - 1).toISOString();
    assert.deepEqual(checkFreshness({ fetchedAt: exactly }, rule, now), []);
    assert.equal(checkFreshness({ fetchedAt: justOver }, rule, now).length, 1);
  });

  it("names which of the two questions a rule answers", () => {
    const rules = [
      { at: ["_meta", "fetchedAt"], maxAge: DAILY_MAX_AGE, watches: "producer" },
      { at: ["_meta", "date"], maxAge: FX_SOURCE_MAX_AGE, watches: "source" },
    ];
    const findings = checkFreshness(
      { _meta: { fetchedAt: "2026-09-01T16:15:00+00:00", date: "2026-09-01" } },
      rules,
      now,
    );
    assert.equal(findings.length, 2);
    assert.match(findings[0].detail, /for the producer/);
    assert.match(findings[1].detail, /for the source/);
  });
});

describe("the fx source threshold", () => {
  const rule = [
    { at: ["_meta", "date"], maxAge: FX_SOURCE_MAX_AGE, watches: "source" },
  ];
  const check = (date, nowIso) =>
    checkFreshness({ _meta: { date } }, rule, new Date(nowIso));

  // Every row is a gap the ECB takes on purpose. A watchdog that fires on
  // any of them gets muted, and then it protects nothing.
  it("survives an ordinary weekend", () => {
    // Published Fri 11.09., still the newest value at Mon 16:14 UTC.
    assert.deepEqual(check("2026-09-11", "2026-09-14T16:14:00Z"), []);
  });

  it("survives a weekend followed by a TARGET holiday", () => {
    // Same Friday, next publication only on Tuesday — 112 h.
    assert.deepEqual(check("2026-09-11", "2026-09-15T16:14:00Z"), []);
  });

  it("survives Easter, the longest closure in the calendar", () => {
    // Good Friday 26.03.2027, Easter Monday 29.03.2027: published Thu
    // 25.03., next value Tue 30.03. — 136 h, the worst legitimate gap.
    assert.deepEqual(check("2027-03-25", "2027-03-30T16:14:00Z"), []);
  });

  it("reports a source that has genuinely stopped", () => {
    const findings = check("2026-09-11", "2026-09-18T00:00:00Z");
    assert.equal(findings.length, 1);
    assert.equal(findings[0].mode, "stale");
  });

  it("holds the boundary at six days", () => {
    const base = new Date("2026-09-11T00:00:00Z").getTime();
    assert.deepEqual(
      check("2026-09-11", new Date(base + FX_SOURCE_MAX_AGE).toISOString()),
      [],
    );
    assert.equal(
      check("2026-09-11", new Date(base + FX_SOURCE_MAX_AGE + 1).toISOString())
        .length,
      1,
    );
  });
});

describe("minItems", () => {
  const check = minItems(["news"], 2);

  it("passes on the floor and above it", () => {
    assert.equal(check({ news: [1, 2] }), null);
    assert.equal(check({ news: [1, 2, 3] }), null);
  });

  it("reports below the floor, and says both numbers", () => {
    const finding = check({ news: [1] });
    assert.equal(finding.mode, "thin");
    assert.match(finding.detail, /carries 1, floor is 2/);
  });

  it("reports an empty list", () => {
    assert.equal(check({ news: [] }).mode, "thin");
  });

  it("reports a value that is not a list at all", () => {
    assert.match(check({ news: null }).detail, /not an array/);
    assert.match(check({}).detail, /not an array/);
  });
});

describe("sameLength", () => {
  const check = sameLength(["timestamps"], ["prices"]);

  it("passes when both arrays match", () => {
    assert.equal(check({ timestamps: [1, 2], prices: [3, 4] }), null);
  });

  it("catches the off-by-one a floor would wave through", () => {
    const finding = check({ timestamps: [1, 2, 3], prices: [1, 2] });
    assert.equal(finding.mode, "thin");
    assert.match(finding.detail, /has 3 entries.*has 2/);
  });
});

describe("allPresent", () => {
  const check = allPresent([["marketCap"], ["ath"], ["fullNodes", "count"]]);

  it("passes when every path holds a value", () => {
    assert.equal(check({ marketCap: 1, ath: 2, fullNodes: { count: 3 } }), null);
  });

  it("passes on zero, which is a value", () => {
    assert.equal(check({ marketCap: 0, ath: 0, fullNodes: { count: 0 } }), null);
  });

  it("names every null and missing path at once", () => {
    const finding = check({ marketCap: null, ath: 2, fullNodes: {} });
    assert.equal(finding.mode, "thin");
    assert.match(finding.detail, /marketCap/);
    assert.match(finding.detail, /fullNodes\.count/);
    assert.doesNotMatch(finding.detail, /ath/);
  });
});

describe("selfCount", () => {
  const check = selfCount(["news"], ["_meta", "itemCount"]);

  it("passes when head and body agree", () => {
    assert.equal(check({ news: [1, 2], _meta: { itemCount: 2 } }), null);
  });

  it("reports a producer that wrote two different answers", () => {
    const finding = check({ news: [1, 2], _meta: { itemCount: 7 } });
    assert.equal(finding.mode, "thin");
    assert.match(finding.detail, /says 7.*carries 2/);
  });

  it("stays quiet when the payload makes no claim to check", () => {
    // Absent self-report is a schema question, and that is #42's.
    assert.equal(check({ news: [1, 2], _meta: {} }), null);
  });
});

describe("currencyMatrix", () => {
  const check = currencyMatrix(2);
  const square = {
    _meta: { currencies: ["EUR", "USD"] },
    EUR: { EUR: 1, USD: 1.1 },
    USD: { EUR: 0.9, USD: 1 },
  };

  it("passes a complete square matrix", () => {
    assert.equal(check(square), null);
  });

  it("reports too few currencies", () => {
    const finding = check({ _meta: { currencies: ["EUR"] }, EUR: { EUR: 1 } });
    assert.match(finding.detail, /lists 1, floor is 2/);
  });

  it("reports a row the header announced but the body does not carry", () => {
    const { USD, ...missingRow } = square;
    assert.match(check(missingRow).detail, /announced but absent: \[USD\]/);
  });

  it("reports a short row", () => {
    const finding = check({ ...square, USD: { USD: 1 } });
    assert.match(finding.detail, /row USD has 1 rates, expected 2/);
  });

  it("reports a self-rate that is not 1", () => {
    const finding = check({ ...square, USD: { EUR: 0.9, USD: 1.02 } });
    assert.match(finding.detail, /USD\/USD is 1.02/);
  });
});

describe("evaluatePayload", () => {
  const config = PAYLOADS.find((p) => p.key === "market");

  it("reports a file that did not arrive, and checks nothing else", () => {
    const findings = evaluatePayload(
      config,
      { ok: false, reason: "HTTP 404" },
      CAPTURE_NOW,
    );
    assert.equal(findings.length, 1);
    assert.equal(findings[0].mode, "unreachable");
    assert.equal(findings[0].detail, "HTTP 404");
  });

  it("reports staleness and thinness together when both are true", () => {
    const findings = evaluatePayload(
      config,
      {
        ok: true,
        json: {
          fetchedAt: "2026-09-01T00:00:00+00:00",
          marketCap: null,
          volume24h: null,
          ath: null,
          athDate: null,
        },
      },
      CAPTURE_NOW,
    );
    assert.deepEqual(
      findings.map((f) => f.mode),
      ["stale", "thin"],
    );
  });
});

describe("the configuration table", () => {
  it("covers every payload the CDN publishes, once", () => {
    const keys = PAYLOADS.map((p) => p.key);
    assert.deepEqual(keys, [
      "market",
      "history-1D",
      "history-1W",
      "history-1M",
      "history-3M",
      "history-1Y",
      "fx-rates",
      "news-en",
      "news-de",
      "network-health",
    ]);
    assert.equal(new Set(keys).size, keys.length);
  });

  it("gives every payload a timestamp location and at least one volume check", () => {
    for (const payload of PAYLOADS) {
      assert.ok(payload.freshness.length > 0, `${payload.key} freshness`);
      assert.ok(payload.volume.length > 0, `${payload.key} volume`);
      assert.equal(payload.path, `data/${payload.key}.json`);
    }
  });
});

describe("the captured payloads of 2026-09-13", () => {
  const fetched = Object.fromEntries(
    PAYLOADS.map((p) => [p.key, { ok: true, json: capture(p.key) }]),
  );
  const results = evaluateAll(PAYLOADS, fetched, CAPTURE_NOW);
  const byKey = Object.fromEntries(results.map((r) => [r.key, r.findings]));

  it("passes every threshold for the nine healthy files", () => {
    for (const key of Object.keys(byKey)) {
      if (key === "network-health") continue;
      assert.deepEqual(byKey[key], [], `${key} should be clean`);
    }
  });

  it("catches the null node count that was live at capture time", () => {
    // This is #29's breakage, fixed in #101 but not yet deployed when the
    // capture was taken: `fullNodes.count` is null while `_meta.fetchedAt`
    // is well inside 26 h. Failure mode 2 exactly — and the reason the
    // watchdog must not be armed before that Worker has run once.
    const findings = byKey["network-health"];
    assert.equal(findings.length, 1);
    assert.equal(findings[0].mode, "thin");
    assert.match(findings[0].detail, /fullNodes\.count/);
  });
});

describe("the two failure modes the Definition of Done names", () => {
  it("reports an artificially old timestamp", () => {
    const json = capture("market");
    json.fetchedAt = "2026-09-10T20:15:11+00:00";
    const [result] = evaluateAll(
      [PAYLOADS.find((p) => p.key === "market")],
      { market: { ok: true, json } },
      CAPTURE_NOW,
    );
    assert.equal(result.findings.length, 1);
    assert.equal(result.findings[0].mode, "stale");
    assert.match(result.findings[0].detail, /over the 45 min allowed/);
  });

  it("reports an artificially emptied payload whose timestamp is current", () => {
    const json = capture("news-en");
    json.news = [];
    json._meta.itemCount = 0;
    const [result] = evaluateAll(
      [PAYLOADS.find((p) => p.key === "news-en")],
      { "news-en": { ok: true, json } },
      CAPTURE_NOW,
    );
    // The timestamp is untouched and inside the window — only the volume
    // check can see this, which is the whole argument of #43.
    assert.deepEqual(
      result.findings.map((f) => f.mode),
      ["thin"],
    );
    assert.match(result.findings[0].detail, /carries 0, floor is 2/);
  });

  it("reports a history file whose two arrays drifted apart", () => {
    const json = capture("history-1D");
    json.prices = json.prices.slice(0, -1);
    const [result] = evaluateAll(
      [PAYLOADS.find((p) => p.key === "history-1D")],
      { "history-1D": { ok: true, json } },
      CAPTURE_NOW,
    );
    assert.equal(result.findings.length, 1);
    assert.match(result.findings[0].detail, /has 288 entries.*has 287/);
  });
});

describe("humanAge", () => {
  it("uses the largest unit that still reads precisely", () => {
    assert.equal(humanAge(45 * MINUTE), "45 min");
    assert.equal(humanAge(2 * HOUR), "2.0 h");
    assert.equal(humanAge(26 * HOUR), "26.0 h");
    assert.equal(humanAge(72 * HOUR), "3.0 d");
  });
});

describe("the deliberately broken source", () => {
  it("injures exactly one payload per failure mode and leaves the rest alone", async () => {
    // Importing run.js must not set a live run going — the guard at the
    // bottom of that file is what this exercises alongside the injuries.
    const { brokenFixtures } = await import("./run.js");
    const fetched = brokenFixtures(PAYLOADS, CAPTURE_NOW);
    const results = evaluateAll(PAYLOADS, fetched, CAPTURE_NOW);
    const modes = Object.fromEntries(
      results.map((r) => [r.key, r.findings.map((f) => f.mode)]),
    );

    assert.deepEqual(modes["market"], ["stale"]);
    assert.deepEqual(modes["news-en"], ["thin"]);
    // network-health carries the capture's own null node count; every
    // other file is served untouched, so a proof run also shows that the
    // healthy ones stay quiet.
    assert.deepEqual(modes["network-health"], ["thin"]);
    for (const key of ["history-1D", "history-3M", "fx-rates", "news-de"]) {
      assert.deepEqual(modes[key], [], key);
    }
  });
});
