# Feature: price overview and charts

The core module of the app and the Price section. It answers thesis 1: what a
Bitcoin costs right now, in the reader's currency and in sats, and where the
price is heading. The requirements are F01.1 to F01.7 in the
[functional requirements](../product/functional-requirements.md#thesis-1--what-does-a-bitcoin-cost-right-now-and-what-is-that-in-my-world).
Every figure on this screen sits inside a statement
([CLAUDE.md §5](../../CLAUDE.md)).

## Elements

**Price header.** The current price, large, in the chosen currency; the
percentage change over a switchable period (24 h, 7 d, 30 d); the absolute
change; the time of the last update. The sats line says how many sats one unit
of the chosen currency buys.

**Chart.** A line chart of the price over the chosen range: 1D, 1W, 1M, 3M,
1Y, and all. The chart takes the colour of the trend in that range. Zoom and
pinch-to-zoom on touch devices; a tooltip with the exact value on hover or
touch. Charts are drawn with `fl_chart`.

**Market cards.** Market capitalisation, 24-hour volume, circulating supply,
and the all-time high and low with their dates and the distance in percent.
The volume is shown with a reference that makes it readable (F01.5); see the
notes below.

## Data

| Element | Source | Notes |
|---|---|---|
| Live price | Binance public API, called by the app | Every 60 seconds ([ADR-0002](../adr/0002-data-sources-and-apis.md)) |
| History | `data/history-{range}.json`, from `cron-history` | Ranges 1D, 1W, 1M, 3M, 1Y; a series of timestamps and prices ([ADR-0005](../adr/0005-static-json-api-via-cdn.md)) |
| Market snapshot | `data/market.json`, from `cron-history` | Market cap, volume, supply, all-time high and low, Bitcoin dominance |
| Currency | `data/fx-rates.json`, from `cron-fx-rates` | About 30 currencies, converted on the device |

The cache lifetimes are in ADR-0005. The price is polled every 60 seconds, and
after a failure it backs off exponentially up to five minutes.

## Notes

- The ranges follow F01.3. The `ALL` range needs price history beyond the 365
  days the CoinGecko Demo API serves; that is an open decision (issue #44) and
  becomes an ADR.
- The history payload is a price series, not candles. A candlestick view would
  need open, high, low and close values in a payload that does not exist, and
  is not planned.
- A 30-day mean for the 24-hour volume (issue #93) is what makes the volume
  figure assessable; until it exists the volume is left out of the Price
  section.
