// MIT License — Copyright (c) 2026 Daniel Nagel
//
// The watchdog's judgement, as pure functions. Nothing in this file
// fetches, writes, reads the clock or talks to GitHub — a payload and a
// `now` go in, a list of findings comes out. That is what makes both
// failure modes testable against a fixture instead of against the live
// CDN.
//
// A finding is `{ mode, checkId, detail }`. `mode` is one of the three
// the report speaks in:
//
//   "stale"       #43's failure mode 1 — the timestamp fell behind.
//   "thin"        #43's failure mode 2 — the timestamp is current and the
//                 content collapsed anyway.
//   "unreachable" Neither: the file did not arrive, or did not parse.
//                 Kept apart because it asks for a different look — at
//                 the CDN, not at the Worker.

/** Walk a path like `["_meta", "fetchedAt"]`; `undefined` if any hop misses. */
export function at(payload, path) {
  let node = payload;
  for (const step of path) {
    if (node === null || node === undefined || typeof node !== "object") {
      return undefined;
    }
    node = node[step];
  }
  return node;
}

const show = (path) => path.join(".");

// === Age ===================================================================

/**
 * Age of a timestamp in milliseconds, or `null` if it is not a timestamp.
 *
 * The `null` is the point: a missing or unparseable value must not become
 * `NaN` and slip through the `>` comparison as healthy. Callers turn
 * `null` into a finding of its own.
 *
 * `anchor: "date"` marks a day-granular value (`fx-rates._meta.date`).
 * `Date.parse` reads a bare `YYYY-MM-DD` as midnight UTC, which is the
 * anchor `FX_SOURCE_MAX_AGE` is calibrated against — see payloads.js.
 */
export function ageMs(value, now) {
  if (typeof value !== "string") return null;
  const t = Date.parse(value);
  if (Number.isNaN(t)) return null;
  return now.getTime() - t;
}

/**
 * Run one payload's freshness rules.
 *
 * `watches` names what the rule is actually about — the Worker that
 * writes the file, or the upstream source behind it — because those two
 * questions have different answers and different fixes.
 */
export function checkFreshness(payload, rules, now) {
  const findings = [];
  for (const rule of rules) {
    const value = at(payload, rule.at);
    const age = ageMs(value, now);
    if (age === null) {
      findings.push({
        mode: "stale",
        checkId: `freshness:${show(rule.at)}`,
        detail:
          value === undefined
            ? `${show(rule.at)} is missing`
            : `${show(rule.at)} is not a timestamp: ${JSON.stringify(value)}`,
      });
      continue;
    }
    if (age > rule.maxAge) {
      findings.push({
        mode: "stale",
        checkId: `freshness:${show(rule.at)}`,
        detail:
          `${show(rule.at)} is ${humanAge(age)} old, over the ` +
          `${humanAge(rule.maxAge)} allowed for the ${rule.watches} ` +
          `(${value})`,
      });
    }
  }
  return findings;
}

/** Round an age to the largest unit that still reads precisely. */
export function humanAge(ms) {
  const minutes = ms / 60_000;
  if (Math.abs(minutes) < 90) return `${Math.round(minutes)} min`;
  const hours = minutes / 60;
  if (Math.abs(hours) < 48) return `${hours.toFixed(1)} h`;
  return `${(hours / 24).toFixed(1)} d`;
}

// === Volume check builders =================================================
//
// Each builder returns `(payload) => finding | null`. They are small on
// purpose: the configuration table stays readable, and each rule is
// unit-testable without a payload fixture around it.

/** The array at `path` carries at least `min` entries. */
export function minItems(path, min) {
  return (payload) => {
    const value = at(payload, path);
    if (!Array.isArray(value)) {
      return thin(`volume:${show(path)}`, `${show(path)} is not an array`);
    }
    if (value.length < min) {
      return thin(
        `volume:${show(path)}`,
        `${show(path)} carries ${value.length}, floor is ${min}`,
      );
    }
    return null;
  };
}

/**
 * Two arrays are exactly as long as each other.
 *
 * Separate from `minItems` because it catches something a floor cannot:
 * 288 timestamps against 287 prices passes any floor and renders as a
 * chart silently shifted against its own time axis.
 */
export function sameLength(pathA, pathB) {
  return (payload) => {
    const a = at(payload, pathA);
    const b = at(payload, pathB);
    const id = `volume:${show(pathA)}=${show(pathB)}`;
    if (!Array.isArray(a) || !Array.isArray(b)) {
      return thin(id, `${show(pathA)} and ${show(pathB)} are not both arrays`);
    }
    if (a.length !== b.length) {
      return thin(
        id,
        `${show(pathA)} has ${a.length} entries, ${show(pathB)} has ${b.length}`,
      );
    }
    return null;
  };
}

