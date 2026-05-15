// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the network-health aggregator. Covers the 2×2 grid of
// trend × pool-share states the dashboard surfaces.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import { aggregateHealth, trendLabel } from "./index.js";

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

  it("falls back to whichever dimension is present when the other is null", () => {
    // Bitnodes outage → only pool data is meaningful.
    assert.equal(aggregateHealth(null, 25.0), "good");
    assert.equal(aggregateHealth(null, 35.0), "warning");
    assert.equal(aggregateHealth(null, 45.0), "critical");
    // Mempool outage → only node trend is meaningful.
    assert.equal(aggregateHealth(2.0, null), "good");
    assert.equal(aggregateHealth(-2.0, null), "warning");
    assert.equal(aggregateHealth(-10.0, null), "critical");
  });

  it("returns good when both dimensions are null (defensive contract)", () => {
    // In practice main() doesn't upload in this case, but the function
    // must still type-check cleanly.
    assert.equal(aggregateHealth(null, null), "good");
  });
});
