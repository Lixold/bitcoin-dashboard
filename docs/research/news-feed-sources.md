# Research: news feed sources and language strategy

The feeds behind the news section, the languages the app aims at, and the order
in which they go live. The way items are filtered and classified is recorded in
[ADR-0006](../adr/0006-news-filtering-and-lexicon-tagging.md); the feature is
described in [news and sentiment](../features/news-and-sentiment.md).

## Decision

Bitcoin Dashboard supports **15 languages** with Bitcoin-focused RSS feeds. They
go live in five waves, ordered by relevance, the quality of the available
sources and the size of the language group. Most outlets cover crypto in general, not
Bitcoin only, so every feed passes a keyword filter (ADR-0006).

English and German are live in the Workers `cron-news-en` and `cron-news-de`.
The other languages are planned; their feed lists below are the starting point.

## Language strategy

| Language | Wave | Why this wave |
|---|---|---|
| English (EN) | 1 | Required; the largest Bitcoin media ecosystem |
| German (DE) | 1 | Home market of the project; very good sources |
| Turkish (TR) | 2 | Very high Bitcoin demand in the face of inflation |
| Portuguese, Brazil (PT-BR) | 2 | Strong Bitcoin market in Brazil, good sources |
| Spanish (ES) | 3 | Large language group, good Iberian sources |
| French (FR) | 3 | Cointelegraph FR and three more high-quality sources |
| Japanese (JA) | 3 | Bitcoin is clearly regulated in Japan; CoinPost leads |
| Chinese, simplified (ZH) | 4 | The feed ecosystem is limited (see the note below) |
| Korean (KO) | 4 | Active community; RSS is limited |
| Italian (IT) | 4 | Solid sources, rather blockchain-general |
| Arabic (AR) | 5 | Right-to-left layout needed; sources exist but are thin |
| Russian (RU) | 5 | Technically available; see the note below |
| Hindi (HI) | 5 | India is a major crypto adoption market; native RSS sources are very thin |
| Bengali (BN) | 5 | Hardly any Bitcoin RSS; sources to be determined |
| Urdu (UR) | 5 | Hardly any Bitcoin RSS; sources to be determined |

## Feeds per language

"Type" says how much the outlet covers: **Bitcoin only**, *Bitcoin focus*, or
*general crypto*, which the keyword filter must cut down. The priority orders the
feeds inside one language.

### Wave 1

**English (EN)**, live

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Bitcoin Magazine | `https://bitcoinmagazine.com/feed` | Bitcoin only | 1 |
| Cointelegraph EN | `https://cointelegraph.com/rss` | General crypto | 2 |
| The Block | `https://www.theblock.co/rss.xml` | General crypto | 3 |
| NewsBTC | `https://www.newsbtc.com/feed/` | Bitcoin focus | 4 |
| CoinDesk | `https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml` | General crypto | 5 |

NewsBTC is read from the root feed because its Bitcoin category feed is empty;
the keyword filter removes what is off-topic.

**German (DE)**, live

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Blocktrainer | `https://www.blocktrainer.de/feed/` | Bitcoin only | 1 |
| BitcoinBlog.de | `https://bitcoinblog.de/feed/` | Bitcoin only | 2 |
| BTC-ECHO | `https://www.btc-echo.de/feed/` | General crypto | 3 |
| CryptoMonday | `https://cryptomonday.de/feed/` | General crypto | 4 |

### Wave 2

**Turkish (TR)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| BTCHaber | `https://www.btchaber.com/feed/` | Bitcoin focus | 1 |
| Koin Bülteni | `https://koinbulteni.com/feed/` | General crypto | 2 |
| CoinTurk | `https://coin-turk.com/feed/` | General crypto | 3 |
| KriptoKoin | `https://kriptokoin.com/feed/` | General crypto | 4 |

**Portuguese, Brazil (PT-BR)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| GuiaDoBitcoin | `https://guiadobitcoin.com.br/feed/` | Bitcoin focus | 1 |
| Livecoins | `https://livecoins.com.br/feed/` | General crypto | 2 |
| Cointelegraph PT | `https://pt.cointelegraph.com/rss` | General crypto | 3 |
| BeInCrypto PT | `https://beincrypto.com.br/feed/` | General crypto | 4 |

### Wave 3

**Spanish (ES)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Bit2Me Blog | `https://blog.bit2me.com/es/feed/` | Bitcoin focus | 1 |
| Cointelegraph ES | `https://es.cointelegraph.com/rss` | General crypto | 2 |
| BeInCrypto ES | `https://es.beincrypto.com/feed/` | General crypto | 3 |
| CryptoPlaza | `https://cryptoplaza.es/feed/` | General crypto | 4 |

