// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the CoinGecko price-series mapper.
//
// These exist because of a shipped data corruption: `Number(p[0]) | 0`
// coerced millisecond epochs to signed 32-bit integers, so every published
// history-*.json carried timestamps that decoded to 2006-2009, and the two
// longest ranges (3M, 1Y) wrapped inside the array and stopped being
// monotonic. The regression guards below assert the emitted unit
// (milliseconds, verbatim from CoinGecko) and monotonicity across a span
// wider than 2^32 ms.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import { mapPriceSeries } from "./index.js";

// Real-shaped CoinGecko `market_chart` excerpt: `[ts_ms, price]` pairs at the
// 5-minute cadence the 1D range returns, anchored on 2026-08-28 17:14:20 UTC.
const COINGECKO_1D_EXCERPT = [
  [1787937260000, 80871.4207164174],
  [1787937560000, 80912.03186513288],
  [1787937860000, 80798.55219871149],
  [1787938160000, 81147.90144270253],
];

// Anything above 2^31-1 ms wraps under `| 0`. Every value we emit is far
// beyond it, so this is the cheapest possible assertion of the unit.
const INT32_MAX = 2 ** 31 - 1;

function isMonotonic(values) {
  for (let i = 1; i < values.length; i++) {
    if (values[i] <= values[i - 1]) return false;
  }
  return true;
}

describe("mapPriceSeries — unit contract", () => {
  it("emits CoinGecko millisecond epochs verbatim", () => {
    const { timestamps, prices } = mapPriceSeries(COINGECKO_1D_EXCERPT);

    assert.deepEqual(timestamps, [
      1787937260000, 1787937560000, 1787937860000, 1787938160000,
    ]);
    assert.deepEqual(prices, [
      80871.4207164174, 80912.03186513288, 80798.55219871149,
      81147.90144270253,
    ]);
  });

  it("keeps every timestamp above the signed 32-bit ceiling", () => {
    const { timestamps } = mapPriceSeries(COINGECKO_1D_EXCERPT);
    for (const ts of timestamps) {
      assert.ok(ts > INT32_MAX, `${ts} wrapped to 32 bits`);
    }
  });

  it("decodes to the calendar date CoinGecko meant", () => {
    const { timestamps } = mapPriceSeries(COINGECKO_1D_EXCERPT);
    assert.equal(
      new Date(timestamps[0]).toISOString(),
      "2026-08-28T17:14:20.000Z",
    );
  });

  it("preserves the 5-minute spacing of the 1D range", () => {
    const { timestamps } = mapPriceSeries(COINGECKO_1D_EXCERPT);
    for (let i = 1; i < timestamps.length; i++) {
      assert.equal(timestamps[i] - timestamps[i - 1], 300000);
    }
  });
});

describe("mapPriceSeries — monotonicity", () => {
  it("stays monotonic across a span wider than 2^32 ms", () => {
    // 2161 hourly points = the real 3M payload size, spanning ~7.8e9 ms.
    // Under `| 0` the wraparound landed inside this array and the series
    // went backwards by ~4.29e9 ms — a 3M chart that computed to a span of
    // minus 9.4 days.
    const start = 1780158860000; // 2026-05-30T17:14:20Z
    const hourly = Array.from({ length: 2161 }, (_, i) => [
      start + i * 3600000,
      70000 + i,
    ]);

    const { timestamps, prices } = mapPriceSeries(hourly);

    assert.equal(timestamps.length, 2161);
    assert.ok(isMonotonic(timestamps));
    assert.ok(
      timestamps[timestamps.length - 1] - timestamps[0] > 2 ** 32,
      "test fixture must span more than 2^32 ms to be a regression guard",
    );
    assert.equal(prices.length, timestamps.length);
  });

  it("never emits a negative timestamp", () => {
    // 1M and 1Y shipped first timestamps of -1358395136 and -216024064.
    const { timestamps } = mapPriceSeries(COINGECKO_1D_EXCERPT);
    for (const ts of timestamps) assert.ok(ts > 0);
  });
});

describe("mapPriceSeries — malformed input", () => {
  it("drops pairs with a non-finite value and keeps the arrays aligned", () => {
    const { timestamps, prices } = mapPriceSeries([
      [1787937260000, 80871.42],
      [1787937560000, null],
      ["not-a-number", 80912.03],
      [1787938160000, 81147.9],
    ]);

    assert.deepEqual(timestamps, [1787937260000, 1787938160000]);
    assert.deepEqual(prices, [80871.42, 81147.9]);
    assert.equal(timestamps.length, prices.length);
  });

  it("skips entries that are not pairs", () => {
    const { timestamps, prices } = mapPriceSeries([
      [1787937260000, 80871.42],
      null,
      "garbage",
      [1787937560000, 80912.03],
    ]);

    assert.deepEqual(timestamps, [1787937260000, 1787937560000]);
    assert.equal(prices.length, 2);
  });

  it("returns empty arrays when prices is missing or not an array", () => {
    for (const input of [undefined, null, {}, "prices"]) {
      const { timestamps, prices } = mapPriceSeries(input);
      assert.deepEqual(timestamps, []);
      assert.deepEqual(prices, []);
    }
  });
});
