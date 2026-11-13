# Documentation

This directory holds what the project knows about itself, in English. Working
rules, the Definition of Done and conventions are in
[CLAUDE.md](../CLAUDE.md); the user-facing overview is the
[README](../README.md). Where each kind of knowledge lives is in
[CLAUDE.md §9](../CLAUDE.md).

| Directory | Contents |
|---|---|
| [`product/`](product/) | [Overview](product/overview.md), [roadmap](product/roadmap.md), [functional](product/functional-requirements.md) and [non-functional](product/non-functional-requirements.md) requirements |
| [`architecture/`](architecture/) | [System overview](architecture/system-overview.md) |
| [`adr/`](adr/) | Architecture decisions, the only copy; see the [index](adr/README.md) |
| [`features/`](features/) | One note per module: [price and charts](features/price-overview-and-charts.md), [on-chain metrics](features/on-chain-metrics.md), [news and sentiment](features/news-and-sentiment.md), [price forecasts](features/price-forecasts.md), [mining calculator](features/mining-calculator.md), [large holders](features/whale-and-smart-money.md), [internationalisation](features/internationalisation.md) |
| [`research/`](research/) | [News feed sources and language strategy](research/news-feed-sources.md) |
| [`deployment/`](deployment/) | [Distribution](deployment/distribution.md) |

## How to read these notes

- **They describe intent, not status.** A requirement or feature note says what
  the product is meant to do. Whether it has shipped is answered by the code, the
  closed `slice` issues and the project board, never by a note in this
  directory ([CLAUDE.md §10](../CLAUDE.md)).
- **Where a note and the code disagree, the code is the fact** and the note is
  a defect: fix it in a pull request.
- **A decision goes into an ADR**, not into a feature note. A feature note links
  to the ADR; it does not restate it.
- **No backlog and no commercial topics here** ([CLAUDE.md §10 and §12](../CLAUDE.md)).
