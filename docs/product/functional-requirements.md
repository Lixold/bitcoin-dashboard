# Functional requirements

**Guiding principle.** The dashboard does not show raw numbers; it answers
questions. Every metric is interpreted and turned into a clear statement:
*what does this mean for me right now?* A reader should know what they need to
know after ten seconds, without looking anything up.

The requirements are grouped into eight theses. A thesis is the question a
section of the app answers; it is also the input to a slice design
([CLAUDE.md §5](../../CLAUDE.md)). Requirement IDs (`F01.1`, `F04.4`, …) are
stable: issues and code refer to them. Priorities are *High*, *Medium* and
*Low*. Which requirements have shipped is tracked in GitHub Issues, not here.

## Sections and theses

The app has six sections; the eight theses are spread across them
([ADR-0007](../adr/0007-information-architecture-and-navigation.md)).

| Section | id | Theses |
|---|---|---|
| Price | `price` | 1, 7 (relative value) |
| Market | `market` | 2, 6 (large holders) |
| Forecast | `forecast` | 3 |
| Network | `network` | 4 |
| Miner | `miner` | 5 |
| News | `news` | 8 |

**Navigation.** A `NavigationBar` below 768 dp, a `NavigationRail` from 768, a
`NavigationDrawer` from 1024. A section appears in the navigation once its
first slice has shipped. Settings are not a destination: they open from the
gear in the screen header, and on macOS also with ⌘, from the app menu.

---

## Thesis 1 — What does a Bitcoin cost right now, and what is that in my world?

**Background.** A Bitcoin user thinks in sats and dollars but lives in a local
currency. The price is the first question and has to be answered in under a
second, in both worlds at once.

**UX principle.** Never a number alone: price, direction and context together.
The reader sees at once whether it is more or less expensive than yesterday or
last week.

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F01.1 | Live Bitcoin price in USD and in the chosen home currency at the same time | Price, coloured direction indicator (▲/▼) and the percentage change today | High |
| F01.2 | Sats per fiat unit: "1 € = X sats" | How much Bitcoin does a small amount buy? More tangible than "BTC = 95,000 USD" | High |
| F01.3 | Price history chart (1D, 1W, 1M, 3M, 1Y, all) | The chart takes the colour of the trend in the chosen range, with "+X % in this period" | High |
| F01.4 | Percentage change against reference points (24 h, 7 d, 30 d, 1 y) | Actively commented, e.g. "strongest week in three months" | Medium |
| F01.5 | Market capitalisation, 24-hour volume and circulating supply | Volume relative to market cap: is the market active or quiet today? | Medium |
| F01.6 | All common fiat currencies (EUR, USD, GBP, CHF, JPY, KRW, AUD, CAD, BRL, CNY, INR, MXN, SEK, NOK, TRY, …) | — | High |
| F01.7 | All-time high and all-time low as reference | "X % to the all-time high" or "X % above the previous high" | Low |

---

## Thesis 2 — Is Bitcoin currently cheap or overheated?

**Background.** An informed holder does not want one more chart to interpret.
The reading wanted is whether, by historical measures, the market is cheap or
overheated right now.

**UX principle.** No indicator dump. The relevant on-chain signals are
condensed into **one aggregated market status**, a traffic light with its
reasoning, so the reader understands the signal and why it reads as it does.
Each metric also gets a short explanation behind an info control. The status
describes where the market stands relative to its history; it is never an
instruction to buy or sell.

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F02.1 | **Composite signal "market status"** from MVRV Z-Score, NUPL, Puell Multiple and Realized Price against market price | Aggregated traffic light: 🟢 accumulation zone / 🟡 neutral / 🔴 overheated, plus "the market was last in this range on [date]" | High |
| F02.2 | Fear & Greed Index (current and 30-day history) | Active comment, e.g. "extreme fear: sentiment is in the lowest of its five bands" | High |
| F02.3 | Distance of the current price from the 200-week moving average | "The price is X % above the 200-week average; distances beyond X % have preceded corrections in the past" | High |
| F02.4 | MVRV Z-Score as a single value, also part of the composite | Coloured zone: red = historically high, green = historically low, with a one-sentence explanation | High |
| F02.5 | Pi Cycle Top indicator | Shows "no signal" or "Pi Cycle Top within reach" | Medium |
| F02.6 | Realized Price as a floor reference | "The price is X % above the Realized Price; the market has rarely traded below it for long" | Medium |
| F02.7 | Historical cycle comparison | "The market currently resembles the state of [date]" | Low |

