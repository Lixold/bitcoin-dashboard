# Product overview

Bitcoin Dashboard is a free, native, cross-platform app for people who
follow Bitcoin. It shows market data, network metrics, multilingual news and
price models in the reader's own language and currency — without an account,
without tracking, and open source.

This page says what the product is for. How it is built is in
[CLAUDE.md](../../CLAUDE.md) and the [ADRs](../adr/README.md); what it must do
is in the [requirements](functional-requirements.md); what comes when is in
the [roadmap](roadmap.md).

## Vision

A plain, data-focused dashboard that tells a private Bitcoin user, at a
glance, what matters right now. The app does not hand over numbers and leave
the reading to the user. Every figure comes with the sentence that says what
it means — see [interpretation principles](functional-requirements.md#interpretation-principles).

## Audience

Private individuals interested in Bitcoin, worldwide. There is no portfolio
tracking and there are no personal data: the app uses public market data only,
shown in the user's language and currency.

## What the app answers

The app is organised around eight questions, called theses. Each belongs to
one of six sections of the app
([ADR-0007](../adr/0007-information-architecture-and-navigation.md)).

| Section | Question the section answers | Thesis |
|---|---|---|
| Price | What does a Bitcoin cost right now, in my currency and in sats? How expensive is it compared with gold, shares and inflation? | 1, 7 |
| Market | Is Bitcoin cheap or overheated by historical measures? What are the large holders doing? | 2, 6 |
| Forecast | Where does Bitcoin stand in year X according to which model? | 3 |
| Network | Is the Bitcoin network healthy and decentralised? | 4 |
| Miner | What does my own mining hardware earn, and does it pay off? | 5 |
| News | What is happening in the Bitcoin world, in my language? | 8 |

The detailed requirements per thesis are in
[functional requirements](functional-requirements.md); the feature notes in
[docs/features](../features/) describe individual modules.

## Platforms

macOS, Windows, iOS, Android and Linux. Web is a development and preview
target, not a shipped product. Minimum versions are in the
[README](../../README.md#supported-platforms).

## Principles

- **Privacy first.** No login, no personal data, no tracking
  ([CLAUDE.md §1](../../CLAUDE.md)).
- **Free.** No paywall, no advertising, MIT-licensed source.
- **Global.** Many languages, about 30 currencies, regional news
  ([internationalisation](../features/internationalisation.md)).
- **Statements over numbers.** Data backs the statement; it does not replace
  it.
- **Valuation, not advice.** The app describes where a price stands relative
  to a model or a historical range. It never tells the reader to buy, sell or
  hold.

## Where to look next

| Question | Document |
|---|---|
| How is it built? | [System overview](../architecture/system-overview.md), [ADRs](../adr/README.md) |
| What must it do? | [Functional](functional-requirements.md) and [non-functional](non-functional-requirements.md) requirements |
| What is planned? | [Roadmap](roadmap.md) |
| How do I contribute? | [CLAUDE.md](../../CLAUDE.md), [README](../../README.md#contributing) |
