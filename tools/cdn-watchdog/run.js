// MIT License — Copyright (c) 2026 Daniel Nagel
//
// The watchdog's entry point: fetch what is published, run the table over
// it, and report. Everything that touches the network, the clock, the
// filesystem or `gh` lives here; the judgement lives in checks.js and the
// wording in report.js.
//
// Usage:
//   node tools/cdn-watchdog/run.js [--source=live|fixture-broken] [--dry-run]
//
//   --source=live            read the CDN. The default and the only mode
//                            the schedule uses.
//   --source=fixture-broken  read the committed capture and break it on
//                            purpose — one payload aged past its
//                            threshold, one emptied. This is how the
//                            issue path is proven to fire without waiting
//                            for a real outage.
//   --dry-run                print what would be posted; touch nothing.
//
// Exit code: 0 whenever the watchdog did its job, *including* when it
// found violations and reported them. A red scheduled run means the
// watchdog itself is broken — that distinction is worth more than a
// second, noisier signal for something the issue already says.

import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { evaluateAll } from "./checks.js";
import { PAYLOADS } from "./payloads.js";
import {
  CLEAR_FINGERPRINT,
  ISSUE_LABEL,
  ISSUE_TITLE,
  fingerprint,
  readFingerprint,
  renderLogLine,
  renderRecovery,
  renderReport,
  violations,
} from "./report.js";

const HERE = dirname(fileURLToPath(import.meta.url));
const FIXTURE_DIR = join(HERE, "fixtures", "cdn-2026-09-13");

/**
 * The app's own origin, from `CdnClient.host`. The watchdog reads exactly
 * the URL the app reads — no cache-busting query, no `no-cache` header.
 * If the edge ever serves the app a stale copy, the watchdog should see
 * that same stale copy and say so; a watchdog that reaches past the cache
 * would call a payload healthy that no user can get.
 */
const CDN = "https://data.bitcoin-dashboard.app";

const USER_AGENT =
  "BitcoinDashboardWatchdog/1.0 (+https://github.com/Lixold/bitcoin-dashboard)";

const FETCH_ATTEMPTS = 3;
const FETCH_BACKOFF_MS = 2_000;

// === Fetching ==============================================================

/**
 * GET one payload, retrying a couple of times before calling it
 * unreachable.
 *
 * The shared Worker helper deliberately does not retry; a watchdog is the
 * opposite case. One transient 5xx must not open an issue, because an
 * alarm that is wrong once is an alarm that gets muted.
 */