> **Data gap.** F02.1, F02.4 and F02.6 (MVRV, NUPL, Puell Multiple, Realized
> Price) need a source beyond mempool.space and Blockchain.com. The CoinMetrics
> Community API is the candidate under evaluation; see the open data points in
> [ADR-0002](../adr/0002-data-sources-and-apis.md).

---

## Thesis 3 — Where does Bitcoin stand in year X, by which model?

**Background.** A Bitcoin user believes in long-term price models but does not
trust all of them equally. They want to see what model Y says for 2028 and
decide for themselves which forecast they find plausible.

**UX principle.** No static chart. The reader picks a target year and sees all
active models side by side with their value for that year. No model is sold as
"the truth"; the reader chooses which ones to trust.

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F03.1 | **Year slider**: the reader picks a year and every active model shows its price for that year | Per model: estimated price and "that is X % above today's price" | High |
| F03.2 | Stock-to-Flow (PlanB): model value against current price | "The price is X % below/above the S2F model value" | High |
| F03.3 | Power Law corridor (lower edge, centre line, upper edge) | "The price is in the [lower/middle/upper] third of the corridor" | High |
| F03.4 | Rainbow chart (logarithmic regression bands) | Shows the name of the current band as a valuation label, such as "undervalued", "fair" or "overvalued"; never an instruction to buy or sell | High |
| F03.5 | Halving cycle overlay | "We are in month X after the last halving; in past cycles the high came around month X+12" | Medium |
| F03.6 | 200-week moving average as the lower edge of the forecast | The projected value of the average for the chosen year | Medium |
| F03.7 | Models can be switched on and off individually | The reader marks "I trust / do not trust this model"; switched-off models are greyed out | High |

> **Disclaimer.** All forecast models rest on historical data and are not
> financial advice. Every forecast screen carries the notice: "This model is
> based on historical data and is not financial advice. Past developments are
> no indicator of future results."

---

## Thesis 4 — Is the Bitcoin network healthy and secure?

**Background.** Trust in Bitcoin rests on the network, not on institutions.
The reader wants to observe it: is the chain running, is decentralisation
intact, is the community still working on the code?

**UX principle.** No raw node count, no abstract hashrate. The dashboard states
the health of the network in plain words: *all green* or *attention, X has
changed*. Technical metrics are translated into understandable language.

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F04.1 | **Network health status** (aggregated) | Traffic light: 🟢 running stably / 🟡 anomaly detected / 🔴 critical deviation, with the reason in one sentence | High |
| F04.2 | Hashrate (current, 7-day moving average, trend) | "Hashrate at an all-time high: the network has never been more secure" or "hashrate fell X % this week" | High |
| F04.3 | Number of reachable full nodes | "X,XXX nodes worldwide: no single party can control the network" | High |
| F04.4 | Mining pool concentration | Two values: the share of the largest pool and the combined share of the top three. Warning from top 3 above 70 % or top 1 above 40 %; critical from top 3 at 80 % or more, or top 1 above 50 %. "The three largest pools hold X % of the hashrate, still below the level at which a small group could decide the order of blocks" | High |
| F04.5 | Current block time and the last block (timestamp) | "Last block X minutes ago: the network is processing transactions normally" or "block time clearly raised" | High |
| F04.6 | Difficulty, countdown to the next adjustment and expected change | "In X days the difficulty will probably rise/fall by X %, which means for miners …" | High |
| F04.7 | **GitHub activity of Bitcoin Core** (commits and active contributors, last 30/90 days) | "X developers worked on Bitcoin Core in the last 30 days: the protocol is actively maintained" | High |
| F04.8 | Mempool size and recommended transaction fees (sat/vB) | "Mempool full: wait for cheaper transactions, or pay X sat/vB for confirmation in about an hour" | High |
| F04.9 | Lightning Network capacity | Is the Lightning Network growing or shrinking, and is it usable for everyday payments? | Low |

---

## Thesis 5 — What does my miner earn right now, and does it pay off?

**Background.** A Bitcoiner with their own hashrate, whether a small home miner
or a larger operation, needs no abstract network figures. They need their own
context: what do I earn today, does it still pay?