/** Every named path holds a value that is neither missing nor null. */
export function allPresent(paths) {
  return (payload) => {
    const missing = paths.filter((p) => {
      const v = at(payload, p);
      return v === undefined || v === null;
    });
    if (missing.length === 0) return null;
    return thin(
      `volume:present:${paths.map(show).join(",")}`,
      `null or missing: ${missing.map(show).join(", ")}`,
    );
  };
}

/**
 * The count a payload declares about itself matches what it carries.
 *
 * A mismatch is neither staleness nor thinness in the ordinary sense —
 * the producer wrote a header and a body that disagree. Two comparisons,
 * and it catches a corruption that neither the floor above nor the schema
 * test in #42 would see.
 */
export function selfCount(arrayPath, declaredPath) {
  return (payload) => {
    const items = at(payload, arrayPath);
    const declared = at(payload, declaredPath);
    if (!Array.isArray(items) || typeof declared !== "number") return null;
    if (items.length !== declared) {
      return thin(
        `volume:selfcount:${show(arrayPath)}`,
        `${show(declaredPath)} says ${declared}, ${show(arrayPath)} carries ` +
          `${items.length}`,
      );
    }
    return null;
  };
}

/**
 * `fx-rates.json` is a square conversion matrix at the top level, one
 * object per currency, plus `_meta`.
 *
 * Four things have to hold together, and a missing one is invisible in
 * the app until some currency pair renders nothing: enough currencies,
 * the rows present are exactly the ones `_meta.currencies` announces
 * (the header-vs-body check the news files get from `selfCount`), every
 * row complete, and every self-rate 1.
 */
export function currencyMatrix(min) {
  const id = "volume:fx-matrix";
  return (payload) => {
    const declared = at(payload, ["_meta", "currencies"]);
    if (!Array.isArray(declared)) {
      return thin(id, "_meta.currencies is missing or not an array");
    }
    if (declared.length < min) {
      return thin(
        id,
        `_meta.currencies lists ${declared.length}, floor is ${min}`,
      );
    }

    const rows = Object.keys(payload).filter((k) => k !== "_meta");
    const announced = new Set(declared);
    const unannounced = rows.filter((r) => !announced.has(r));
    const absent = declared.filter((c) => !rows.includes(c));
    if (unannounced.length > 0 || absent.length > 0) {
      return thin(
        id,
        `_meta.currencies and the rows disagree — ` +
          `announced but absent: [${absent.join(", ")}], ` +
          `present but unannounced: [${unannounced.join(", ")}]`,
      );
    }

    for (const code of declared) {
      const row = payload[code];
      if (row === null || typeof row !== "object") {
        return thin(id, `row ${code} is not an object`);
      }
      const width = Object.keys(row).length;
      if (width !== declared.length) {
        return thin(
          id,
          `row ${code} has ${width} rates, expected ${declared.length}`,
        );
      }
      if (row[code] !== 1) {
        return thin(id, `${code}/${code} is ${row[code]}, expected 1`);
      }
    }
    return null;
  };
}

function thin(checkId, detail) {
  return { mode: "thin", checkId, detail };
}

// === Running the table =====================================================

/**
 * Judge one fetched payload against its configuration row.
 *
 * `fetched` is what the fetch layer produced: either `{ ok: true, json }`
 * or `{ ok: false, reason }`. A file that did not arrive is reported as
 * unreachable and nothing else — running volume checks against a payload
 * that is not there would only bury the one fact that matters.
 */
export function evaluatePayload(config, fetched, now) {
  if (!fetched.ok) {
    return [
      { mode: "unreachable", checkId: "fetch", detail: fetched.reason },
    ];
  }
  const findings = checkFreshness(fetched.json, config.freshness, now);
  for (const check of config.volume) {
    const finding = check(fetched.json);
    if (finding) findings.push(finding);
  }
  return findings;
}

/**
 * Judge the whole table. Returns one result per configured payload, in
 * table order, so the report reads the same way twice running.
 */
export function evaluateAll(configs, fetchedByKey, now) {
  return configs.map((config) => ({
    key: config.key,
    path: config.path,
    findings: evaluatePayload(
      config,
      fetchedByKey[config.key] ?? {
        ok: false,
        reason: "not fetched",
      },
      now,
    ),
  }));
}
