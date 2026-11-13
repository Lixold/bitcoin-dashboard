# Feature: internationalisation

The app is for Bitcoin users worldwide. Language, currency and regional news
adapt to the reader. Internationalisation is part of the architecture from the
start; adding it later is expensive and error-prone. The requirements are NF05
in the
[non-functional requirements](../product/non-functional-requirements.md#nf05--internationalisation)
and F09.1 to F09.4, F09.6, F09.8 to F09.10 in the
[functional requirements](../product/functional-requirements.md#f09--app-settings-and-internationalisation).

Language of the app, language of the news and currency are three independent
settings. A reader can use the app in German, read news in German and English,
and see prices in Swiss francs.

## Languages

Ten languages are the target of the first full release; fifteen is the long-term
scope. The *wave* is the news rollout wave from
[ADR-0006](../adr/0006-news-filtering-and-lexicon-tagging.md): waves 1 to 4 make
up the first ten languages. News for a language can go live before its UI is
translated.

| Language | Locale | Default currency | Wave |
|---|---|---|---|
| English | `en` | USD | 1 |
| German | `de` | EUR | 1 |
| Turkish | `tr` | TRY | 2 |
| Portuguese (Brazil) | `pt_BR` | BRL | 2 |
| Spanish | `es` | USD or EUR | 3 |
| French | `fr` | EUR | 3 |
| Japanese | `ja` | JPY | 3 |
| Chinese (simplified) | `zh` | CNY | 4 |
| Korean | `ko` | KRW | 4 |
| Italian | `it` | EUR | 4 |
| Arabic (right to left) | `ar` | — | 5 |
| Russian | `ru` | RUB | 5 |
| Hindi | `hi` | INR | 5 |
| Bengali | `bn` | BDT | 5 |
| Urdu | `ur` | PKR | 5 |

The app ships `app_en.arb` and `app_de.arb` today. Feeds, sources and the
reasons for the order are in [news feed sources](../research/news-feed-sources.md).

## Currencies

All currencies of the ECB reference rate feed, updated daily by `cron-fx-rates`.
`data/fx-rates.json` carries 30 currencies as a full conversion matrix
([ADR-0005](../adr/0005-static-json-api-via-cdn.md)), and the app converts on the
device: `price_local = price_usd × fx_rates["USD"][currency]`.

The default currencies RUB, BDT and PKR in the table are not in that set, and
Arabic has no default yet. Before those languages ship, the default is either
another currency or the FX source gains a second provider; this has to be
decided with wave 5.

## Implementation

**Packages.** `flutter_localizations` and `intl`; ARB files as the translation
format, as is standard in Flutter. `l10n.yaml` makes `lib/l10n/app_en.arb` the
template; the generated classes live in `lib/l10n/generated/` and are never
edited by hand ([CLAUDE.md §3](../../CLAUDE.md)).

```
lib/l10n/
  app_en.arb      template language
  app_de.arb
  …
```

**Locale detection at launch** (F09.3):

1. Read the device locale.
2. Find the matching supported locale.
3. Fall back to English.
4. Set the default currency from the locale's region (de-DE gives EUR, ja-JP
   gives JPY).
5. Load the stored settings; they override the locale default.

Until this is built the app starts with English and USD.

**Numbers and dates** are formatted with `intl`: `NumberFormat.currency` for
prices, `NumberFormat.percentPattern` for percentages, `NumberFormat.compact`
for large amounts such as the market capitalisation, `DateFormat.yMd` for dates
and `DateFormat.jm` for times (12 or 24 hours by locale). Satoshis have no
decimal separator and take the locale's grouping.

**News.** There is no query endpoint. The app fetches `data/news-{lang}.json`
for every chosen news language and merges the lists on the device, newest first
([ADR-0005](../adr/0005-static-json-api-via-cdn.md)).

## Translation workflow

1. Base strings are maintained in English in `app_en.arb`.
2. Every user-facing string goes into `app_en.arb` and `app_de.arb` in the same
   pull request; other locales fall back to English until translated.
3. Initial translations of further languages come from a translation tool or
   are written by hand; who does them and how they are reviewed is open (see
   below).
4. Corrections from the community come as pull requests; ARB files are plain
   text.

## Open questions

- Right-to-left support for Arabic. Flutter supports it natively, but the UI
  needs its own tests before the release of `ar`.
- Whether translations can be delivered without an app update (remote strings).
  NF05.4 settles the news side; UI strings are compiled into the app.
- Who does the initial translations, and who reviews them?
- Store listings (screenshots, descriptions) in every language
  ([distribution](../deployment/distribution.md)).
