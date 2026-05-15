# Bitcoin Dashboard

Live BTC prices, on-chain metrics, multilingual news, and price models for macOS, Windows, iOS, Android, and Linux.

> **No login. No tracking. No ads. Open source.**

Bitcoin Dashboard reads market data, mempool state, sentiment, and curated news directly on your device — no account, no analytics, no server holding your data.

---

## Features

- **Live Price** — Real-time BTC price via Binance public API, ~30 currencies supported
- **On-Chain Metrics** — Mempool, fees, hashrate, difficulty via mempool.space
- **Network Health** — Reachable node count (Bitnodes) and chain tip status (mempool.space)
- **Fear & Greed Index** — Daily sentiment score via alternative.me
- **Price History** — Charts for 1D / 1W / 1M / 3M / 1Y timeframes
- **Market Snapshot** — Market cap, 24 h volume, supply, and 24 h change
- **Multilingual News** — RSS-based news; EN and DE available today, 13 more languages planned (ES, PT-BR, FR, IT, JA, KO, ZH, TR, …)
- **Currency Conversion** — ~30 fiat currencies via daily ECB reference rates
- **Prognosis Models** — Stock-to-Flow and additional valuation models *(roadmap)*
- **Dark & Light Mode** — Native theme support on all platforms
- **Privacy First** — No account, no tracking, no analytics; settings stay on device

---

## Screenshots

> *Coming soon*

---

## Tech Stack

### Application

| Area | Technology |
|---|---|
| Framework | Flutter / Dart 3 |
| Charts | fl_chart |
| HTTP | dio |
| Local Cache | Hive |
| State Management | Riverpod |

### Backend (Serverless, no origin server)

| Component | Technology |
|---|---|
| Batch data pipelines | Cloudflare Workers (JS cron triggers) |
| Storage | Cloudflare R2 (static JSON objects) |
| Delivery | Cloudflare CDN (`data.bitcoin-dashboard.app`) |
| Deploy automation | GitHub Actions → Wrangler |

Live data (price, mempool, fees, sentiment) is fetched **directly** by the app from public APIs — there is no API server in between. Aggregated and rate-limited sources (price history, FX rates, news, network stats) are produced by Cloudflare Workers on a cron schedule and published as static JSON to R2.

---

## Supported Platforms

| Platform | Minimum Version |
|---|---|
| macOS | 13+ |
| Windows | 10+ |
| iOS | 16+ |
| Android | 9+ (API 28) |
| Linux | ✓ |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.41+)
- Dart 3.11+

Verify your setup before the first run:

```bash
flutter doctor
```

### Clone & install

```bash
git clone https://github.com/Lixold/bitcoin-dashboard.git
cd bitcoin-dashboard
flutter pub get
```

`flutter pub get` also (re)generates the localisation classes under
`lib/l10n/generated/` via `gen-l10n` — no extra step needed.

### Run in a browser (Chrome) — fastest path

No Xcode or Android SDK required. This is the recommended way to try the
app or iterate on UI changes; it works on any host that has Chrome.

```bash
flutter run -d chrome
```

The dev build hot-reloads on save (press `r` in the terminal for a hot
reload, `R` for a hot restart). To produce a release build that you can
serve from any static host:

```bash
flutter build web --release
# Output: build/web/  — point any static webserver at this directory
```

> Web is supported as a **development and preview target**. The shipped
> product is the native app (macOS / Windows / iOS / Android / Linux);
> see [Supported Platforms](#supported-platforms) above.

### Run on native targets

Each native target needs its own platform toolchain in working order —
`flutter doctor` will tell you which ones are ready:

```bash
flutter run -d macos        # requires a working Xcode + CocoaPods
flutter run -d ios          # requires Xcode + an iOS simulator or device
flutter run -d android      # requires Android Studio + an emulator or device
flutter run -d windows      # Windows host only
flutter run -d linux        # Linux host only
```

List the devices/targets that Flutter currently sees:

```bash
flutter devices
```

---

## Project Structure

```
bitcoin-dashboard/
├── lib/                       # Flutter app source
│   ├── features/              # Feature modules (price, settings, shell, …)
│   ├── core/                  # Shared HTTP client, theme, utilities
│   ├── l10n/                  # ARB localisation files + generated classes
│   └── main.dart
├── workers/                   # Cloudflare Workers (cron-triggered fetchers)
│   ├── _shared/               # Shared helpers (lib.js, news_pipeline.js)
│   ├── cron-history/          # CoinGecko → history-*.json + market.json
│   ├── cron-fx-rates/         # ECB → fx-rates.json (daily)
│   ├── cron-news-en/          # RSS EN → news-en.json
│   ├── cron-news-de/          # RSS DE → news-de.json
│   └── cron-network-stats/    # Bitnodes + mempool.space → network-stats.json
├── scripts/                   # Archived Python pipeline scripts (reference)
├── .github/workflows/         # CI (Flutter analyze/test) + Worker deploys
└── test/                      # Unit & widget tests
```

---

## Data Sources

| Data | Source | How |
|---|---|---|
| Live BTC Price | Binance Public API | App fetches directly |
| Mempool / Fees / Hashrate | mempool.space | App fetches directly |
| Fear & Greed Index | alternative.me | App fetches directly |
| Price History | CDN `/data/history-{range}.json` | Cloudflare Worker → CoinGecko |
| Market Snapshot | CDN `/data/market.json` | Cloudflare Worker → CoinGecko |
| FX Rates (~30 currencies) | CDN `/data/fx-rates.json` | Cloudflare Worker → ECB XML |
| News (EN, DE today) | CDN `/data/news-{lang}.json` | Cloudflare Worker → RSS |
| Network Stats | CDN `/data/network-stats.json` | Cloudflare Worker → Bitnodes + mempool.space |
| Prognosis Models *(roadmap)* | CDN `/data/prognosis-{model}.json` | Cloudflare Worker |

Currency conversion is performed **client-side**: `price_local = price_usd × fx_rates["EUR"]`

---

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

## Privacy

Bitcoin Dashboard does **not** collect, store, or transmit any personal data. All settings are stored locally on your device.

---

*Built with ❤️ for the Bitcoin community.*
