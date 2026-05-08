# Bitcoin Dashboard

A privacy-first Bitcoin app for macOS, Windows, iOS, Android, and Linux.

> **No login. No tracking. No ads. Open source.**

Bitcoin Dashboard gives you live Bitcoin market data, on-chain metrics, multilingual news, sentiment indicators, and price models — all without sending any personal data to a server.

---

## Features

- **Live Price** — Real-time BTC price via Binance public API, ~30 currencies supported
- **On-Chain Metrics** — Mempool, fees, hashrate, difficulty via mempool.space
- **Fear & Greed Index** — Daily sentiment score via alternative.me
- **Price History** — Charts for 1D / 7D / 30D / 90D / 1Y / ALL timeframes
- **Prognosis Models** — Stock-to-Flow (S2F) and other models
- **Multilingual News** — RSS-based news in 10 languages (EN, DE, ES, PT-BR, FR, IT, JA, KO, ZH, TR)
- **Currency Conversion** — ~30 fiat currencies via ECB exchange rates
- **Dark & Light Mode** — Native theme support on all platforms
- **Privacy First** — No account, no tracking, no analytics, fully local

---

## Screenshots

> *Coming soon*

---

## Tech Stack

| Area | Technology |
|---|---|
| Framework | Flutter / Dart 3 |
| Charts | fl_chart |
| HTTP | dio |
| Local Cache | Hive |
| State Management | Riverpod |

### Backend (Zero-Cost, No Server)

| Component | Technology | Cost |
|---|---|---|
| Data pipelines | GitHub Actions (Python cron jobs) | Free |
| Storage | Cloudflare R2 (static JSON) | Free tier |
| Delivery | Cloudflare CDN | Free |
| **Total** | | **~0 EUR/month** |

Live data (price, fees, Fear & Greed) is fetched **directly** by the app from public APIs — no backend required.

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
├── lib/                    # Flutter app source
│   ├── features/           # Feature modules (price, news, on-chain, …)
│   ├── core/               # Shared providers, models, utilities
│   └── main.dart
├── scripts/                # Python data pipeline scripts
├── .github/
│   └── workflows/          # GitHub Actions workflow definitions
├── test/                   # Unit & widget tests
└── docs/                   # Architecture Decision Records (ADRs)
```

---

## Data Sources

| Data | Source | How |
|---|---|---|
| Live BTC Price | Binance Public API | App fetches directly |
| Mempool / Fees / Hashrate | mempool.space | App fetches directly |
| Fear & Greed Index | alternative.me | App fetches directly |
| Price History | CDN `/data/history-{range}.json` | GitHub Actions → CoinGecko |
| FX Rates (~30 currencies) | CDN `/data/fx-rates.json` | GitHub Actions → ECB XML |
| News (10 languages) | CDN `/data/news-{lang}.json` | GitHub Actions → RSS |
| Prognosis Models | CDN `/data/prognosis-{model}.json` | GitHub Actions Python |
| Market Data | CDN `/data/market.json` | GitHub Actions → CoinGecko |

Currency conversion is performed **client-side**: `price_local = price_usd × fx_rates["EUR"]`

---

## Architecture Decisions

All major decisions are documented as Architecture Decision Records in [`docs/adr/`](docs/adr/):

| ADR | Decision | Status |
|---|---|---|
| ADR-001 | Flutter as cross-platform framework | ✅ Accepted |
| ADR-002 | Data sources & APIs | ✅ Accepted |
| ADR-003 | GitHub Actions + Cloudflare R2 + CDN (no server) | ✅ Accepted |
| ADR-004 | Riverpod for state management | ✅ Accepted |
| ADR-005 | Static JSON files via CDN (no API server) | ✅ Accepted |

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
