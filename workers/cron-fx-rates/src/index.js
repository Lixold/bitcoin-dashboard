// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Cloudflare Worker: ECB daily foreign-exchange reference rates.
//
// Replaces scripts/fetch_fx_rates.py. Pulls the ECB eurofxref-daily XML feed,
// builds a full base->quote cross-rate matrix for ~30 currencies, and writes
// it to R2 at data/fx-rates.json with a 24h CDN cache.
//
// Publication cadence on the ECB side: TARGET2 banking days, around 16:00
// CET. The cron sits at 16:23 UTC — safely after publish in both CET (17:23
// local) and CEST (18:23 local). On non-banking days the feed simply still
// returns the previous day's rates with the previous day's `time=` attribute;
// that's the behaviour we want, so no special-casing.

const ECB_URL = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml";

// Cross rates derived from 4-decimal ECB inputs do not justify arbitrary
// precision, but high-magnitude pairs (e.g. JPY ~ 184 EUR-base) lose ~0.7 %
// in a round-trip A -> B -> A at 6 decimals. 8 decimals keeps the worst-case
// round-trip deviation under 1e-4 for every pair while only adding ~15 % to
// the JSON payload size.
const RATE_DECIMALS = 8;

const FX_CACHE_CONTROL = "public, max-age=86400";

function isoUtcSeconds(d) {
  return d.toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

function roundTo(n, decimals) {
  const f = Math.pow(10, decimals);
  return Math.round(n * f) / f;
}

// Parse the ECB XML and return { date, rates } where `rates` maps each
// currency code (including EUR=1.0) to its rate against EUR.
//
// Structure of the feed:
//   <gesmes:Envelope ...>
//     <Cube>
//       <Cube time="YYYY-MM-DD">
//         <Cube currency="USD" rate="1.08"/>
//         ...
//       </Cube>
//     </Cube>
//   </gesmes:Envelope>
//
// The feed has a fixed, predictable structure, so a single regex pass per
// concern is enough — no DOM tree needed (and DOMParser isn't available
// in the workerd runtime anyway).
function parseEcbXml(xmlText) {
  const dateMatch = xmlText.match(/time\s*=\s*["'](\d{4}-\d{2}-\d{2})["']/);
  if (!dateMatch) {
    throw new Error("ECB feed: missing dated <Cube time=...> element");
  }
  const date = dateMatch[1];

  // EUR is the implicit base in the ECB feed and not listed as a row; add
  // it explicitly so the cross-rate matrix treats it uniformly.
  const rates = { EUR: 1.0 };

  // Single sweep over the body picks up every (currency, rate) pair. The
  // order of the two attributes is consistent in the ECB feed (currency
  // first), so a strict pattern is fine here.
  const cubeRe = /currency\s*=\s*["']([A-Z]+)["']\s+rate\s*=\s*["']([\d.]+)["']/g;
  let m;
  while ((m = cubeRe.exec(xmlText)) !== null) {
    const currency = m[1];
    const rateStr = m[2];
    const r = Number.parseFloat(rateStr);
    if (Number.isNaN(r)) {
      console.warn(`Skipping non-numeric rate for ${currency}: ${rateStr}`);
      continue;
    }
    rates[currency] = r;
  }

  if (Object.keys(rates).length <= 1) {
    throw new Error("ECB feed contained no usable currency rates");
  }

  return { date, rates };
}

// Build the full base -> quote matrix. For any pair (A, B):
//   rate(A -> B) = eur_rates[B] / eur_rates[A]
// because eur_rates[X] expresses "1 EUR = X units of currency X".
function computeCrossRates(eurRates) {
  const cross = {};
  for (const [base, baseRate] of Object.entries(eurRates)) {
    const row = {};
    for (const [quote, quoteRate] of Object.entries(eurRates)) {
      row[quote] = roundTo(quoteRate / baseRate, RATE_DECIMALS);
    }
    cross[base] = row;
  }
  return cross;
}

async function runAll(env) {
  // Single upstream call + single upload — there is no partial-success
  // granularity to preserve here (unlike history/news). On a transient
  // failure the previous fx-rates.json on R2 stays in place, and the next
  // daily cron tick refreshes it.
  console.log(`Fetching ECB daily reference rates from ${ECB_URL}`);
  const res = await fetch(ECB_URL, {
    headers: { Accept: "application/xml, text/xml;q=0.9, */*;q=0.5" },
  });
  if (!res.ok) {
    throw new Error(`ECB HTTP ${res.status}`);
  }
  const xmlText = await res.text();

  const { date, rates } = parseEcbXml(xmlText);
  console.log(
    `Parsed ECB feed: date=${date} currencies=${Object.keys(rates).length}`,
  );

  const cross = computeCrossRates(rates);

  const payload = {
    _meta: {
      fetchedAt: isoUtcSeconds(new Date()),
      date,
      source: "ECB",
      currencies: Object.keys(rates).sort(),
    },
    ...cross,
  };

  await env.BUCKET.put("data/fx-rates.json", JSON.stringify(payload), {
    httpMetadata: {
      contentType: "application/json",
      cacheControl: FX_CACHE_CONTROL,
    },
  });

  console.log(`FX rates uploaded successfully (date=${date})`);
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runAll(env));
  },
};
