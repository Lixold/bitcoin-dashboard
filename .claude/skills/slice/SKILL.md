---
name: slice
description: Implement one vertical slice of the Bitcoin Dashboard end to end — from GitHub issue to merged PR. Use whenever work starts on an issue labelled `slice`, or when someone says "take issue #N", "build the next slice", or names a feature to implement. Enforces the order data contract → design → provider + tests → UI → i18n → docs → PR.
---

# Vertical slice

One slice = one visible improvement backed by real data. The order below is not a
suggestion. Do not reorder it, do not skip a gate, do not start the next step while the
current one is unverified.

## Step 0 — Load the assignment

```bash
gh issue view <n> --comments
```

Extract: data contract (which JSON, which fields), design link, the one-sentence visible
result, DoD checklist.

**Gate.** If any of the four is missing, stop. Do not improvise them. Report what is
missing and ask for the issue to be completed, or open the prerequisite issue (for
example the Worker slice that produces the missing JSON).

## Step 1 — Verify the data contract against reality

```bash
curl -s https://data.bitcoin-dashboard.app/data/<file>.json | head -c 2000
```

Confirm every field the slice needs actually exists, with the type and unit you expect.
Note `generated_at` freshness.

**Gate.** If a field is missing or shaped differently than the issue assumes, stop and
report. Never adapt the UI to an assumed shape — the Worker changes first, as its own
slice.

## Step 2 — Design

The design must exist and be linked in the issue before UI work starts. Read it. Design only this slice, not the whole screen on spec. If the slice
needs a component the design system does not cover, extend the design first, then
implement.

## Step 3 — Branch

```bash
git checkout main && git pull --prune
git checkout -b slice/<n>-<short-topic>
```

Never commit to `main`.

## Step 4 — Provider and tests first

Implement the Riverpod provider with explicit loading, error and data states. Write the
tests in the same step:

- unit tests for pure logic (parsing, mapping, thresholds, intervals)
- widget test with `ProviderScope` overrides covering loading, error and data

**Gate.** Tests green before any UI code is written.

## Step 5 — UI

Build the UI against the real provider. No mock values, no static chart points, no `—`
placeholder. If something cannot show real data yet, it does not belong in this slice.

## Step 6 — i18n

Every user-visible string goes into `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`,
then `flutter gen-l10n`. No hardcoded strings in widgets.

## Step 7 — Verify locally

```bash
dart format .
flutter analyze
flutter test
# worker changes only:
cd workers && npm test
```

All must pass before committing.

## Step 8 — Docs in the same PR

- New or changed decision → add or update the ADR in `docs/adr/`.
- Behaviour documented in `README.md` changed → update it here, not later.
- Never leave documentation for "later" or for a separate session.

## Step 9 — Commit, push, PR

```bash
git commit -m "feat(<scope>): <what>"
git push -u origin slice/<n>-<short-topic>
gh pr create --fill --body-file <filled PR template>
```

The PR body follows `.github/PULL_REQUEST_TEMPLATE.md`, includes `Closes #<n>` and a
one-line statement of what is now visible.

## Step 10 — Hand over for acceptance

Run `.claude/skills/review/SKILL.md` against your own diff before reporting. Then
summarise in two sentences: what is now visible in the app, and what to look at when
running it.

## Stop conditions

Stop and ask rather than working around any of these:

- data contract missing or mismatched
- design missing for a visible element
- a required check fails for a reason you cannot attribute to your change
- the slice grows beyond one screen area or one data source — split it into two issues
