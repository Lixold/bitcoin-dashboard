# Architecture Decision Records (ADRs)

This directory is the canonical home of the architecture decisions for
Bitcoin Dashboard. Each ADR documents a single decision: its context, the
options considered, the choice that was made, and the consequences. ADRs
are write-once — later revisions add a new dated version row rather than
overwriting history.

There is no second copy. A decision is written and amended here, in
English, through a pull request like any other change; no other note,
document or mirror is authoritative. See
[CLAUDE.md §9](../../CLAUDE.md) for where every other kind of knowledge
lives.

## Index

| ID | Title | Status |
|---|---|---|
| [ADR-0001](0001-flutter-tech-stack.md) | Flutter as the cross-platform tech stack | Accepted |
| [ADR-0002](0002-data-sources-and-apis.md) | Public data sources and APIs | Accepted |
| [ADR-0003](0003-backend-cloudflare-workers-r2.md) | Backend: Cloudflare Workers + R2 + CDN | Accepted (v5) |
| [ADR-0004](0004-state-management-riverpod.md) | Riverpod for state management | Accepted |
| [ADR-0005](0005-static-json-api-via-cdn.md) | Client ↔ CDN API: static JSON objects | Accepted (v4) |

## Format

ADRs in this repository follow a lightweight variant of the
[MADR](https://adr.github.io/madr/) template. Each file is short and
self-contained, with sections for context, options, decision, and
consequences. Diagrams are kept inline so the files render in GitHub
without external assets.

The header of every ADR carries the date, the status, and the decider. The
decider is the maintainer's GitHub handle.

## Status values

| Status | Meaning |
|---|---|
| Proposed | Under discussion, not yet binding. |
| Accepted | Currently in force. |
| Superseded | Replaced by another ADR — link to the successor in the header. |
| Deprecated | No longer relevant, kept for historical context. |

## Contributing

New ADRs should be proposed via a pull request. The filename uses the
next free four-digit ID and a short kebab-case slug
(`NNNN-short-title.md`). Update the index table above in the same PR.
