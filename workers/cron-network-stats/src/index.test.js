// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the network-health aggregator. Covers the 2×2 grid of
// trend × pool-share states the dashboard surfaces, what the label says
// when one of the two dimensions has no reading at all, and the
// derivation that turns a page of BTC Nodes snapshots into that reading.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import {
  aggregateHealth,
  fullNodesFromSnapshots,
  trendLabel,
} from "./index.js";

describe("trendLabel", () => {
  it("flags up when percent change exceeds the +0.5% dead band", () => {
    assert.equal(trendLabel(1.0), "up");
    assert.equal(trendLabel(0.51), "up");
  });

  it("flags down when percent change exceeds the -0.5% dead band", () => {
    assert.equal(trendLabel(-1.0), "down");
    assert.equal(trendLabel(-0.51), "down");
  });

  it("returns stable inside the symmetric dead band", () => {
    // ±0.5% inclusive falls into "stable" — this is the anti-flapping
    // contract called out in the network-stats Worker.
    assert.equal(trendLabel(0), "stable");
    assert.equal(trendLabel(0.5), "stable");
    assert.equal(trendLabel(-0.5), "stable");
    assert.equal(trendLabel(0.3), "stable");
  });
});

describe("aggregateHealth", () => {
  it("returns good when no warning signal is present", () => {
    assert.equal(aggregateHealth(2.0, 25.0), "good");
    assert.equal(aggregateHealth(0.1, 28.0), "good");
  });

  it("returns warning on softly shrinking node count", () => {
    // Nodes drop within (-5%, 0) — soft warning, not critical.
    assert.equal(aggregateHealth(-2.5, 25.0), "warning");
    assert.equal(aggregateHealth(-0.1, 25.0), "warning");
  });

  it("returns critical when nodes drop more than 5%", () => {
    assert.equal(aggregateHealth(-5.1, 25.0), "critical");
    assert.equal(aggregateHealth(-10.0, 25.0), "critical");
  });

  it("returns warning when largest pool sits in 30–40 % concentration band", () => {
    assert.equal(aggregateHealth(1.0, 30.0), "warning");
    assert.equal(aggregateHealth(1.0, 35.0), "warning");
    assert.equal(aggregateHealth(1.0, 40.0), "warning");
  });

  it("returns critical when largest pool exceeds 40 %", () => {
    assert.equal(aggregateHealth(1.0, 40.1), "critical");
    assert.equal(aggregateHealth(1.0, 55.0), "critical");
  });

  it("critical from either dimension wins over warning from the other", () => {
    assert.equal(aggregateHealth(-10.0, 25.0), "critical");
    assert.equal(aggregateHealth(1.0, 45.0), "critical");
    // Both critical → still critical (no escalation beyond that).
    assert.equal(aggregateHealth(-10.0, 50.0), "critical");
  });

  it("says unknown instead of good when a dimension has no reading", () => {
    // #29: the node census was gone for weeks while this function read
    // "good" off the pool share alone. Only "good" claims something about
    // the whole picture, so only "good" gives way.
    assert.equal(aggregateHealth(null, 25.0), "unknown");
    assert.equal(aggregateHealth(2.0, null), "unknown");
    assert.equal(aggregateHealth(undefined, 25.0), "unknown");
    assert.equal(aggregateHealth(2.0, undefined), "unknown");
  });

  it("keeps the verdict of the dimension that did arrive", () => {
    // "unknown" must never swallow an alarm: a pool over the line is
    // critical whether or not the node count came in.
    assert.equal(aggregateHealth(null, 35.0), "warning");
    assert.equal(aggregateHealth(null, 45.0), "critical");
    assert.equal(aggregateHealth(-2.0, null), "warning");
    assert.equal(aggregateHealth(-10.0, null), "critical");
  });

  it("returns unknown when both dimensions are null (defensive contract)", () => {
    // In practice runAll() doesn't upload in this case, but nothing about
    // an empty input may come out sounding reassuring.
    assert.equal(aggregateHealth(null, null), "unknown");
  });
});

describe("fullNodesFromSnapshots", () => {
  // A fixed epoch, never Date.now(): the window is measured against the
  // newest snapshot in the page, so the assertions must not move with the
  // day the suite runs on.
  const now = 1_757_793_600; // 2026-09-13T20:00:00Z
  const HOUR = 3600;

  const snap = (offsetHours, totalNodes) => ({
    url: `https://btcnodes.io/api/v1/snapshots/${now - offsetHours * HOUR}/`,
    timestamp: now - offsetHours * HOUR,
    total_nodes: totalNodes,
    latest_height: 921_000,
  });

  it("derives the 24h change against the newest snapshot in the page", () => {
    const reading = fullNodesFromSnapshots([
      snap(0, 26_260),
      snap(12, 26_100),
      snap(24, 26_000),
      snap(36, 25_900),
    ]);

    assert.deepEqual(reading, {
      count: 26_260,
      percentChange24h: 1.0,
      trend: "up",
    });
  });

  it("reads newest-first regardless of the order the page arrives in", () => {
    // The upstream's ordering is a convention, not a documented promise.
    const reading = fullNodesFromSnapshots([
      snap(24, 26_000),
      snap(0, 26_260),
      snap(36, 25_900),
    ]);

    assert.equal(reading.count, 26_260);
    assert.equal(reading.percentChange24h, 1.0);
  });

  it("picks the snapshot closest to 24 h before the newest one", () => {
    // 20 h back is inside the 6 h tolerance and beats the 2 h-old entry.
    const reading = fullNodesFromSnapshots([
      snap(0, 26_260),
      snap(2, 26_250),
      snap(20, 26_000),
    ]);

    assert.equal(reading.percentChange24h, 1.0);
    assert.equal(reading.trend, "up");
  });

  it("reports the count with an unknown trend when the page stops short of 24 h", () => {
    // Reaching back only 4 h leaves the reference 20 h off target: the
    // count is still worth shipping, the change is not.
    const reading = fullNodesFromSnapshots([
      snap(0, 26_260),
      snap(2, 26_250),
      snap(4, 26_240),
    ]);

    assert.deepEqual(reading, {
      count: 26_260,
      percentChange24h: null,
      trend: "unknown",
    });
  });

  it("reports the count with an unknown trend from a single snapshot", () => {
    const reading = fullNodesFromSnapshots([snap(0, 26_260)]);

    assert.deepEqual(reading, {
      count: 26_260,
      percentChange24h: null,
      trend: "unknown",
    });
  });

  it("drops malformed entries rather than failing the whole reading", () => {
    const reading = fullNodesFromSnapshots([
      { timestamp: now, total_nodes: null },
      { timestamp: null, total_nodes: 99_999 },
      snap(0, 26_260),
      snap(24, 26_000),
    ]);

    assert.equal(reading.count, 26_260);
    assert.equal(reading.percentChange24h, 1.0);
  });

  it("throws when the page holds nothing usable", () => {
    assert.throws(() => fullNodesFromSnapshots([]), /no usable snapshots/);
    assert.throws(
      () => fullNodesFromSnapshots([{ timestamp: now }]),
      /no usable snapshots/,
    );
  });

  it("returns an unknown trend rather than dividing by a zero reference", () => {
    const reading = fullNodesFromSnapshots([snap(0, 26_260), snap(24, 0)]);

    assert.deepEqual(reading, {
      count: 26_260,
      percentChange24h: null,
      trend: "unknown",
    });
  });
});
