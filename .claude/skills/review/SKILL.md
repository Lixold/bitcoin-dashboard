---
name: review
description: Review a Bitcoin Dashboard change against the product values and the Definition of Done before it is merged. Use before opening a PR, when a review is requested, or when reviewing an open PR. Checks privacy invariants, placeholder-free UI, i18n completeness, test coverage and documentation.
---

# Slice review

Review the diff, not the intention. Report findings as a short list, most severe first,
each with file and line. If nothing is wrong, say so in one line — do not invent
findings.

## 1. Product values (blocking)

- No new network host outside the allowlist in `PRIVACY.md`.
- No analytics, telemetry, crash-reporting or advertising dependency added to
  `pubspec.yaml` / `pubspec.lock` or to `workers/package.json`.
- No new persistence beyond the local settings box; nothing user-specific leaves the
  device.
- No identifier that could correlate a user across requests.

A finding here blocks the merge regardless of everything else.

## 2. Definition of Done (blocking)

- Provider covers loading, error and data.
- UI shows real data — no `—`, no mock list, no hardcoded chart points, no
  `TODO`/`FIXME` in the shipped path.
- Every figure sits inside a Statement with its insight sentence — no bare numbers.
  A screen of bare metric cards is a rejection: list the figures that carry no sentence
  and block the merge. This check fails on its own — a diff that is otherwise clean does
  not pass it.
- Every user-visible string is in both ARB files; no hardcoded strings in widgets.
- Insight-sentence categories are translation keys, not hard-coded copy.
- Tests added with the change: unit tests for pure logic, widget test with provider
  overrides for the three states.
- Docs updated in the same PR when a decision or a documented behaviour changed.
- PR body states the Statement the slice makes and the evidence behind it, and closes
  the issue.

## 3. Consistency

- English throughout: identifiers, comments, commit messages, PR body.
- Conventional Commits.
- Architecture invariants from `CLAUDE.md` section 9 respected; no reintroduced VPS,
  cron-for-data or per-worker duplication of `workers/_shared/`.
- Shared worker logic changed in `_shared/`, not copied into a worker.

## 4. Craft

- Error paths produce a usable state, not a silent empty widget.
- Polling intervals and backoff match the documented provider behaviour.
- No widget rebuild triggered by a provider that should be scoped narrower.

## Output

Findings first, then a one-line verdict: `ready to merge` or `blocked: <reason>`.