**French (FR)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Journal du Coin | `https://journalducoin.com/feed/` | Bitcoin focus | 1 |
| Cryptoast | `https://cryptoast.fr/feed/` | General crypto | 2 |
| Cointelegraph FR | `https://fr.cointelegraph.com/rss` | General crypto | 3 |
| BeInCrypto FR | `https://fr.beincrypto.com/feed/` | General crypto | 4 |

**Japanese (JA)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| CoinPost | `https://coinpost.jp/?feed=rss2` | Market leader in Japan | 1 |
| Cointelegraph JP | `https://jp.cointelegraph.com/rss` | General crypto | 2 |
| Bitcoin.com JP | `https://news.bitcoin.com/ja/feed/` | Bitcoin focus | 3 |

### Wave 4

**Chinese, simplified (ZH)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Bitcoin.com ZH | `https://news.bitcoin.com/zh/feed/` | Bitcoin focus | 1 |
| Cointelegraph ZH | `https://zh.cointelegraph.com/rss` | General crypto | 2 |
| PANews | `https://www.panewslab.com/rss` | General crypto | 3 |

Mainland China blocks many Western crypto sites, so the sources suit readers in
Taiwan and Hong Kong better. More Chinese sources are added after evaluation.

**Korean (KO)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Cointelegraph KR | `https://kr.cointelegraph.com/rss` | General crypto | 1 |
| TokenInsight KR | `https://tokeninsight.com/rss/news/kr` | General crypto | 2 |
| BeInCrypto KO | `https://ko.beincrypto.com/feed/` | General crypto | 3 |

**Italian (IT)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Cointelegraph IT | `https://it.cointelegraph.com/rss` | General crypto | 1 |
| Conio Blog | `https://blog.conio.com/feed` | Bitcoin focus | 2 |
| Blockchain Italia | `https://www.blockchainitalia.io/feed/` | General blockchain | 3 |
| Young Platform | `https://youngplatform.com/blog/feed/` | General crypto | 4 |

### Wave 5

**Arabic (AR)**, right to left

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Cointelegraph AR | `https://ar.cointelegraph.com/rss` | General crypto | 1 |
| BeInCrypto AR | `https://ar.beincrypto.com/feed/` | General crypto | 2 |
| Bitcoin.com AR | `https://news.bitcoin.com/ar/feed/` | Bitcoin focus | 3 |

Right-to-left layout has to be enabled and tested in the UI before this
language ships.

**Russian (RU)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| Bits.media | `https://bits.media/feed/` | Bitcoin focus | 1 |
| Cointelegraph RU | `https://ru.cointelegraph.com/rss` | General crypto | 2 |
| BeInCrypto RU | `https://ru.beincrypto.com/feed/` | General crypto | 3 |
| Bitcoin.com RU | `https://news.bitcoin.com/ru/feed/` | Bitcoin focus | 4 |

The sources are legitimate news outlets. Russian-language coverage touches
sanctions-related topics; before this language goes live, review what the
filter lets through and decide how such items are treated.

**Hindi (HI)**

| Source | RSS URL | Type | Priority |
|---|---|---|---|
| BitcoinWorld | `https://bitcoinworld.co.in/feed/` | Bitcoin focus, India | 1 |
| CoinFunda | `https://coinfunda.com/feed/` | General crypto | 2 |
| Cointelegraph HI | `https://hi.cointelegraph.com/rss` | General crypto | 3 |

The native Hindi RSS ecosystem is very thin and many Indian outlets publish in
English. Check each source for actual Hindi content before implementing.

**Bengali (BN)** and **Urdu (UR)**: no Bitcoin-specific RSS ecosystem has been
found in either language, so the sources are open. The language can be prepared
technically (ARB files, locale) while the content waits for a source evaluation.
For Bengali a candidate to check is `https://bn.beincrypto.com/feed/`, if it
exists.

## Validation

The feed URLs for waves 2 to 5 come from desk research. They have not been
fetched and parsed. Before a language goes live, every URL is run through the
shared pipeline's parser: the response must be HTTP 200 and valid XML. In
operation the pipeline lists the feeds that answered in each run in
`_meta.validatedFeeds` of the payload
([ADR-0005](../adr/0005-static-json-api-via-cdn.md)); a feed that fails is
skipped for that run and the others are still published.

## Keyword filter

The filter is the same for every language: an item stays if its title or
description, folded to lower case without diacritics, contains `bitcoin`, `btc`,
`satoshi` or `lightning`. "blockchain" is deliberately left out; it is too
generic. The word "bitcoin" is spelled the same in most languages, so the list
needs no per-language additions. The definition is in
`workers/_shared/news_pipeline.js` and the reasoning in ADR-0006.

## Open decisions

- Bengali and Urdu: are there reliable native sources, or does the language fall
  back to English?
- Chinese: a separate source list for Taiwan and Hong Kong against mainland
  China?
- Hindi: check the sources for real Hindi content before wave 5.
- Arabic: settle the UI test status for right-to-left before the release.
