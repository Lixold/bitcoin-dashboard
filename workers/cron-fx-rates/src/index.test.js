// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Unit tests for the ECB feed parser. These cover the shapes we have
// historically seen from ECB (single-quoted vs. double-quoted attrs;
// missing dated cube; non-numeric rate strings) and the cross-rate
// derivation that the Flutter client depends on.

import { describe, it } from "node:test";
import { strict as assert } from "node:assert";

import { computeCrossRates, parseEcbXml } from "./index.js";

const ECB_FEED_DOUBLE_QUOTES = `<?xml version="1.0" encoding="UTF-8"?>
<gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01"
                 xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
  <Cube>
    <Cube time="2026-05-13">
      <Cube currency="USD" rate="1.0823"/>
      <Cube currency="CHF" rate="0.9214"/>
      <Cube currency="JPY" rate="167.45"/>
    </Cube>
  </Cube>
</gesmes:Envelope>`;

const ECB_FEED_SINGLE_QUOTES = `<?xml version='1.0' encoding='UTF-8'?>
<gesmes:Envelope>
  <Cube>
    <Cube time='2026-05-13'>
      <Cube currency='USD' rate='1.0823'/>
      <Cube currency='GBP' rate='0.8451'/>
    </Cube>
  </Cube>
</gesmes:Envelope>`;

describe("parseEcbXml — happy path", () => {
  it("extracts date and EUR-based rates including the implicit EUR=1", () => {
    const { date, rates } = parseEcbXml(ECB_FEED_DOUBLE_QUOTES);
    assert.equal(date, "2026-05-13");
    assert.equal(rates.EUR, 1.0);
    assert.equal(rates.USD, 1.0823);
    assert.equal(rates.CHF, 0.9214);
    assert.equal(rates.JPY, 167.45);
  });

  it("accepts single-quoted XML attributes (regression: PR #17)", () => {
    const { date, rates } = parseEcbXml(ECB_FEED_SINGLE_QUOTES);
    assert.equal(date, "2026-05-13");
    assert.equal(rates.USD, 1.0823);
    assert.equal(rates.GBP, 0.8451);
  });
});

describe("parseEcbXml — failure modes", () => {
  it("throws when the dated <Cube time=...> element is missing", () => {
    const xml = `<?xml version="1.0"?><Cube><Cube><Cube currency="USD" rate="1.0"/></Cube></Cube>`;
    assert.throws(() => parseEcbXml(xml), /missing dated <Cube time/);
  });

  it("throws when the feed has no usable rates", () => {
    const xml = `<?xml version="1.0"?><Cube><Cube time="2026-05-13"></Cube></Cube>`;
    assert.throws(() => parseEcbXml(xml), /no usable currency rates/);
  });

  it("skips non-numeric rates and keeps the rest", () => {
    const xml = `<?xml version="1.0"?>
<Cube><Cube time="2026-05-13">
  <Cube currency="USD" rate="1.0823"/>
  <Cube currency="BAD" rate="not-a-number"/>
  <Cube currency="JPY" rate="167.45"/>
</Cube></Cube>`;
    const { rates } = parseEcbXml(xml);
    assert.equal(rates.USD, 1.0823);
    assert.equal(rates.JPY, 167.45);
    assert.equal(rates.BAD, undefined);
  });
});

describe("computeCrossRates", () => {
  it("produces a symmetric base→quote matrix from EUR-base rates", () => {
    const eurRates = { EUR: 1.0, USD: 1.0823, CHF: 0.9214 };
    const cross = computeCrossRates(eurRates);

    // EUR row mirrors the input.
    assert.equal(cross.EUR.EUR, 1.0);
    assert.equal(cross.EUR.USD, 1.0823);
    assert.equal(cross.EUR.CHF, 0.9214);

    // USD row: 1 USD = (EUR/USD) EUR = 1/1.0823 EUR ≈ 0.92395 EUR.
    assert.equal(cross.USD.USD, 1.0);
    assert.ok(Math.abs(cross.USD.EUR - 0.92395) < 0.0001);
    // 1 USD = (CHF/USD) CHF = 0.9214/1.0823 CHF ≈ 0.85134 CHF.
    assert.ok(Math.abs(cross.USD.CHF - 0.85134) < 0.0001);
  });

  it("keeps round-trip A → B → A within 1e-4 even for high-magnitude pairs", () => {
    // JPY has the largest absolute value among ECB currencies; this is
    // the canonical "lose precision on cross-rates" smoke test.
    const eurRates = { EUR: 1.0, JPY: 184.5 };
    const cross = computeCrossRates(eurRates);
    const roundTrip = cross.EUR.JPY * cross.JPY.EUR;
    assert.ok(Math.abs(roundTrip - 1.0) < 1e-4);
  });

  it("returns the identity ratio on each diagonal", () => {
    const cross = computeCrossRates({ EUR: 1.0, USD: 1.5, GBP: 0.8 });
    assert.equal(cross.EUR.EUR, 1.0);
    assert.equal(cross.USD.USD, 1.0);
    assert.equal(cross.GBP.GBP, 1.0);
  });
});
