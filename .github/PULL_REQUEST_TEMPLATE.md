Closes #

## What is visible now

<!-- The Statement: the claim the user now reads, in one sentence — not the widget that
carries it. Then the evidence: which figure backs which part of the claim. -->

## Data contract

<!-- Which CDN file and fields this relies on, or "none" for chores. -->

## Acceptance

<!-- Which target this change requires (CLAUDE.md §10), and whether it was run there.
If it was not, write "deferred" here with the target, why it was unavailable and what
stays unseen. Prose, not a checkbox: it stays deferred until someone runs it. -->

## Definition of Done

- [ ] Design exists and is linked in the issue
- [ ] Provider covers loading, error and data states
- [ ] UI renders real data — no placeholders, no mock values
- [ ] Every figure sits inside a Statement with its insight sentence — no bare numbers.
- [ ] Strings localised in `app_en.arb` and `app_de.arb`
- [ ] Insight-sentence categories are translation keys, not hard-coded copy.
- [ ] Unit tests for pure logic added
- [ ] Widget test with provider overrides (loading / error / data)
- [ ] `dart format`, `flutter analyze`, `flutter test` pass locally
- [ ] Worker changes: `cd workers && npm test` passes
- [ ] Docs updated in this PR (ADR / changelog where applicable)

## Product values

- [ ] No new network host outside the `PRIVACY.md` allowlist
- [ ] No analytics, telemetry or crash-reporting dependency added
- [ ] No persistence beyond the local settings box