async function fetchPayload(path) {
  let lastReason = "no attempt made";
  for (let attempt = 1; attempt <= FETCH_ATTEMPTS; attempt += 1) {
    try {
      const res = await fetch(`${CDN}/${path}`, {
        headers: { Accept: "application/json", "User-Agent": USER_AGENT },
      });
      if (!res.ok) {
        lastReason = `HTTP ${res.status} from ${CDN}/${path}`;
      } else {
        const text = await res.text();
        try {
          return { ok: true, json: JSON.parse(text) };
        } catch (exc) {
          // Not retried: a body that is not JSON is an answer, not a
          // hiccup, and asking twice will not change it.
          return {
            ok: false,
            reason: `body is not JSON (${exc.message}); ${text.length} bytes`,
          };
        }
      }
    } catch (exc) {
      lastReason = `${exc.name}: ${exc.message}`;
    }
    if (attempt < FETCH_ATTEMPTS) {
      await sleep(FETCH_BACKOFF_MS * attempt);
    }
  }
  return { ok: false, reason: `${lastReason} (${FETCH_ATTEMPTS} attempts)` };
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchAllLive(configs) {
  const entries = await Promise.all(
    configs.map(async (c) => [c.key, await fetchPayload(c.path)]),
  );
  return Object.fromEntries(entries);
}

// === The deliberately broken source ========================================

/**
 * The committed capture, with two documented injuries.
 *
 * `market.json` gets a timestamp from long ago — failure mode 1.
 * `news-en.json` gets an empty list — failure mode 2. Everything else is
 * served untouched, so a proof run also demonstrates that the healthy
 * files stay quiet.
 */
export function brokenFixtures(configs, now) {
  const out = {};
  for (const config of configs) {
    const json = JSON.parse(
      readFileSync(join(FIXTURE_DIR, `${config.key}.json`), "utf8"),
    );
    if (config.key === "market") {
      json.fetchedAt = new Date(now.getTime() - 72 * 3_600_000).toISOString();
    }
    if (config.key === "news-en") {
      json.news = [];
      json._meta.itemCount = 0;
    }
    out[config.key] = { ok: true, json };
  }
  return out;
}

// === GitHub ================================================================

function gh(args, input) {
  return execFileSync("gh", args, {
    encoding: "utf8",
    input,
    stdio: ["pipe", "pipe", "inherit"],
  });
}

function repoArgs() {
  return process.env.GITHUB_REPOSITORY
    ? ["--repo", process.env.GITHUB_REPOSITORY]
    : [];
}

/**
 * The open issue this watchdog owns, recognised by its exact title.
 *
 * Matched locally against the label's open issues rather than through
 * `--search`: the search index is eventually consistent, and an issue
 * this job opened minutes ago may not be findable yet — which is exactly
 * when a second one would be opened by mistake.
 */
function findOpenIssue() {
  const raw = gh([
    "issue",
    "list",
    ...repoArgs(),
    "--state",
    "open",
    "--label",
    ISSUE_LABEL,
    "--limit",
    "100",
    "--json",
    "number,title",
  ]);
  const found = JSON.parse(raw).find((i) => i.title === ISSUE_TITLE);
  return found ? found.number : null;
}

/**
 * The fingerprint the last run left behind — in the newest comment that
 * carries one, or in the issue body if no comment does.
 */
function lastFingerprint(number) {
  const raw = gh([
    "issue",
    "view",
    String(number),
    ...repoArgs(),
    "--json",
    "body,comments",
  ]);
  const issue = JSON.parse(raw);
  const texts = [issue.body, ...(issue.comments ?? []).map((c) => c.body)];
  for (let i = texts.length - 1; i >= 0; i -= 1) {
    const value = readFingerprint(texts[i]);
    if (value) return value;
  }
  return null;
}

// === Orchestration =========================================================

function parseArgs(argv) {
  const args = { source: "live", dryRun: false };
  for (const arg of argv) {
    if (arg.startsWith("--source=")) args.source = arg.slice("--source=".length);
    else if (arg === "--dry-run") args.dryRun = true;
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (!["live", "fixture-broken"].includes(args.source)) {
    throw new Error(`unknown source: ${args.source}`);
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const now = new Date();

  const fetched =
    args.source === "live"
      ? await fetchAllLive(PAYLOADS)
      : brokenFixtures(PAYLOADS, now);

  const results = evaluateAll(PAYLOADS, fetched, now);
  const line = renderLogLine(results, now);
  console.log(line);
  if (process.env.GITHUB_STEP_SUMMARY) {
    const { appendFileSync } = await import("node:fs");
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${line}\n`);
  }

  const failing = violations(results);
  const current = fingerprint(results);

  if (args.dryRun) {
    console.log("--- dry run, nothing posted ---");
    console.log(
      failing.length > 0
        ? renderReport(results, now, { source: args.source })
        : renderRecovery(results, now),
    );
    return;
  }

  const number = findOpenIssue();

  if (failing.length === 0) {
    if (number === null) return;
    if (lastFingerprint(number) === CLEAR_FINGERPRINT) return;
    gh(
      ["issue", "comment", String(number), ...repoArgs(), "--body-file", "-"],
      renderRecovery(results, now),
    );
    console.log(`Commented recovery on #${number}.`);
    return;
  }

  const body = renderReport(results, now, { source: args.source });

  if (number === null) {
    const url = gh(
      [
        "issue",
        "create",
        ...repoArgs(),
        "--title",
        ISSUE_TITLE,
        "--label",
        ISSUE_LABEL,
        "--body-file",
        "-",
      ],
      body,
    );
    console.log(`Opened ${url.trim()}`);
    return;
  }

  if (lastFingerprint(number) === current) {
    console.log(`#${number} already says this — not commenting again.`);
    return;
  }

  gh(
    ["issue", "comment", String(number), ...repoArgs(), "--body-file", "-"],
    body,
  );
  console.log(`Commented the change on #${number}.`);
}

// Only when run as the entry point — `brokenFixtures` is imported by the
// tests, and importing a module must not set off a live run.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((exc) => {
    console.error(`Watchdog failed: ${exc.message}`);
    process.exitCode = 1;
  });
}
