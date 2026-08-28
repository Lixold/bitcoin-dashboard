Closes #

## What is visible now

<!-- One sentence in terms of what the user sees. -->

## Data contract

<!-- Which CDN file and fields this relies on, or "none" for chores. -->

## Definition of Done

- [ ] Design exists and is linked in the issue
- [ ] Provider covers loading, error and data states
- [ ] UI renders real data — no placeholders, no mock values
- [ ] Strings localised in `app_en.arb` and `app_de.arb`
- [ ] Unit tests for pure logic added
- [ ] Widget test with provider overrides (loading / error / data)
- [ ] `dart format`, `flutter analyze`, `flutter test` pass locally
- [ ] Worker changes: `cd workers && npm test` passes
- [ ] Docs updated in this PR (ADR / changelog where applicable)

## Product values

- [ ] No new network host outside the `PRIVACY.md` allowlist
- [ ] No analytics, telemetry or crash-reporting dependency added
- [ ] No persistence beyond the local settings box
