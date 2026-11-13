# Feature: on-chain and network metrics

Network data read directly from the Bitcoin network and its public
explorers. These metrics say how the network is doing, independent of the
price. They belong to the Network section and answer thesis 4; the
requirements are F04.2 to F04.9 in the
[functional requirements](../product/functional-requirements.md#thesis-4--is-the-bitcoin-network-healthy-and-secure).
Mining-pool concentration and the number of reachable nodes come from a Worker
payload (`network-health.json`) and are specified in F04.1, F04.3 and F04.4.

## Metrics

**Network health**

| Metric | Description | Source |
|---|---|---|
| Hashrate | Current mining capacity (EH/s), 7-day average | mempool.space |
| Difficulty | Current mining difficulty | mempool.space |
| Difficulty adjustment | Estimated next adjustment (percent and countdown) | mempool.space |
| Block height and last block | Current height and time of the last block | mempool.space |

**Mempool and fees**

| Metric | Description | Source |
|---|---|---|
| Mempool size | Waiting transactions (count and MB) | mempool.space |
| Fee recommendation | Low, medium and high priority (sat/vB) | mempool.space |
| Fee history | Fee levels over time, as a heat map | mempool.space |

**Network activity**

| Metric | Description | Source |
|---|---|---|
| Active addresses | Unique addresses with activity in 24 h | Blockchain.com or CoinMetrics; not decided |
| Transaction volume | On-chain BTC volume in 24 h | Blockchain.com; not decided |

**Lightning Network** (optional, later): total capacity and number of active
channels, from mempool.space.

## UI concept

- A grid of tiles, one per metric, each with its statement.
- Colour coding (green, yellow, red) separates normal operation from
  anomalies.
- Tapping a tile opens a detail view with the history of the metric.

## Data

The live metrics are fetched by the app directly from mempool.space, every 60
seconds (fees, mempool) or every 5 minutes (hashrate, difficulty); see
[ADR-0002](../adr/0002-data-sources-and-apis.md) and
[ADR-0005](../adr/0005-static-json-api-via-cdn.md). Nothing in this module needs
a Worker.

## Open questions

- Which of the activity metrics (active addresses, transaction volume) can be
  had reliably from a free API. The free Glassnode tier does not qualify: it
  serves weekly data only (ADR-0002).
