# Non-functional requirements

Requirement IDs (`NF03.2`, …) are stable. The product values behind groups
NF03 and NF04 are binding constraints, not goals
([CLAUDE.md §1](../../CLAUDE.md)).

## NF01 — Platforms

| ID | Requirement |
|---|---|
| NF01.1 | Native app for macOS (minimum macOS 13 Ventura) |
| NF01.2 | Native app for Windows (minimum Windows 10) |
| NF01.3 | Native app for iOS (minimum iOS 16) |
| NF01.4 | Native app for Android (minimum Android 9, API 28) |
| NF01.5 | Linux where possible (no app store required) |

Web is a development and preview target only.

## NF02 — Performance

| ID | Requirement |
|---|---|
| NF02.1 | Cold start of the app in under 3 seconds |
| NF02.2 | API data is cached; the app remains usable without a network connection, showing the last data it has ([ADR-0005](../adr/0005-static-json-api-via-cdn.md)) |
| NF02.3 | Low resource use: under 150 MB of RAM in normal operation |

## NF03 — Privacy and security

| ID | Requirement |
|---|---|
| NF03.1 | No user account, no login |
| NF03.2 | Only public, non-personal data is processed |
| NF03.3 | No tracking SDKs (no Firebase Analytics or similar), no crash reporter, no telemetry |
| NF03.4 | No user identifier is stored anywhere. The Workers read public APIs and write static files; they receive no user traffic |
| NF03.5 | No third-party service receives user data. Every outbound host is a public, read-only endpoint, sees only the standard metadata of a request and is recorded in [ADR-0002](../adr/0002-data-sources-and-apis.md). The data pipeline runs on Cloudflare (Workers, R2, CDN) and serves the same static documents to every reader ([ADR-0003](../adr/0003-backend-cloudflare-workers-r2.md)) |
| NF03.6 | HTTPS for all connections (app to CDN and live APIs, Workers to data sources) |

The threat model that follows from these constraints is in
[SECURITY.md](../../SECURITY.md).

## NF04 — Cost and licence

| ID | Requirement |
|---|---|
| NF04.1 | The app is free for end users |
| NF04.2 | No in-app purchases, no advertising |
| NF04.3 | Source code is open source under the MIT licence ([LICENSE](../../LICENSE)) |
| NF04.4 | The running costs of the data pipeline are carried by the maintainer, not the users |

## NF05 — Internationalisation

| ID | Requirement |
|---|---|
| NF05.1 | App UI localised in at least 10 languages (priority: DE, EN, ES, FR, IT, PT-BR, JA, KO, ZH, TR); 15 is the long-term scope, see [internationalisation](../features/internationalisation.md) |
| NF05.2 | Currency formatting strictly by locale (symbol, decimal separator, thousands separator) |
| NF05.3 | Translations managed in ARB files (Flutter standard, extensible by the community) |
| NF05.4 | A new news language needs no app release: it is a new Worker and a new payload. UI strings are compiled into the app |
| NF05.5 | The news module supports a different source configuration per language |

## NF06 — Maintainability and scalability

| ID | Requirement |
|---|---|
| NF06.1 | One codebase for all platforms (Flutter) |
| NF06.2 | Modular architecture: features can be developed and switched off independently (feature-first layout, [CLAUDE.md §3](../../CLAUDE.md)) |
| NF06.3 | Testable core logic (unit tests for business logic) |
| NF06.4 | News sources and the currency list are changed in the Workers, not in the app: the feed lists are Worker configuration and the currencies follow the ECB feed. A Worker deploy, not an app release |
| NF06.5 | Data sources can be exchanged without an app change: the app depends on the payload contract ([ADR-0005](../adr/0005-static-json-api-via-cdn.md)), not on the upstream source |
