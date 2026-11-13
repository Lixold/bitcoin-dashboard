# Feature: large holders ("whale and smart money")

Shows whether institutional investors and long-term holders are accumulating
or taking profits. No raw wallet balances; a clear direction with its reason.
Part of the Market section and thesis 6. The requirements are F06.1 to F06.5 in
the
[functional requirements](../product/functional-requirements.md#thesis-6--are-the-large-holders-accumulating-or-selling).

The module depends on data sources that are not chosen yet. This note records
what is known.

## Requirements in short

| ID | Metric | Interpretation | Priority |
|---|---|---|---|
| F06.1 | Exchange flows | Net inflow or outflow of BTC on exchanges | High |
| F06.2 | Whale wallet trend (wallets above 1,000 BTC) | Is the group growing or shrinking? | High |
| F06.3 | HODL waves | Warning when long-term holders sell | Medium |
| F06.4 | Coin Days Destroyed | Old coins in motion: distribution? | Medium |
| F06.5 | Spot ETF flows | Net institutional inflow or outflow | High |

## Data sources

| Metric | Free source available? | Candidate |
|---|---|---|
| F06.5 ETF flows | Yes | CoinGlass API (free with a key) |
| F06.1 Exchange flows | Limited | CoinMetrics Community, to be evaluated |
| F06.2 Whale wallets | Limited | CoinMetrics Community, to be evaluated |
| F06.3 HODL waves | Hardly any free source | Glassnode (paid) or CoinMetrics |
| F06.4 CDD | Limited | CoinMetrics Community or Blockchain.com |

**Priority.** F06.5 is built on its own, independent of the other metrics.
F06.1 to F06.4 depend on the CoinMetrics evaluation.

## Backend

Planned Workers, once the sources are settled. Each publishes under
[ADR-0005](../adr/0005-static-json-api-via-cdn.md) and is added to the CDN
watchdog's payload list:

```
cron-etf-flows   → CoinGlass API       → data/etf-flows.json    (daily)
cron-whale-data  → CoinMetrics (TBD)   → data/whale-flows.json  (daily, TBD)
```

## Open questions

- Which of F06.1, F06.2 and F06.4 does the free CoinMetrics Community tier
  deliver at daily resolution?
- Does the CoinGlass licence allow displaying the data in an open-source app?
  (Also listed in [ADR-0002](../adr/0002-data-sources-and-apis.md).)
- If no source is free: build F06.5 only and treat the rest as a later
  extension?