**UX principle.** No static mining calculator hidden somewhere. Mining metrics
are always set against the reader's own hashrate. The parameters are entered
once and every figure is personalised from then on.

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F05.1 | **Mining profile**, entered once: own hashrate (TH/s), power consumption (W), electricity price (ct/kWh) | Once set up, all metrics are personalised | High |
| F05.2 | Daily and monthly earnings forecast in BTC and fiat | "With your hashrate you earn about X BTC (~Y €) per day today" | High |
| F05.3 | Break-even price: at which BTC price does the miner cover its costs? | "The current price is X % above your break-even" or "attention: the current price is below your break-even" | High |
| F05.4 | Effect of the next difficulty adjustment on the reader's earnings | "The expected difficulty increase of X % reduces your daily earnings by about Y sats" | High |
| F05.5 | The reader's share of the network hashrate | "You represent 0.000X % of all Bitcoin computing power" | Medium |
| F05.6 | Mempool and fees in the mining context | "Mempool fees are high: miners currently earn X % more from fees than from the block subsidy" | Medium |

> **Implementation note.** Thesis 5 is entirely client-side. All calculations
> run in Dart on data that is already there (network hashrate and difficulty
> from mempool.space, the live price from Binance). No new backend is needed.
> The mining profile is stored locally in Hive (`mining_profile`). See the
> [mining calculator](../features/mining-calculator.md).

---

## Thesis 6 — Are the large holders accumulating or selling?

**Background.** The reader wants to know whether smart money is buying or
selling. Whales and long-term holders often set the direction of the market, but
their signals are hard to read without preparation.

**UX principle.** No raw wallet balances. The dashboard states a direction, for
example "large holders are buying" or "selling pressure is coming from smart
money", with the concrete reason.

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F06.1 | Exchange flows (BTC moving to and from exchanges) | "This week X,XXX BTC left exchanges: holders are moving coins into their own custody" or "inflows to exchanges rose: possible selling pressure" | High |
| F06.2 | Whale wallet trend (wallets above 1,000 BTC: a growing or shrinking group?) | "The number of wallets above 1,000 BTC rose by X this week: accumulation visible" | High |
| F06.3 | HODL waves: age of the coins that moved | "Long-term holders (over two years) began to sell this week" | Medium |
| F06.4 | Coin Days Destroyed (CDD) | "High CDD: old coins are moving, which points to distribution by early holders" | Medium |
| F06.5 | ETF flows (Bitcoin spot ETFs, where available) | "Today X million USD flowed into Bitcoin ETFs on balance" | High |

> **Data gap (critical).** F06.1 to F06.4 are mainly available from paid
> providers (Glassnode, CryptoQuant). F06.5 looks feasible through the CoinGlass
> API; its terms for display in an open-source app are still to be confirmed.
> The evaluation is tracked in [ADR-0002](../adr/0002-data-sources-and-apis.md).
> See the [whale and smart money](../features/whale-and-smart-money.md) note.

---

## Thesis 7 — How expensive is Bitcoin really, compared with what?

**Background.** A Bitcoin user does not think in absolute dollars but in
relative purchasing power. Expensive compared with what? Gold? Shares? The wage
it once took to buy it?

**UX principle.** No static chart. Always a clear ratio: *1 BTC = X ounces of
gold; more or less than last year?*

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F07.1 | Bitcoin against gold (in ounces) | "1 BTC buys X ounces of gold today; the highest/lowest value was Y" | High |
| F07.2 | Bitcoin against S&P 500 performance (YTD, 1 y, 4 y, since genesis) | "Bitcoin outperformed the S&P 500 by X % over the last four years" | High |
| F07.3 | Bitcoin against inflation (purchasing power of EUR/USD) | "1,000 € invested in Bitcoin in 2020 would be worth X € today; held in cash, Y € after inflation" | Medium |
| F07.4 | Satoshi purchasing power: what an everyday product costs in sats | "1 coffee (3.50 €) = X sats today; in 2020 it was Y sats" | Low |
| F07.5 | Bitcoin dominance in the crypto market | "Bitcoin holds X % of the crypto market; rising dominance means capital flows back to BTC" | Medium |

---

## Thesis 8 — What is happening in the Bitcoin world?

**Background.** The reader wants relevant news, without altcoin noise: only
Bitcoin, in their own language, linked directly.

