import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { loadCandidateInput, table } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/candidate-input.ts";

export const ROOT = "/Users/cyotee/Projects/indexedex";
export const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts";
export const PHASE = `${ROOT}/.omo/ulw-execute/dtf-migration`;
export const OUT = dirname(fileURLToPath(import.meta.url));
export const INPUT = `${PHASE}/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const ARCH = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence";
export const V28 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/verification";
export const V30 = `${WT}/docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts/verification`;
export const V31 = `${PHASE}/phase31-nft-observations/verification`;
export const W = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const SD = "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c";
export const F = "0x3a07364eaba092472d40f0e6788b8891a31fad4d";
export const L = "0x343590ed92498739225e351c27133bc2c11b91b9";
export const ZERO = `0x${"0".repeat(40)}`;
export const sha = b => createHash("sha256").update(b).digest("hex");
export class EvidenceError extends Error { constructor(message) { super(message); this.name = "EvidenceError"; } }
export function check(ok, message) { if (!ok) throw new EvidenceError(message); }
export const json = async p => JSON.parse(await readFile(p, "utf8"));
export const identity = async p => { const b = await readFile(p); return { path: p, bytes: b.length, sha256: sha(b) }; };
export const save = (name, data) => writeFile(join(OUT, name), `${JSON.stringify(data, null, 2)}\n`, { flag: "wx" });
export async function intake() {
  const input = await loadCandidateInput(INPUT), bindings = [];
  const bind = async (path, expected) => {
    const actual = await identity(path);
    if (expected) check(actual.bytes === expected.bytes && actual.sha256 === expected.sha256, `binding: ${path}`);
    bindings.push(actual);
    return path.endsWith(".json") ? json(path) : null;
  };
  // Accepted phase31 producer root authenticates its external archive/schema bindings.
  const producer = `${PHASE}/phase31-nft-observations/source`;
  const ps = await bind(`${producer}/seal.json`, { bytes: 2781, sha256: "dc8f757532b275af78cdd7b204bf1153238b99fc581699c45f17e35d65b52af6" });
  for (const b of ps.bindings) await bind(resolve(producer, b.path), b);
  for (const b of await json(`${producer}/source-manifest.json`)) await bind(b.path, b);
  const roots = [V28, V30, V31, producer, `${PHASE}/recipient-flow-review-verification`];
  for (const dir of roots) {
    const seal = await bind(`${dir}/seal.json`);
    const direct = Object.values(seal).filter(x => x && typeof x === "object" && typeof x.path === "string");
    for (const b of [...direct, ...(seal.bindings ?? [])]) await bind(resolve(dir, b.path), b);
    const manifest = await json(`${dir}/manifest.json`);
    const entries = Array.isArray(manifest) ? manifest : dir.endsWith("recipient-flow-review-verification") ? manifest.entries : manifest.files;
    for (const b of entries) await bind(resolve(dir, b.path), b);
  }
  const s31 = await json(`${V31}/seal.json`);
  check(s31.verdict === "confirmed" && s31.pendingOperations === 0 && s31.pin.number === "113279837", "phase31 stopped acceptance");
  const old28 = await json(`${V28}/actual/archive.json`), old30 = await json(`${V30}/actual/archive.json`);
  const current = await json(`${V31}/observations.json`);
  const wa = await json(`${ARCH}/weighted/probe.sources.json`);
  const ea = await json(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`);
  const contracts = { ...ea.contracts, ...wa };
  check(input.sources.sources.find(s => s.id === "S008")?.path === "evidence/weighted-bonds.csv", "S008 path");
  const rows = table(input, "evidence/weighted-bonds.csv");
  const refs = rows.flatMap(row => row.fields.claim_transactions === "" ? [] :
    row.fields.claim_transactions.split("|").map((tx, i) => {
      check(/^0x[0-9a-f]{64}$/.test(tx), `claim hash: ${row.locator}`);
      const priorIndex = old30.results.findIndex(x => x.tx === tx);
      return { locator: row.locator, collection: W, tokenId: row.fields.token_id, occurrence: i + 1, tx,
        capture: priorIndex < 0 ? "new" : "reused-phase30", priorIndex };
    }));
  check(rows.length === 43 && refs.length === 23 && new Set(refs.map(r => r.tx)).size === 23, "derived population");
  check(refs.filter(r => r.capture === "reused-phase30").length === 7, "seven accepted receipts");
  const oldHashes = new Set(old28.results.map(r => r.tx));
  check(refs.every(r => !oldHashes.has(r.tx)), "unexpected phase28 overlap");
  for (const row of rows) {
    const cur = current.rows.find(r => r.locator === row.locator);
    check(cur && JSON.stringify(cur.originalFields) === JSON.stringify(row.fields), `phase31 original: ${row.locator}`);
  }
  for (const file of ["candidate-input.ts", "receipt-association.ts", "receipt-rpc.ts", "provenance.ts", "schema.ts"]) {
    await bind(`${WT}/scripts/recovery/dtf-migration/${file}`);
  }
  await bind(`${PHASE}/phase33-nft-claim-receipts-brief.md`);
  const originals = { root: INPUT, declarations: input.bindings, sources: input.sources,
    identities: [...input.bytes].map(([path, b]) => ({ path, bytes: b.length, sha256: sha(b) })),
    qualification: "hash-authenticated recovered bodies, not located original captures" };
  return { input, originals, bindings, rows, refs, old28, old30, current, wa, contracts };
}
