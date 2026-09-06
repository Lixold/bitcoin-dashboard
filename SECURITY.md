# Security Policy

Thank you for helping keep Bitcoin Dashboard and its users safe. This
document explains how to report vulnerabilities, what is in scope, and
what response you can expect.

---

## Supported Versions

Bitcoin Dashboard is in active early-stage development. Only the latest
release on the `main` branch receives security updates.

| Version | Supported |
|---|---|
| Latest release on `main` | ✅ |
| Pre-release / older builds | ❌ |

Once tagged releases are published, this table will list the versions
that receive security fixes.

---

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security problems.**

Use one of the following private channels instead:

1. **Preferred — GitHub Private Vulnerability Reporting:**
   [Open a private advisory](https://github.com/Lixold/bitcoin-dashboard/security/advisories/new)
   on the repository. This keeps the report confidential and lets us
   coordinate a fix and disclosure timeline through GitHub.
2. **Alternative — Email:** `security@finhood.de`
   Please use the subject prefix `[SECURITY]` and, where possible,
   include a proof of concept, affected version/commit, platform, and
   any logs or stack traces. PGP is not required.

You will receive an acknowledgement within **72 hours**. We aim to
provide an initial assessment within **7 days** and, where applicable,
a fix or mitigation within **30 days** of confirmation. These targets
are best-effort — the project is currently maintained by a single
developer.

---

## Disclosure Policy

We follow **coordinated disclosure**:

- We will work with you on a fix and a public advisory.
- Please give us a reasonable window (typically up to 90 days) before
  any public disclosure.
- Once a fix is released, we will publish a GitHub Security Advisory
  crediting the reporter (unless you prefer to remain anonymous).

---

## Scope

### In scope

- The Flutter application source code in this repository (`lib/`,
  `test/`, platform projects under `android/`, `ios/`, `macos/`,
  `windows/`, `linux/`, `web/`).
- The Cloudflare Workers data pipelines under `workers/` (including
  the shared modules in `workers/_shared/`) and the GitHub Actions
  workflows under `.github/workflows/`.
- The integrity of the JSON data assets we publish to the CDN
  (`data.bitcoin-dashboard.app`, backed by Cloudflare R2 bucket
  `bitcoin-dashboard-data`) — for example, supply-chain attacks that
  could replace these files with malicious content.
- Build, release, and dependency-management configuration
  (`pubspec.yaml`, `pubspec.lock`, GitHub Actions, etc.).

Examples of issues we want to hear about:

- Remote code execution, arbitrary file read/write, or sandbox escape
  in the app.
- Crashes or denial-of-service triggered by malformed remote data.
- Insecure parsing of CDN payloads, RSS feeds, or third-party API
  responses.
- TLS / certificate validation issues.
- Local data exposure (e.g. unencrypted secrets in Hive boxes,
  insecure file permissions).
- Vulnerable or malicious transitive dependencies.
- Workflow misconfigurations that could leak secrets or allow
  unauthorised writes to the R2 bucket.

### Out of scope

- Vulnerabilities in third-party APIs we consume (Binance,
  mempool.space, alternative.me, CoinGecko, ECB XML feed, RSS news
  sources). Please report those to the respective providers.
- Vulnerabilities in the Flutter SDK, Dart SDK, GitHub Actions
  runners, or Cloudflare infrastructure. Please report those to the
  upstream maintainers.
- Issues that require a rooted, jailbroken, or otherwise compromised
  device, or that require physical access to an unlocked device.
- Social-engineering attacks against the maintainer or contributors.
- Denial-of-service attacks against public endpoints not operated by
  this project.
- Reports generated solely by automated scanners without a working
  proof of concept.

---

## Threat Model Notes

A few project facts that shape what is and isn't a vulnerability:

- **No accounts, no backend, no user data on our side.** The app does
  not collect, store, or transmit personal data. There are no
  credentials, sessions, or PII to leak server-side.
- **Static-data delivery only.** The CDN serves read-only JSON files
  produced by our cron-triggered Cloudflare Workers. There is no API
  server and no write path from the app.
- **Client-side currency conversion.** Calculations such as
  `price_local = price_usd × fx_rates[code]` happen on the device and
  rely on the integrity of `fx-rates.json`. CDN integrity is therefore
  in scope.
- **Local cache on device.** The app stores settings and cached data
  in [Hive](https://pub.dev/packages/hive) boxes inside the platform's
  per-app sandbox. Access to those files implies access to the user's
  account or device.
- **Links leave the app; the browser makes the connection.** Where the
  app offers a link — the About rows today, article links later — it
  hands the address to the platform's own browser through
  [`url_launcher`](https://pub.dev/packages/url_launcher) and reads
  nothing back. The binary opens no connection to a linked host, sends
  it no request and receives no response, so a link target is not a data
  source: it does not belong in the source list in
  [ADR-0002](docs/adr/0002-data-sources-and-apis.md) and it is not a new
  host under `CLAUDE.md` §1. What happens after the handover — which
  cookies travel, what the page loads — belongs to the user's browser
  session and is outside this app's control and outside this scope.

---

## Hall of Fame

Once we receive valid reports, contributors who choose to be named
will be listed here.

*No reports have been resolved yet.*
