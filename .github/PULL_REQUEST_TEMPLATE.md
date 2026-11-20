Closes #

<!-- Slice: put the design link here, first line under "Closes". Chores, CI, Worker and docs
changes: mark the slice-only items below n/a instead of leaving them unchecked. -->

## What is visible now

<!-- The Statement: the claim the user now reads, in one sentence — not the widget that
carries it. Then the evidence: which figure backs which part of the claim. For a change
that renders nothing, say so. -->

## Data contract

<!-- Which CDN file or live endpoint and which fields this relies on, re-verified when and
how, or "none" for chores. -->

## Acceptance

<!-- Which target this change requires (CLAUDE.md §10), and whether it was run there.
If it was not, write "deferred" here with the target, why it was unavailable and what
stays unseen. Prose, not a checkbox: it stays deferred until someone runs it. -->

## Decisions taken

<!-- Every decision the run made that the issue did not make: what, and why. The reader
can overturn any of them in review. "None" is an answer. -->

## Deviations

<!-- Where the run left the slice skill or the issue, and why. "None" is an answer. -->

## Follow-ups

<!-- Issues to open after the merge, one line each: title, type, why. The merge approves
this list; nothing outside it is opened. "None" is an answer. -->

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
- [ ] Worker changes: `npm --prefix workers test` passes
- [ ] Docs updated in this PR (ADR or README where a decision or documented behaviour changed)

## Product values

- [ ] No new network host beyond those documented in ADR-0002
- [ ] No analytics, telemetry or crash-reporting dependency added
- [ ] No persistence beyond the local settings box
