---
name: slice
description: Take one GitHub issue of the Bitcoin Dashboard from "taken" to an open PR with green checks, in one run. Use whenever work starts on an issue ("take issue #N", "build the next slice", a feature to implement) — slice, chore or bug. For a slice it enforces the order data contract → design → provider + tests → UI → i18n → docs → review → PR → CI, and it stops only at the stop conditions at the end.
---

# One issue, one run

A run takes one issue from "taken" to **an open PR with green checks** without a human in
between. The human does two things: reads the PR and merges it. Everything else is yours.

- **Stop only at a stop condition** (list at the end). Every other open question is yours
  to decide: take the most reasonable reading, carry on, and write the decision into the PR
  under "Decisions taken". A question that could have been decided stalls the run; a
  recorded decision costs one commit to overturn in review.
- **The order of a slice is not a suggestion.** Do not reorder it, do not skip a gate, do
  not start the next step while the current one is unverified. A deviation that was
  unavoidable goes into the PR under "Deviations".
- **Use whichever route to GitHub works in the session.** Usually that is the GitHub
  connector; the other is the REST API through `gh api repos/Lixold/bitcoin-dashboard/...`.
  GraphQL is blocked in Claude Code cloud sessions, so `gh issue view`, `gh pr create` and
  `gh pr checks` fail there. The commands below are written as `gh api` calls; each has a
  connector equivalent. If one route fails, switch to the other instead of stopping.
- **Chores and bugs** run Steps 0, 3, 7, 8 and 9–13 only. Without a data contract, a
  design, a provider or a UI there is nothing to verify at Steps 1, 2, 4, 5 and 6; the
  issue's "Done when" replaces the slice Definition of Done, and the PR states that the
  change renders nothing where that is true (`CLAUDE.md` §10).

## Step 0 — Take the issue

Read the issue and its comments (connector, or):

```bash
gh api repos/Lixold/bitcoin-dashboard/issues/<n>
gh api repos/Lixold/bitcoin-dashboard/issues/<n>/comments
```

Extract: data contract (which JSON, which fields), design link, the Statement (the claim
the user reads, in one sentence — not the widget that carries it), the Evidence (which
figure backs which part of the claim), the Decisions and stop criteria the issue already
makes, DoD checklist.

**Gate.** Five preconditions, all of them present before any other step:

1. the data contract is verified, not assumed — by the issue, and again by you in Step 1;
2. a design for this slice is linked in the issue, **or** the issue is labelled
   `needs-design` and you create it in Step 2;
3. the statement the slice makes is written in one sentence;
4. the evidence is named — which figure backs which part of the statement;
5. the issue carries the Definition of Done checklist.

If any of the five is missing, stop. Do not improvise them. Report what is missing and
ask for the issue to be completed, or open the prerequisite issue (for example the Worker
slice that produces the missing JSON).

**Status is GitHub's own.** The issue's status on the board moves with GitHub's automation
when a branch or PR is linked to it and when that PR is merged. Set no label or field for
it.

**Acceptance target.** Decide now, from the split in `CLAUDE.md` §10, whether anything
in this change is platform-dependent. If it is, the issue names the target its acceptance
requires before Step 3 — have it added if it is missing. Deciding this after the work is
how a browser run gets claimed for a change it could never have shown.

**Plan.** Turn the issue's Definition of Done into a task list, one task per step below,
and keep it current. Use sub-agents for work that is independent — checking the data
contract beside writing the provider tests, say — and for the review in Step 9, which
needs a fresh context. Do not split one slice's provider and UI across agents.

## Step 1 — Verify the data contract against reality

```bash
curl -s https://data.bitcoin-dashboard.app/data/<file>.json | head -c 2000
curl -s https://mempool.space/api/<endpoint> | head -c 2000   # direct live calls
```

Confirm every field the slice needs actually exists, with the type and unit you expect.
Note `generated_at` freshness. Capture the payloads you will test against, untouched, under
`test/support/fixtures/`.

**Gate.** If a field is missing or shaped differently than the issue assumes, stop and
report. Never adapt the UI to an assumed shape — the Worker changes first, as its own
slice.

## Step 2 — Design

If the issue links a design, use it. If it is labelled `needs-design`, create it now.

**The input to a slice design is a thesis, not an existing screen.** Brief it as thesis,
statement, evidence, states, components, and what is out of scope. A design briefed from an
existing layout reproduces that layout's omissions. Build it on the design-system artifact
(Artifact tool, type Design), light and dark, with loading, data and error. Design only
this slice, not the whole screen on spec. If the slice needs a component the design system
does not cover, extend the design first, then implement.

Then post the design link as a comment on the issue and remove `needs-design` (connector,
or):

```bash
gh api repos/Lixold/bitcoin-dashboard/issues/<n>/comments -f body='Design: <link>'
gh api -X DELETE repos/Lixold/bitcoin-dashboard/issues/<n>/labels/needs-design
```

**Continue.** The design is read together with the PR; its link goes at the top of the PR
body. Stop at the design only when:

- the issue leaves **thresholds** to the run — a threshold is a product statement. Measure
  live values, propose the boundaries with the measurements and the tone per band, post
  design and measurements, and wait; or
- the issue's stop criteria ask for a design checkpoint, or an abort criterion of the
  issue triggers (for example: the reading sits in the same band at every measurement).

If the design tool or the design system is unreachable, stop. Do not improvise a design.

## Step 3 — Branch

```bash
git fetch origin main
git switch -c slice/<n>-<short-topic> origin/main     # chore/<n>-…, fix/<n>-… for those
```

The branch name from `CLAUDE.md` §6 wins over a branch name the session was started
with. Never commit to `main`.

## Step 4 — Provider and tests first