**UX principle.** No unfiltered news API. Editorially curated sources,
Bitcoin only. The feed is personalised by language and region and sorts news by
topic: regulation, technology, market. The filtering is recorded in
[ADR-0006](../adr/0006-news-filtering-and-lexicon-tagging.md).

| ID | Requirement | Interpretation layer | Priority |
|---|---|---|---|
| F08.1 | News feed, **Bitcoin only** (no altcoin content, no general crypto noise) | Tag system: regulation / technology / market / mining / adoption, so the category is clear at a glance | High |
| F08.2 | Filtered by language and region (DE, EN, ES, FR, IT, PT, JA, KO, ZH, TR, …) | — | High |
| F08.3 | Regional Bitcoin media (German-language, Japanese, Brazilian sources) | — | High |
| F08.4 | Articles open in the system browser | — | High |
| F08.5 | News language(s) chosen manually, independent of the app language | — | Medium |
| F08.6 | Regulation radar: policy news by country (ETF status, legislation, bans) | "In [country], [development] is under way; this could mean [local effect]" | Medium |
| F08.7 | Sentiment indicator from news headlines (positive / neutral / negative) | Supplement to the Fear & Greed Index: "today's headlines are mostly [positive/negative]" | Low |

---

## F09 — App settings and internationalisation

F09 falls into two classes.

*Global preferences* live in the settings screen, reached through the gear in
the header: F09.1 to F09.6 and F09.8 to F09.13.

*Contextual preferences* live in their section, with a link from the
settings: **F09.7 (mining profile) belongs in the Miner section** and
**F09.14 (model preferences) in the Forecast section**. Thesis 5 asks for this
explicitly ("no static mining calculator hidden somewhere"); a profile that
lives only in the settings breaks that principle. The currency pill in the price
header is the pattern
([ADR-0007](../adr/0007-information-architecture-and-navigation.md)).

| ID | Requirement | Priority |
|---|---|---|
| F09.1 | Choose the preferred fiat currency (all common world currencies) | High |
| F09.2 | Choose the app language (at least DE, EN, ES, FR, IT, PT, JA, KO, ZH, TR) | High |
| F09.3 | Detect language and region automatically at first launch (device locale) | High |
| F09.4 | Change the language manually at any time in the settings | High |
| F09.5 | Dark mode / light mode | High |
| F09.6 | Choose preferred news language(s) independent of the app language | High |
| F09.7 | Manage the mining profile (hashrate TH/s, power W, electricity price ct/kWh) | High |
| F09.8 | Number formatting by locale (1.234,56 vs 1,234.56) | High |
| F09.9 | Date formatting by locale | Medium |
| F09.10 | Choose the fiat currency independent of the app language | High |
| F09.11 | Configure the automatic refresh interval | Medium |
| F09.12 | Price alerts (optional); only in a form that keeps the product values, with no account and no push service | Low |
| F09.13 | Right-to-left support (Arabic, Hebrew), later | Low |
| F09.14 | Manage model preferences (which forecast models are active) | High |

---

## Interpretation principles

These rules apply to every screen and every metric.

| Principle | Description |
|---|---|
| **No bare numbers** | Every metric has an accompanying sentence. A number alone is not enough. |
| **Context** | "X is high/low/normal", always relative to historical values or a target range. |
| **Clear relevance** | Where a metric bears on a decision (send now or wait), the app says so. |
| **Traffic light, not a wall of numbers** | Aggregated signals (market status, network health) are always shown with a colour and a status level. |
| **Historical placement** | "Last this high/low on [date]" gives the reader a memory without research. |
| **Plain language** | Technical terms (MVRV, NUPL, …) always come with a one-sentence explanation that can be expanded. |
| **Personal context** | Where a mining profile exists, global metrics are also related to the reader's own situation. |
| **Valuation, not advice** | A sentence states a reading and its historical context. It does not recommend buying, selling or holding. |

**Implementation.** The statements are produced in Dart. The levels a metric
can fall into are declared as a `BandScale` next to the metric's domain code
and carry the tone of a reading in each band
([CLAUDE.md §5](../../CLAUDE.md)); the text for each band is a localised ARB
key, not a literal in a widget. Shipping thresholds inside a CDN payload to
change them without an app update was considered; no payload does so today
([ADR-0005](../adr/0005-static-json-api-via-cdn.md)).
