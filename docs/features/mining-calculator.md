# Feature: mining calculator

A personalised mining calculator, the Miner section and thesis 5. The reader
enters their own hashrate, power consumption and electricity price once, and
from then on sees global network data set against that profile: not a static
calculator but a profile that keeps itself current. The requirements are F05.1
to F05.6 in the
[functional requirements](../product/functional-requirements.md#thesis-5--what-does-my-miner-earn-right-now-and-does-it-pay-off).

The module is **entirely client-side** (Dart). It needs no Worker and no new
host.

## Mining profile (F05.1)

The profile lives in the Miner section, not in the settings
([ADR-0007](../adr/0007-information-architecture-and-navigation.md)), and is
stored locally in Hive under `mining_profile`.

| Parameter | Unit | Example |
|---|---|---|
| Own hashrate | TH/s | 110 TH/s |
| Power consumption | W | 3,250 W |
| Electricity price | ct/kWh | 8.5 ct/kWh |

```
mining_profile: {
  hashrate_ths: double,        // TH/s
  power_consumption_w: int,    // watt
  electricity_cost_ct: double  // ct/kWh
}
```

## Calculations

All formulas rest on public mining figures.

**Daily earnings in BTC (F05.2)**

```
btc_per_day = (own_hashrate / network_hashrate) × block_subsidy × blocks_per_day
            = (own_hashrate / network_hashrate) × 3.125 BTC × 144
```

The formula counts the block subsidy only; fees are shown next to it (F05.6).
The subsidy halves with every halving, so it is read from the halving schedule
and not written into a screen.

**Daily electricity cost**

```
cost_per_day = (power_w / 1000) × 24 h × (electricity_ct / 100)
```

**Break-even price (F05.3)**, in the currency of the electricity price:

```
breakeven_price = cost_per_day / btc_per_day
```

**Effect of the next difficulty adjustment (F05.4)**

```
new_earnings = btc_per_day × (current_difficulty / expected_new_difficulty)
delta_sats   = (new_earnings − btc_per_day) × 100_000_000
```

**Share of the network hashrate (F05.5)**

```
share_pct = (own_hashrate / network_hashrate) × 100
```

## UI concept

- **Profile tile**, always visible once a profile exists: daily earnings in
  BTC and in fiat, electricity cost, net result.
- **Break-even indicator**: a traffic light (green above break-even, red below)
  and the distance in percent.
- **Difficulty impact**: a preview of the next adjustment on the earnings.
- **No profile yet**: the empty state of the section invites the reader to
  enter the three values. Its design belongs to the slice.

## Data

| Data point | Source | Provided by |
|---|---|---|
| Network hashrate (EH/s) | mempool.space | live call, every 5 minutes |
| Current difficulty | mempool.space | live call |
| Expected difficulty adjustment (%) | mempool.space | live call |
| Fee share against subsidy | mempool.space | live call |
| Live price in fiat | Binance, then ECB rates | live price and `fx-rates.json` |

A provider combines the stored profile with these streams and produces the
statistics; no payload is added to [ADR-0005](../adr/0005-static-json-api-via-cdn.md).
