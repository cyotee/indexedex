import { readFile, lstat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve, dirname } from "node:path";
import { isDeepStrictEqual } from "node:util";

export const ROOT = "/Users/cyotee/Projects/indexedex";
export const PHASE = `${ROOT}/.omo/ulw-execute/dtf-migration`;
export const SOURCE = `${PHASE}/phase32-nft-purchase-inputs/source`;
export const FROZEN = `${PHASE}/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const ARCH = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence";
export const V28 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/verification";
export const V30 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts/verification";
export const V31 = `${PHASE}/phase31-nft-observations/verification`;
export const W = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const E = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
export const WD = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
export const ED = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
export const WETH = "0x0bd7d308f8e1639fab988df18a8011f41eacad73";
export const CORE = "0x8333749cc7b1f66b5be568257d362aa749497cf0";
export const WF = "0xaaf47ef19c9b932b6d00bca3683b000fc6208661";
export const LOUPE = "0x343590ed92498739225e351c27133bc2c11b91b9";
export const ZERO = `0x${"0".repeat(40)}`;
export const TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";
export const identities = new Map();
export const counters = { checks: 0, bindings: 0 };
export class VerificationError extends Error {
  constructor(label) { super(label); this.name = "VerificationError"; }
}
export function check(condition, label) {
  counters.checks++;
  if (!condition) throw new VerificationError(label);
}
export function equal(actual, expected, label) {
  check(isDeepStrictEqual(actual, expected), label);
}
export const sha = bytes => createHash("sha256").update(bytes).digest("hex");
export async function raw(path) {
  const bytes = await readFile(path);
  identities.set(path, { path, bytes: bytes.length, sha256: sha(bytes) });
  return bytes;
}
export async function json(path) { return JSON.parse((await raw(path)).toString("utf8")); }
export async function binding(entry, directory) {
  const path = resolve(directory, entry.path);
  await raw(path);
  const actual = identities.get(path);
  check(actual.bytes === entry.bytes && actual.sha256 === entry.sha256, `raw binding ${path}`);
  counters.bindings++;
}
export async function sealed(directory) {
  const seal = await json(`${directory}/seal.json`);
  const manifest = seal.manifest ?? seal.bindings.find(x => x.path === "manifest.json");
  await binding(manifest, directory);
  for (const b of seal.bindings ?? []) await binding(b, directory);
  const body = await json(resolve(directory, manifest.path));
  for (const b of Array.isArray(body) ? body : body.files ?? body.entries) await binding(b, directory);
  return seal;
}
export function csv(bytes, path) {
  // Independent RFC4180 tokenizer. Mutable arrays accumulate logical records.
  const text = bytes.toString("utf8"), records = [];
  let row = [], value = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') { value += '"'; i++; }
      else quoted = !quoted;
    } else if (!quoted && (c === "," || c === "\n" || c === "\r")) {
      row.push(value); value = "";
      if (c !== ",") {
        records.push(row); row = [];
        if (c === "\r" && text[i + 1] === "\n") i++;
      }
    } else value += c;
  }
  check(!quoted, `closed CSV ${path}`);
  if (value || row.length) { row.push(value); records.push(row); }
  const header = records.shift();
  check(header && new Set(header).size === header.length, `CSV header ${path}`);
  return records.map((values, i) => {
    check(values.length === header.length, `CSV rectangular ${path}:${i + 2}`);
    return { locator: `${path}#row=${i + 2}`, row: i + 2, path,
      fields: Object.fromEntries(header.map((h, j) => [h, values[j]])) };
  });
}
export async function intake() {
  const producerSeal = await sealed(SOURCE);
  for (const dir of [V28, V30, V31, `${PHASE}/recipient-flow-review-verification`]) await sealed(dir);
  const recorded = await json(`${SOURCE}/inputs.json`);
  for (const b of recorded.acceptedEvidenceAndAuthorities) await binding(b, "/");
  const manifest = await json(`${FROZEN}/manifest.json`);
  await binding({ path: "sources.json", ...manifest.files["sources.json"] }, FROZEN);
  const index = await json(`${FROZEN}/sources.json`);
  const declarations = [...index.sources, ...Object.entries(manifest.files).map(([path, b]) => ({ path, ...b }))];
  const bodies = new Map();
  for (const b of declarations) {
    const path = resolve(FROZEN, b.path);
    let cursor = path;
    while (cursor !== dirname(cursor)) {
      check(!(await lstat(cursor)).isSymbolicLink(), `regular frozen ancestry ${cursor}`);
      cursor = dirname(cursor);
    }
    check(path.startsWith(dirname(FROZEN) + "/"), `frozen containment ${path}`);
    await binding(b, FROZEN);
    bodies.set(b.path, await raw(path));
  }
  check(declarations.length === 36 && bodies.size === 27, "complete frozen declarations");
  for (const [id, path] of [["S008", "evidence/weighted-bonds.csv"], ["S009", "evidence/earlier-cp-bonds.csv"]])
    check(index.sources.some(x => x.id === id && x.path === path), `declared ${id}`);
  const tables = new Map();
  for (const path of ["evidence/weighted-bonds.csv", "evidence/earlier-cp-bonds.csv", "evidence/transfers.csv",
    "../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv", "conversions.csv"])
    tables.set(path, csv(bodies.get(path), path));
  const commands = await json(`${SOURCE}/command-index.json`);
  for (const c of commands) {
    check(c.finishedAt && c.signal === null && Number.isInteger(c.exit), `stopped producer receipt ${c.path}`);
    await binding(c.stdout, "/"); await binding(c.stderr, "/");
    for (const b of c.sources) {
      // Earlier executed snapshots intentionally differ from current source.
      const path = b.path;
      const current = await raw(path);
      if (sha(current) !== b.sha256) {
        const snapshot = `${SOURCE}/${path.split("/").at(-1).replace(".mjs", "-executed01.mjs.txt")}`;
        await binding({ ...b, path: snapshot }, "/");
      } else check(current.length === b.bytes, `command source bytes ${path}`);
    }
  }
  equal(await raw(`${SOURCE}/reconcile-01.stdout`), await raw(`${SOURCE}/reconcile-repeat.stdout`), "producer deterministic repeat");
  return { producerSeal, tables, index, declarations, commands,
    a28: await json(`${V28}/actual/archive.json`), r28: await json(`${V28}/actual/reconciliation.json`),
    a30: await json(`${V30}/actual/archive.json`), r30: await json(`${V30}/actual/reconciliation.json`),
    ea: await json(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`),
    wa: await json(`${ARCH}/weighted/probe.sources.json`),
    current: await json(`${V31}/observations.json`),
    worksheet: await json(`${PHASE}/observed-recipient-flow-review-20261113.json`),
    producer: await json(`${SOURCE}/reconcile-01.stdout`),
    observation: await json(`${SOURCE}/observe-02.stdout`) };
}
