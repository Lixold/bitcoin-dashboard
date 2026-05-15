// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the shared helpers used by every Worker. Run via:
//
//   cd workers && npm test
//
// Uses the Node.js built-in test runner (stable since Node 20). No
// additional dev-dependency required.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import {
  compileAlternation,
  countMatches,
  decodeEntities,
  fold,
  isoUtcSeconds,
  roundTo,
  stripHtml,
} from "./lib.js";

describe("fold", () => {
  it("lowercases ASCII unchanged", () => {
    assert.equal(fold("Bitcoin"), "bitcoin");
  });

  it("strips diacritics from Latin combining marks", () => {
    // The classic German news-feed case: "Bärenmarkt" must match
    // diacritic-free lexicon entries like "barenmarkt".
    assert.equal(fold("Bärenmarkt"), "barenmarkt");
    assert.equal(fold("Rückgang"), "ruckgang");
    assert.equal(fold("Anstieg"), "anstieg");
  });

  it("works on non-Latin combining marks via \\p{M}", () => {
    // Tonemark accents stripped — important for future Asian-language
    // pipelines (Vietnamese, etc.). Plain Han / hiragana / hangul pass
    // through because they don't decompose under NFKD.
    assert.equal(fold("Bitcôin"), "bitcoin");
    // 中文 / 日本語 / 한국어 are not combining-mark-decorated and survive
    // unchanged. We only assert they don't throw and stay lowercase.
    assert.equal(fold("BITCOIN中文"), "bitcoin中文");
  });

  it("returns empty string on empty input", () => {
    assert.equal(fold(""), "");
  });
});

describe("compileAlternation", () => {
  it("matches whole words only — no prefix bleeding", () => {
    const alt = compileAlternation(["up", "rise"]);
    // Critical contract from the audit: `up` must not match `upgrade`.
    assert.equal(alt.test.test("network upgrade landed"), false);
    assert.equal(alt.test.test("price is up today"), true);
    assert.equal(alt.test.test("rise of bitcoin"), true);
    // `supply` must not match `up`.
    assert.equal(alt.test.test("circulating supply"), false);
  });

  it("matches case-insensitively via fold()", () => {
    const alt = compileAlternation(["Bullenmarkt"]);
    // Keywords are folded at compile time; haystack is also folded by
    // the news pipeline. We test the haystack-folded form.
    assert.equal(alt.test.test("der bullenmarkt geht weiter"), true);
  });

  it("supports multi-word keywords with word boundaries", () => {
    const alt = compileAlternation(["bitcoin core"]);
    assert.equal(alt.test.test("a bitcoin core release"), true);
    // Substring match across word break must not fire.
    assert.equal(alt.test.test("bitcoin-only core lib"), false);
  });

  it("exposes separate { test, count } so .test() never mutates state", () => {
    const alt = compileAlternation(["btc"]);
    // The test regex has no `g` flag, so consecutive .test() calls are
    // deterministic regardless of the count regex's lastIndex state.
    assert.equal(alt.test.test("btc dropped"), true);
    assert.equal(alt.test.test("btc dropped"), true);
    assert.equal(alt.test.test("btc dropped"), true);
  });

  it("counts via count regex without leaking lastIndex", () => {
    const alt = compileAlternation(["up", "down"]);
    assert.equal(countMatches(alt.count, "up up down"), 3);
    // Second call must reset lastIndex internally.
    assert.equal(countMatches(alt.count, "up"), 1);
  });

  it("escapes regex metacharacters in keywords", () => {
    // A naive implementation would let `.` match any character.
    const alt = compileAlternation(["a.b"]);
    assert.equal(alt.test.test("axb"), false);
    assert.equal(alt.test.test("a.b foo"), true);
  });
});

describe("countMatches", () => {
  it("returns 0 for no match", () => {
    const alt = compileAlternation(["xyz"]);
    assert.equal(countMatches(alt.count, "abc"), 0);
  });

  it("returns the total number of matches", () => {
    const alt = compileAlternation(["btc"]);
    assert.equal(countMatches(alt.count, "btc btc btc"), 3);
  });
});

describe("isoUtcSeconds", () => {
  it("emits the Python-compatible UTC offset suffix", () => {
    const d = new Date(Date.UTC(2026, 4, 13, 8, 0, 0, 123));
    // Native toISOString would emit `…Z` with millisecond precision; we
    // strip ms and replace the suffix to match the shape the Flutter
    // client originally consumed from the Python scripts.
    assert.equal(isoUtcSeconds(d), "2026-05-13T08:00:00+00:00");
  });
});

describe("roundTo", () => {
  it("rounds to the requested decimal precision", () => {
    assert.equal(roundTo(1.234567, 2), 1.23);
    assert.equal(roundTo(1.235, 2), 1.24);
  });

  it("handles integers", () => {
    assert.equal(roundTo(2, 4), 2);
  });
});

describe("decodeEntities", () => {
  it("decodes the standard XML entities", () => {
    assert.equal(decodeEntities("a &amp; b"), "a & b");
    assert.equal(decodeEntities("&lt;br&gt;"), "<br>");
  });

  it("decodes numeric character references", () => {
    assert.equal(decodeEntities("&#65;&#x42;"), "AB");
  });

  it("decodes German named entities used by some RSS feeds", () => {
    assert.equal(decodeEntities("B&auml;renmarkt"), "Bärenmarkt");
    assert.equal(decodeEntities("Stra&szlig;e"), "Straße");
  });

  it("passes unknown named entities through unchanged", () => {
    assert.equal(decodeEntities("&notarealentity;"), "&notarealentity;");
  });
});

describe("stripHtml", () => {
  it("removes simple tags and collapses whitespace", () => {
    assert.equal(stripHtml("<p>Hello   world</p>"), "Hello world");
  });

  it("decodes entities after stripping", () => {
    assert.equal(stripHtml("<p>5 &lt; 10</p>"), "5 < 10");
  });

  it("returns empty string for empty input", () => {
    assert.equal(stripHtml(""), "");
    assert.equal(stripHtml(null), "");
  });
});
