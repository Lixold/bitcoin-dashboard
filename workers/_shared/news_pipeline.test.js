// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the news-pipeline XML parser. Exercises the RSS / Atom
// branches plus the malformed-input fallback. The classifier and the R2
// upload path are not covered here; they're integration-level concerns
// best left to a deploy-time smoke test.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import {
  asText,
  atomLinkHref,
  parseDate,
  parseFeed,
  rssLink,
} from "./news_pipeline.js";

describe("parseFeed — RSS", () => {
  it("extracts a single item with CDATA-wrapped title and description", () => {
    const xml = `<?xml version="1.0"?>
<rss>
  <channel>
    <item>
      <title><![CDATA[BTC up 5%]]></title>
      <link>https://example.org/btc-up</link>
      <description><![CDATA[Bitcoin gained 5% overnight.]]></description>
      <pubDate>Wed, 13 May 2026 08:00:00 +0000</pubDate>
    </item>
  </channel>
</rss>`;
    const out = parseFeed(xml);
    assert.equal(out.length, 1);
    assert.equal(out[0].title, "BTC up 5%");
    assert.equal(out[0].url, "https://example.org/btc-up");
    assert.equal(out[0].description, "Bitcoin gained 5% overnight.");
    assert.ok(out[0].publishedAt instanceof Date);
    assert.equal(out[0].publishedAt.toISOString(), "2026-05-13T08:00:00.000Z");
  });

  it("prefers content:encoded over description when both are present", () => {
    const xml = `<?xml version="1.0"?>
<rss xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <item>
      <title>Lightning upgrade</title>
      <link>https://example.org/lightning</link>
      <description>Short summary.</description>
      <content:encoded>Full article body in HTML.</content:encoded>
      <pubDate>Wed, 13 May 2026 09:00:00 +0000</pubDate>
    </item>
  </channel>
</rss>`;
    const out = parseFeed(xml);
    assert.equal(out.length, 1);
    // The pipeline's getDescription chain reads content:encoded first,
    // which is the canonical "full body" field in RSS 2.0.
    assert.match(out[0].description, /Full article body/);
  });

  it("returns multiple items in source order", () => {
    const xml = `<?xml version="1.0"?>
<rss><channel>
  <item><title>First</title><link>https://example.org/1</link><pubDate>Wed, 13 May 2026 07:00:00 +0000</pubDate></item>
  <item><title>Second</title><link>https://example.org/2</link><pubDate>Wed, 13 May 2026 08:00:00 +0000</pubDate></item>
  <item><title>Third</title><link>https://example.org/3</link><pubDate>Wed, 13 May 2026 09:00:00 +0000</pubDate></item>
</channel></rss>`;
    const out = parseFeed(xml);
    assert.equal(out.length, 3);
    assert.deepEqual(out.map((x) => x.title), ["First", "Second", "Third"]);
  });
});

describe("parseFeed — Atom", () => {
  it("extracts an entry with rel=alternate link picked over rel=self", () => {
    const xml = `<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>Lightning upgrade</title>
    <link rel="self" href="https://example.org/feed"/>
    <link rel="alternate" href="https://example.org/lightning"/>
    <summary>A new Lightning protocol upgrade.</summary>
    <published>2026-05-13T09:00:00Z</published>
  </entry>
</feed>`;
    const out = parseFeed(xml);
    assert.equal(out.length, 1);
    assert.equal(out[0].title, "Lightning upgrade");
    assert.equal(out[0].url, "https://example.org/lightning");
    assert.equal(out[0].description, "A new Lightning protocol upgrade.");
  });

  it("falls back to summary when content is missing, and vice versa", () => {
    const xmlContent = `<?xml version="1.0"?>
<feed>
  <entry>
    <title>Entry</title>
    <link rel="alternate" href="https://example.org/x"/>
    <content>Body via content.</content>
    <published>2026-05-13T09:00:00Z</published>
  </entry>
</feed>`;
    const out = parseFeed(xmlContent);
    assert.equal(out[0].description, "Body via content.");
  });
});

