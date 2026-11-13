# Feature: price forecasts

Shows several well-known Bitcoin valuation and price models and sets the
current price against each. The reader sees at a glance where Bitcoin stands
according to a model. The module is the Forecast section and thesis 3; the
requirements are F03.1 to F03.7 in the
[functional requirements](../product/functional-requirements.md#thesis-3--where-does-bitcoin-stand-in-year-x-by-which-model).
It is planned for phase 4 of the [roadmap](../product/roadmap.md).

> **Disclaimer.** All forecast models are mathematical models based on
> historical data. They are not financial advice, and the app must say so.
> Every forecast screen shows: "This model is based on historical data and is
> not financial advice. Past developments are no indicator of future results."

## Valuation, not advice

A model band describes where the price stands relative to the model. Band names
are valuation labels such as "undervalued", "fair" or "overvalued". They are
never named after an action. Nothing in this module tells the reader to buy,
sell or hold. The labels are localised ARB copy, like every other statement
([CLAUDE.md §5](../../CLAUDE.md)).

## Models

**Stock-to-Flow (S2F)**
- Ratio: `S2F = circulating supply / annual production`.
- Model price derived from the ratio; the deviation of the current price from
  it, in percent.
- A chart of model price against actual price.
- The S2F model was published by PlanB under CC BY-SA, which requires credit
  to the author ([ADR-0002](../adr/0002-data-sources-and-apis.md)).

**Rainbow chart**
- Logarithmic regression channels since the genesis block, drawn as coloured
  bands.
- The current position is highlighted.

**Power Law corridor**
- Long-term support and resistance lines on a log-log chart.
- The current position inside the corridor (lower, middle or upper third).

**Halving cycle**
- The price relative to the last and the next halving.
- Overlay of several cycles (2012, 2016, 2020, 2024).
- Countdown to the next halving.

**Moving averages**
- The 200-week average as a long-term floor indicator.
- The 50-day and 200-day averages (golden cross and death cross).

## Calculation

All models are computed from the price history and the known halving dates.
The calculation is planned as the Worker `cron-prognosis`, which writes
`data/prognosis-{model}.json` once a day ([ADR-0005](../adr/0005-static-json-api-via-cdn.md));
no third-party model API is involved. The year slider (F03.1) evaluates the
published model parameters on the device.

## Open questions

- Where do the S2F production figures come from beyond the known halving
  schedule?
- Are the models free to use? S2F is CC BY-SA and needs attribution; the same
  question applies to each further model before it ships.
