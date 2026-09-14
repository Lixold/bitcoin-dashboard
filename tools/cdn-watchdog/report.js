// MIT License — Copyright (c) 2026 Daniel Nagel
//
// Turning findings into the one thing the watchdog is allowed to emit: a
// GitHub issue. Pure — composing the text is separate from posting it, so
// the wording is testable and the posting is a thin shell around `gh`.
//
// The whole file exists to answer one question well: **what does an
// hourly job say when the same thing is still broken?** Opening an issue
// per run turns a one-day outage into twenty-four issues and the reader
// into someone who filters them out. So:
//
//   - one issue, one stable title, found by that title;
//   - a fingerprint over *which checks fail*, never over what they
//     measured — ages tick upward every run, and fingerprinting those
//     would comment hourly while saying nothing new;
//   - recovery is a comment, not a close. That the data is flowing again
//     is for a person to confirm.

import { createHash } from "node:crypto";

/** Stable across runs — this is how an open issue is recognised again. */
export const ISSUE_TITLE = "CDN watchdog: a published payload has gone silent or empty";

export const ISSUE_LABEL = "infra";

const MARKER = "watchdog-fingerprint";

/** Written when everything passes, so recovery is only ever said once. */
export const CLEAR_FINGERPRINT = "clear";

const MODE_TITLE = {
  stale: "Failure mode 1 — stale timestamp",
  thin: "Failure mode 2 — fresh timestamp, collapsed content",
  unreachable: "Unreachable — the file did not arrive",
};

const MODE_NOTE = {
  stale:
    "The Worker did not run, errored, or failed its R2 write. Look at the " +
    "Worker's cron and its logs in the Cloudflare dashboard.",
  thin:
    "The Worker ran and wrote successfully — the *upstream* source dried " +
    "up. The timestamp is current, so nothing but this check would have " +
    "noticed. Look at the source, not at the Worker.",
  unreachable:
    "The CDN did not serve the file, or served something that is not the " +
    "JSON it should be. Look at R2 and at the route before looking at the " +
    "producer.",
};

/** The failing rows, in table order. */
export function violations(results) {
  return results.filter((r) => r.findings.length > 0);
}

/**
 * A hash over which payload fails which check, in which mode.
 *
 * Deliberately not over the detail strings: those carry the measured age,
 * which differs every run and would defeat the deduplication it is here
 * to serve.
 */
export function fingerprint(results) {
  const failing = violations(results);
  if (failing.length === 0) return CLEAR_FINGERPRINT;
  const canonical = failing
    .flatMap((r) => r.findings.map((f) => `${r.key}|${f.mode}|${f.checkId}`))
    .sort()
    .join("\n");
  return createHash("sha256").update(canonical).digest("hex").slice(0, 16);
}

/** Recover the fingerprint a previous run left in an issue or comment. */
export function readFingerprint(text) {
  if (typeof text !== "string") return null;
  const match = text.match(new RegExp(`<!-- ${MARKER}: ([0-9a-z]+) -->`));
  return match ? match[1] : null;
}

function marker(value) {
  return `<!-- ${MARKER}: ${value} -->`;
}

/**
 * The body of the issue, or of the comment that follows a change in what
 * is failing.
 *
 * `context.source` names where the payloads were read from, so a proof
 * run against the broken fixtures can never be mistaken for a real alarm.
 */
export function renderReport(results, now, context = {}) {
  const failing = violations(results);
  const healthy = results.filter((r) => r.findings.length === 0);
  const lines = [];

  if (context.source && context.source !== "live") {
    lines.push(
      `> **This is not a real alarm.** The run read from \`${context.source}\`, ` +
        "not from the CDN. It exists to prove that a violation reaches this " +
        "issue at all.",
      "",
    );
  }

  lines.push(
    `${failing.length} of ${results.length} published payloads failed their ` +
      `checks at ${now.toISOString()}.`,
    "",
    "| Payload | Mode | What is wrong |",
    "|---|---|---|",
  );
  for (const row of failing) {
    for (const finding of row.findings) {
      lines.push(
        `| \`${row.path}\` | ${shortMode(finding.mode)} | ${finding.detail} |`,
      );
    }
  }
  lines.push("");

  for (const mode of ["stale", "thin", "unreachable"]) {
    const keys = failing
      .filter((r) => r.findings.some((f) => f.mode === mode))
      .map((r) => `\`${r.key}\``);
    if (keys.length === 0) continue;
    lines.push(
      `### ${MODE_TITLE[mode]}`,
      "",
      `Affects ${keys.join(", ")}.`,
      "",
      MODE_NOTE[mode],
      "",
    );
  }

  if (healthy.length > 0) {
    lines.push(
      `Passing: ${healthy.map((r) => `\`${r.key}\``).join(", ")}.`,
      "",
    );
  }

  lines.push(
    "The thresholds are declared in `tools/cdn-watchdog/payloads.js`; that " +
      "file is the only place the published payloads are enumerated.",
    "",
    marker(fingerprint(results)),
  );
  return lines.join("\n");
}

/**
 * What is said when everything passes again.
 *
 * It does not close the issue. A watchdog that closes its own report
 * hides the outage from whoever was going to look into it.
 */
export function renderRecovery(results, now) {
  return [
    `All ${results.length} published payloads passed their checks at ` +
      `${now.toISOString()}.`,
    "",
    "Leaving this issue open on purpose: that the data is flowing again is " +
      "for a person to confirm, and the cause is still worth a look.",
    "",
    marker(CLEAR_FINGERPRINT),
  ].join("\n");
}

/** One line for the job log and the step summary. */
export function renderLogLine(results, now) {
  const failing = violations(results);
  if (failing.length === 0) {
    return `${now.toISOString()} — all ${results.length} payloads pass.`;
  }
  const parts = failing.map(
    (r) => `${r.key}(${r.findings.map((f) => shortMode(f.mode)).join(",")})`,
  );
  return (
    `${now.toISOString()} — ${failing.length}/${results.length} failing: ` +
    parts.join(" ")
  );
}

function shortMode(mode) {
  if (mode === "stale") return "stale";
  if (mode === "thin") return "empty";
  return "unreachable";
}