describe("parseFeed — robustness", () => {
  it("returns empty array on totally malformed XML", () => {
    assert.deepEqual(parseFeed("<not actually xml"), []);
    assert.deepEqual(parseFeed(""), []);
  });

  it("returns empty array when no items or entries are present", () => {
    const xml = `<?xml version="1.0"?>
<rss><channel><title>Empty feed</title></channel></rss>`;
    assert.deepEqual(parseFeed(xml), []);
  });

  it("survives an item with no title/url — caller filters them out", () => {
    const xml = `<?xml version="1.0"?>
<rss><channel>
  <item>
    <pubDate>Wed, 13 May 2026 08:00:00 +0000</pubDate>
  </item>
</channel></rss>`;
    const out = parseFeed(xml);
    // parseFeed itself does not drop items — that's the caller's job.
    // It only asserts that the parser doesn't crash on missing fields.
    assert.equal(out.length, 1);
    assert.equal(out[0].title, "");
    assert.equal(out[0].url, "");
  });
});

describe("rssLink", () => {
  it("returns a plain string verbatim", () => {
    assert.equal(rssLink("https://example.org"), "https://example.org");
  });

  it("returns the first non-empty string from an array (parser-coerced shape)", () => {
    // Because the XMLParser is configured with isArray for `link`, RSS
    // links arrive here as single-element string arrays.
    assert.equal(rssLink(["https://example.org/article"]), "https://example.org/article");
  });

  it("handles Atom-style link smuggled into RSS via atomLinkHref", () => {
    const links = [
      { "@_rel": "self", "@_href": "https://example.org/feed" },
      { "@_rel": "alternate", "@_href": "https://example.org/article" },
    ];
    assert.equal(rssLink(links), "https://example.org/article");
  });

  it("returns empty string for null / undefined / unexpected shape", () => {
    assert.equal(rssLink(null), "");
    assert.equal(rssLink(undefined), "");
    assert.equal(rssLink(42), "");
  });
});

describe("atomLinkHref", () => {
  it("prefers rel=alternate over rel=self", () => {
    const links = [
      { "@_rel": "self", "@_href": "https://feed" },
      { "@_rel": "alternate", "@_href": "https://article" },
    ];
    assert.equal(atomLinkHref(links), "https://article");
  });

  it("accepts an entry without rel as if it were alternate", () => {
    const links = [{ "@_href": "https://article" }];
    assert.equal(atomLinkHref(links), "https://article");
  });

  it("falls back to the first href if no alternate is present", () => {
    const links = [
      { "@_rel": "self", "@_href": "https://feed" },
      { "@_rel": "enclosure", "@_href": "https://image" },
    ];
    assert.equal(atomLinkHref(links), "https://feed");
  });

  it("returns empty string for empty / non-array input", () => {
    assert.equal(atomLinkHref([]), "");
    assert.equal(atomLinkHref(undefined), "");
  });
});

describe("asText", () => {
  it("returns strings unchanged", () => {
    assert.equal(asText("hello"), "hello");
  });

  it("extracts #text from an object wrapper", () => {
    assert.equal(asText({ "#text": "wrapped", "@_attr": "x" }), "wrapped");
  });

  it("stringifies numbers and booleans for safety", () => {
    assert.equal(asText(42), "42");
    assert.equal(asText(true), "true");
  });

  it("returns empty string for nil and unexpected shape", () => {
    assert.equal(asText(null), "");
    assert.equal(asText(undefined), "");
    assert.equal(asText({}), "");
  });
});

describe("parseDate", () => {
  it("parses RFC 822 dates (RSS)", () => {
    const d = parseDate("Wed, 13 May 2026 08:00:00 +0000");
    assert.ok(d instanceof Date);
    assert.equal(d.toISOString(), "2026-05-13T08:00:00.000Z");
  });

  it("parses ISO-8601 (Atom)", () => {
    const d = parseDate("2026-05-13T09:00:00Z");
    assert.equal(d.toISOString(), "2026-05-13T09:00:00.000Z");
  });

  it("returns null on invalid input", () => {
    assert.equal(parseDate(""), null);
    assert.equal(parseDate(null), null);
    assert.equal(parseDate("nope"), null);
  });
});
