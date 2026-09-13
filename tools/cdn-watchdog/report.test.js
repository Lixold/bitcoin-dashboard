// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for what the watchdog says and when it says it again.
//
// The load-bearing test in here is the first one: an hourly job that
// re-comments every run is worse than no job, because the reader learns
// to scroll past it. The fingerprint is what stops that, so it is tested
// against exactly the thing that changes every run — the measured age.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import {
  CLEAR_FINGERPRINT,
  ISSUE_TITLE,
  fingerprint,
  readFingerprint,
  renderLogLine,
  renderRecovery,
  renderReport,
  violations,
} from "./report.js";

const NOW = new Date("2026-09-13T20:25:00Z");

const clean = (key) => ({ key, path: `data/${key}.json`, findings: [] });

const failing = (key, findings) => ({
  key,
  path: `data/${key}.json`,
  findings,
});

const stale = (detail) => ({
  mode: "stale",
  checkId: "freshness:fetchedAt",
  detail,
});

const thin = (detail) => ({ mode: "thin", checkId: "volume:news", detail });

describe("fingerprint", () => {
  it("is the same when only the measured age has moved on", () => {
    const first = [failing("market", [stale("fetchedAt is 61 min old")])];
    const second = [failing("market", [stale("fetchedAt is 121 min old")])];
    assert.equal(fingerprint(first), fingerprint(second));
  });

  it("changes when another payload starts failing too", () => {
    const before = [failing("market", [stale("x")]), clean("news-en")];
    const after = [
      failing("market", [stale("x")]),
      failing("news-en", [thin("y")]),
    ];
    assert.notEqual(fingerprint(before), fingerprint(after));
  });

  it("changes when the same payload fails in a different mode", () => {
    assert.notEqual(
      fingerprint([failing("market", [stale("x")])]),
      fingerprint([failing("market", [thin("x")])]),
    );
  });

  it("does not depend on the order findings arrive in", () => {
    const a = [failing("market", [stale("x")]), failing("news-en", [thin("y")])];
    const b = [failing("news-en", [thin("y")]), failing("market", [stale("x")])];
    assert.equal(fingerprint(a), fingerprint(b));
  });

  it("is the clear marker when nothing fails", () => {
    assert.equal(fingerprint([clean("market"), clean("news-en")]), CLEAR_FINGERPRINT);
  });
});

describe("readFingerprint", () => {
  it("recovers what renderReport wrote", () => {
    const results = [failing("market", [stale("x")]), clean("news-en")];
    const body = renderReport(results, NOW);
    assert.equal(readFingerprint(body), fingerprint(results));
  });

  it("recovers the clear marker from a recovery comment", () => {
    const body = renderRecovery([clean("market")], NOW);
    assert.equal(readFingerprint(body), CLEAR_FINGERPRINT);
  });

  it("returns null for text that carries no marker", () => {
    assert.equal(readFingerprint("just a human comment"), null);
    assert.equal(readFingerprint(undefined), null);
  });
});

describe("renderReport", () => {
  const results = [
    failing("market", [stale("fetchedAt is 3.0 d old, over the 45 min allowed")]),
    failing("news-en", [thin("news carries 0, floor is 2")]),
    failing("fx-rates", [
      { mode: "unreachable", checkId: "fetch", detail: "HTTP 502" },
    ]),
    clean("history-1D"),
  ];
  const body = renderReport(results, NOW);

  it("counts the failures against the whole table", () => {
    assert.match(body, /3 of 4 published payloads failed/);
  });

  it("names both failure modes the issue asks about, and keeps them apart", () => {
    assert.match(body, /Failure mode 1 — stale timestamp/);
    assert.match(body, /Failure mode 2 — fresh timestamp, collapsed content/);
    assert.match(body, /Unreachable — the file did not arrive/);
  });

  it("says where to look for each mode", () => {
    assert.match(body, /Look at the Worker's cron/);
    assert.match(body, /Look at the source, not at the Worker/);
  });

  it("lists what passed, so the scope of the outage is visible", () => {
    assert.match(body, /Passing: `history-1D`/);
  });

  it("points at the one file the thresholds live in", () => {
    assert.match(body, /tools\/cdn-watchdog\/payloads\.js/);
  });

  it("marks a run that did not read the CDN as not a real alarm", () => {
    const proof = renderReport(results, NOW, { source: "fixture-broken" });
    assert.match(proof, /This is not a real alarm/);
    assert.doesNotMatch(body, /This is not a real alarm/);
  });
});

describe("renderRecovery", () => {
  const body = renderRecovery([clean("market"), clean("news-en")], NOW);

  it("says everything passes again", () => {
    assert.match(body, /All 2 published payloads passed/);
  });

  it("says why the issue stays open", () => {
    assert.match(body, /for a person to confirm/);
  });
});

describe("renderLogLine", () => {
  it("is one quiet line when everything passes", () => {
    assert.match(renderLogLine([clean("market")], NOW), /all 1 payloads pass/);
  });

  it("names the failing payloads and their modes", () => {
    const line = renderLogLine(
      [failing("market", [stale("x")]), failing("news-en", [thin("y")])],
      NOW,
    );
    assert.match(line, /2\/2 failing: market\(stale\) news-en\(empty\)/);
  });
});

describe("violations", () => {
  it("keeps table order so two runs read the same way", () => {
    const results = [
      clean("market"),
      failing("news-en", [thin("x")]),
      failing("news-de", [thin("y")]),
    ];
    assert.deepEqual(
      violations(results).map((r) => r.key),
      ["news-en", "news-de"],
    );
  });
});

describe("the issue title", () => {
  it("carries no timestamp or count, because it is the deduplication key", () => {
    assert.doesNotMatch(ISSUE_TITLE, /\d/);
  });
});
