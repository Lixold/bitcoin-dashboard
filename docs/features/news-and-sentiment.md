# Feature: news and sentiment

Bitcoin-relevant news and indicators of market mood, so the reader gets a quick
picture of current events and of the general market psychology. News is the
News section and thesis 8; the Fear & Greed Index sits in the Market section
and belongs to thesis 2. The requirements are F08.1 to F08.7 and F02.2 in the
[functional requirements](../product/functional-requirements.md).

## Fear & Greed Index

- Today's score (0 to 100) and the band it falls in: extreme fear, fear,
  neutral, greed, extreme greed.
- The course of the last 30 days.
- Source: the alternative.me API, free and without a key, called by the app
  ([ADR-0002](../adr/0002-data-sources-and-apis.md)).

The five bands are declared as a `BandScale` in
`lib/features/market/domain/sentiment_band.dart`
([CLAUDE.md §5](../../CLAUDE.md)).

## News feed

The Workers read public RSS feeds per language, keep the Bitcoin items, add a
topic and a sentiment to each, and publish one file per language,
`data/news-{lang}.json` ([ADR-0005](../adr/0005-static-json-api-via-cdn.md)).
How items are filtered and classified is recorded in
[ADR-0006](../adr/0006-news-filtering-and-lexicon-tagging.md). New sources and
languages need no app update.

**Sources and rollout.** The feeds per language, and the five rollout waves, are
in [news feed sources](../research/news-feed-sources.md). English and German are
live; the others follow in waves.

**Language choice.** The reader may enable any number of news languages,
independent of the app language. The default is the language of the device.
Example: the app in German, news in German and English.

**UI**
- A chronological list across all chosen languages, mixed.
- Optionally a filter for a single language.
- A card shows title, source, date and a language badge, plus the topic and the
  sentiment of the item.
- A tap opens the article in the system browser. There is no in-app browser,
  for privacy.
- Pull to refresh.

**Topics and sentiment.** Every item carries zero or more of the tags
regulation, technology, market, mining and adoption, and one sentiment:
positive, neutral or negative. Both come from word lists in the Worker, not
from a third-party service, and describe the wording of a headline
(ADR-0006).

## Open questions

- A mixed feed across languages, or separate tabs per language?
- A maximum number of items in the feed, and pagination if a language grows
  beyond about 50 items (also an open question in ADR-0005).
- Translate headlines automatically, for example through a translation API in
  the backend?
- The floor and the feed mix for the English list (issue #60).