Implement the Riverpod provider with explicit loading, error and data states, and state its
retry cadence or decline one (`CLAUDE.md` §2). Write the tests in the same step:

- unit tests for pure logic (parsing, mapping, thresholds, intervals)
- widget test with `ProviderScope` overrides covering loading, error and data

**Gate.** Tests green before any UI code is written. If you wrote UI first, say so under
"Deviations".

## Step 5 — UI

Build the UI against the real provider. No mock values, no static chart points, no `—`
placeholder. If something cannot show real data yet, it does not belong in this slice.

Every figure sits inside a Statement with its insight sentence — no bare numbers.
Insight-sentence categories are translation keys, not hard-coded copy.

**Gate.** Before Step 6, list every figure this slice adds and name the sentence that
reads it — which figures the rule covers: `CLAUDE.md` §5. A figure you cannot point a
sentence at is a bare number: add the sentence or drop the figure. Do not ship the figure
and leave its sentence for a follow-up — a screen of bare metric cards is a rejection in
review.

## Step 6 — i18n

Every user-visible string goes into `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`,
then `flutter gen-l10n`. No hardcoded strings in widgets.

## Step 7 — Verify

```bash
dart format .
flutter analyze
flutter test
# worker changes only:
npm --prefix workers test
# tools changes only:
npm --prefix tools/cdn-watchdog test
```

All must pass before committing.

**Acceptance on Chrome** (when `CLAUDE.md` §10 says Chrome is enough): build and serve the
web release, then capture the states with Playwright — light and dark, loading, data and
error, at phone width. Force loading and error by holding or aborting the upstream request.

```bash
flutter build web --release --no-web-resources-cdn
```

Without `--no-web-resources-cdn` the build loads CanvasKit from `gstatic.com`, which the
cloud session's proxy blocks, and the canvas stays empty. Send the screenshots to the
maintainer in the conversation and describe what they show in the PR. A change that renders
nothing has no acceptance target; say so instead of running one.

## Step 8 — Docs in the same PR

- New or changed decision → add or update the ADR in `docs/adr/`.
- Behaviour documented in `README.md` changed → update it here, not later.
- Never leave documentation for "later" or for a separate session.

## Step 9 — Review before the PR

Run `.claude/skills/review/SKILL.md` against your own diff, in a sub-agent with a fresh
context, before anything is pushed. Fix every blocking finding and run Step 7 again. A
finding found here costs a commit; found after the PR it costs a commit and a CI round.

## Step 10 — Commit, push, PR

Open the PR with the connector, or:

```bash
git commit -m "feat(<scope>): <what>"            # chore(<scope>): …, fix(<scope>): …
git push -u origin slice/<n>-<short-topic>
gh api repos/Lixold/bitcoin-dashboard/pulls \
  -f title='<conventional title>' -f head='slice/<n>-<short-topic>' -f base=main \
  -F body=@<filled PR template>
```

The PR body follows `.github/PULL_REQUEST_TEMPLATE.md`, includes `Closes #<n>`, states the
Statement together with the evidence behind it, and fills **Decisions taken**,
**Deviations** and **Follow-ups**. The design link goes at the top. Items that cannot apply
to a chore are marked n/a, not left unchecked.

## Step 11 — Wait for CI, event-driven

Subscribe the session to the PR's activity and wait. A completed check suite wakes the
session, so do not poll `check-runs` in a loop. All required checks (`CLAUDE.md` §6) must
be green.

Read the checks with the connector, or:

```bash
gh api repos/Lixold/bitcoin-dashboard/commits/<sha>/check-runs --jq '.check_runs[] | {name,status,conclusion}'
```

On red: read the failing job, fix the cause, push, wait again. Up to three fix rounds for
the same failure; then stop. Review comments on the PR get the same treatment: address
them, push, wait.

## Step 12 — Hand over

When the checks are green, end the turn with a short report, and put the same at the top of
the PR:

- the Statement the user now reads in the app, and what to look at when running it, in
  two sentences;
- the acceptance target the change requires (`CLAUDE.md` §10) and whether it was run
  there — if it was not, acceptance is **deferred** in the PR: which target, why it was
  unavailable, and what stays unseen. Do not offer a run on a different target in its
  place — the review gate reads the claimed target against the diff and rejects one that
  could not have shown the change;
- the decisions you took, the deviations, and the follow-ups you will open after the merge.

Stay subscribed to the PR. The merge is the approval.

## Step 13 — After the merge

Triggered by the merge event of your PR, or by the maintainer saying it is merged.

1. Check that the issue is closed (`Closes #<n>` closes it at the merge). If it is not,
   close it as completed.
2. Open the issues listed under **Follow-ups** in the PR, one topic each, in the structure
   of the matching issue template, with `Follows #<n>` in the body. The merge approved that
   list: open exactly those, no others. A follow-up you thought of after the merge goes
   into your report, not into the backlog.

You never merge, never deploy Workers, never change repository settings, and never close
an issue by anything but a merged PR.

## Stop conditions

Stop and ask rather than working around any of these. Say what blocks, what you tried, and
what you recommend, in one message; ask the one question that unblocks, not several.

- the data contract is missing or mismatched (Step 0 gate, Step 1 gate)
- the issue leaves thresholds to the run, or its own stop criterion triggers (Step 2)
- the design is missing for a visible element and cannot be created (design tool or design
  system unreachable)
- a required check fails for a reason you cannot attribute to your change, or the same
  failure survives three fix rounds
- the slice grows beyond one screen area or one data source — finish the first issue, open
  the second
- the change needs something that is the maintainer's to give: a new outbound host
  (ADR-0002), a secret, a Worker deploy, a repository setting, a merge

Anything else is not a stop condition. Position of a statement on its screen, display
precision, which insight category a sentence belongs to, the name of a provider: decide,
and record it under "Decisions taken".
