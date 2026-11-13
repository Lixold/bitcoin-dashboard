# ADR-0007 — Information architecture: six sections, adaptive navigation, where preferences live

- **Date:** 2026-09-01
- **Updated:** 2026-11-13 — v2: records the navigation as built
- **Status:** Accepted
- **Decider:** Lixold
- **Related:** [ADR-0004](0004-state-management-riverpod.md); CLAUDE.md §5 and
  §10; [functional requirements](../product/functional-requirements.md)

This ADR records decisions taken on 2026-09-01 and built in September 2026
(issues #63, #64, #65, #88). It describes the code as it stands.

## Version history

| Version | Date | Change |
|---|---|---|
| v1 | 2026-09-01 | Six sections, adaptive navigation, settings behind the header gear, contextual preferences |
| v2 | 2026-11-13 | Records the shipped breakpoints (768 / 1024) and the rule that a section appears with its first slice |

## Context

The product answers eight questions, called theses in the requirements
(price, valuation, forecast, network health, mining, large holders, relative
value, news). The app has to give every question a home, work from a phone
to a wide desktop window, and never show a screen that has nothing real to
say (CLAUDE.md §5). Preferences exist in two kinds: some apply everywhere
(language, currency, appearance), others only make sense inside one topic
(the mining profile, which forecast models to trust).

## Decision

**1. Six sections.** Each section is a destination and a route:

| Section | id / route | Theses |
|---|---|---|
| Price | `price` / `/price` | 1 (price), 7 (relative value) |
| Market | `market` / `/market` | 2 (valuation), 6 (large holders) |
| Forecast | `forecast` / `/forecast` | 3 |
| Network | `network` / `/network` | 4 |
| Miner | `miner` / `/miner` | 5 |
| News | `news` / `/news` | 8 |

The `NavSection` enum (`lib/features/navigation/domain/nav_section.dart`) is
the single place that knows id, icon asset, label key and route location, so
the navigation, the router and a deep link cannot disagree.

**2. Adaptive navigation.** A bottom `NavigationBar` below 768 logical
pixels, a `NavigationRail` from 768, a `NavigationDrawer` from 1024
(`NavigationLayout.forWidth`). The thresholds are the widths at which the
page layout already changes (`AppSpacing.tabletBreakpoint`,
`wideLayoutBreakpoint`), not the 640 and 1240 first proposed in issue #65:
two reflow points instead of four. The earlier floating pill was removed.

**3. A section exists once its first slice has shipped.** `hasShippedSlice`
is `false` for a section until the pull request that ships its first
user-visible capability flips it. Until then the section is absent from the
navigation and the routing table, not shown empty. Its id and label keys stay
in the enum and the ARB files so the next section to ship already has a name.
A deep link to such a section is turned away rather than rendered.

**4. Settings are a task, not a destination.** The gear in the screen header
opens `/settings` on top of the current section; closing it returns there.
On macOS the same screen opens with ⌘, from the app menu.

**5. Preferences live where they belong.** Global preferences — language,
currency, appearance, news languages, number and date formats, refresh
interval — live in the settings screen. Contextual preferences live in their
section, with a link from settings: the mining profile (F09.7) in Miner and
the forecast model selection (F09.14) in Forecast. Thesis 5 requires that the
miner's numbers are personalised in place; a profile reachable only through
settings would turn the section back into a calculator tucked away somewhere.
The currency pill in the price header is the pattern.

## Consequences

**Positive**

- The structure of the app is the structure of the theses; a new feature
  already knows which section it belongs to.
- No placeholder screens: the check is in the router, and a test opens every
  visible section, so a flag flipped without a screen fails CI.
- Two reflow points keep resizing a desktop window calm.

**Negative / risks**

- The navigation grows as slices ship. An early build shows three
  destinations, not six, and the layout must work with any number from three
  to six.
- Sections with a shipped slice depend on a flag that has to be flipped in the
  right pull request; forgetting it hides finished work.
- Contextual preferences make the settings screen a list of links as well as
  controls.
