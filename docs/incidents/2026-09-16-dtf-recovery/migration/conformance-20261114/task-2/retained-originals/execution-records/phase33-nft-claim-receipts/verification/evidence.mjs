import { readFile, writeFile, readdir, lstat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";

export const OUT = dirname(fileURLToPath(import.meta.url));
export const ROOT = "/Users/cyotee/Projects/indexedex";
export const PHASE = `${ROOT}/.omo/ulw-execute/dtf-migration`;
export const SOURCE = `${PHASE}/phase33-nft-claim-receipts/source`;
export const INPUT = `${PHASE}/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`;
export const WT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts";
export const V30 = `${WT}/docs/incidents/2026-09-16-dtf-recovery/migration/recovery-receipts/verification`;
export const V28 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/verification";
export const V31 = `${PHASE}/phase31-nft-observations/verification`;
export const ARCH = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence";
export const W = "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e";
export const SD = "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c";
export const F = "0x3a07364eaba092472d40f0e6788b8891a31fad4d";
export const SF = "0xb7581fe833a2b2380dd786b345d61ffb734d36eb";
export const L = "0x343590ed92498739225e351c27133bc2c11b91b9";
export const ANCHOR = { number: "108944663", hash: "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733" };
export class VerificationError extends Error { constructor(message) { super(message); this.name = "VerificationError"; } }
export function requireEvidence(ok, label) { if (!ok) throw new VerificationError(label); }
export const equal = (a, b, label) => requireEvidence(isDeepStrictEqual(a, b), label);
export const sha = bytes => createHash("sha256").update(bytes).digest("hex");
export const json = async path => JSON.parse(await readFile(path, "utf8"));
export const save = (path, body) => writeFile(join(OUT, path), `${JSON.stringify(body, null, 2)}\n`, { flag: "wx" });
export async function identity(path) {
  const bytes = await readFile(path);
  return { path, bytes: bytes.length, sha256: sha(bytes) };
}
export async function bind(path, expected) {
  requireEvidence(!path.includes("/phase32"), "changing phase32 evidence forbidden");
  const actual = await identity(path);
  equal([actual.bytes, actual.sha256], [expected.bytes, expected.sha256], `identity ${path}`);
  return actual;
}
export function csv(text, path) {
  const records = [];
  let fields = [], value = "", quoted = false, closed = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { value += '"'; i++; }
      else if (c === '"') { quoted = false; closed = true; }
      else value += c;
    } else if (c === '"' && value === "" && !closed) quoted = true;
    else if ([",", "\n", "\r"].includes(c)) {
      fields.push(value); value = ""; closed = false;
      if (c !== ",") {
        records.push(fields); fields = [];
        if (c === "\r" && text[i + 1] === "\n") i++;
      }
    } else { requireEvidence(!closed && c !== '"', "CSV quoting"); value += c; }
  }
  requireEvidence(!quoted, "CSV termination");
  if (fields.length || value || closed) records.push([...fields, value]);
  const header = records.shift();
  requireEvidence(header?.length && new Set(header).size === header.length, "CSV header");
  return records.map((r, i) => {
    requireEvidence(r.length === header.length, "CSV width");
    return { locator: `${path}#row=${i + 2}`, fields: Object.fromEntries(header.map((h, j) => [h, r[j]])) };
  });
}
export async function intake() {
  const bindings = [], producerBindings = [];
  const seal = await json(`${SOURCE}/seal.json`);
  requireEvidence(seal.status === "COMPLETE-STOPPED-BOUNDED-PRODUCER" && seal.pendingOperationsAfterPublisherExit === 0, "stopped producer seal");
  producerBindings.push(await identity(`${SOURCE}/seal.json`));
  for (const b of [...seal.bindings, ...(await json(`${SOURCE}/manifest.json`)).files]) producerBindings.push(await bind(resolve(SOURCE, b.path), b));
  equal(await treeFiles(SOURCE), [...new Set(producerBindings.map(b => b.path))].sort(), "complete sealed producer inventory");
  const cleanup = await json(`${SOURCE}/cleanup.json`);
  requireEvidence(cleanup.pendingRpc === 0 && cleanup.pendingOwnedChildren === 0 && cleanup.allRecordedChildrenClosed, "producer cleanup");
  for (const c of cleanup.commands) requireEvidence(c.stoppedAt && Number.isInteger(c.exitCode), "actual producer command close");
  // Authenticate every external binding, not producer interpretations.
  for (const b of await json(`${SOURCE}/source-manifest.json`)) bindings.push(await bind(b.path, b));
  for (const dir of [V28, V30, V31, `${PHASE}/recipient-flow-review-verification`]) {
    const s = await json(`${dir}/seal.json`);
    bindings.push(await identity(`${dir}/seal.json`));
    const direct = Object.values(s).filter(x => x && typeof x === "object" && typeof x.path === "string");
    for (const b of [...direct, ...(s.bindings ?? [])]) bindings.push(await bind(resolve(dir, b.path), b));
    const m = await json(`${dir}/manifest.json`);
    for (const b of Array.isArray(m) ? m : m.files ?? m.entries) bindings.push(await bind(resolve(dir, b.path), b));
  }
  const manifest = await json(`${INPUT}/manifest.json`);
  const sourceBytes = await bind(`${INPUT}/sources.json`, manifest.files["sources.json"]);
  const sources = await json(`${INPUT}/sources.json`);
  requireEvidence(sources.chainId === 4663 && sources.sources.find(s => s.id === "S008").path === "evidence/weighted-bonds.csv", "input domain/S008");
  const declarations = [...sources.sources, ...Object.entries(manifest.files).map(([path, b]) => ({ path, ...b }))];
  const inputs = [await identity(`${INPUT}/manifest.json`), sourceBytes];
  for (const b of declarations) {
    const path = resolve(INPUT, b.path);
    requireEvidence(path.startsWith(`${dirname(INPUT)}/`), "input path boundary");
    for (let cursor = path; cursor !== dirname(cursor); cursor = dirname(cursor)) requireEvidence(!(await lstat(cursor)).isSymbolicLink(), "input symlink");
    inputs.push(await bind(path, b));
    // Read full authenticated bodies; CSV interpretation remains specific to S008.
  }
  const rows = csv(await readFile(`${INPUT}/evidence/weighted-bonds.csv`, "utf8"), "evidence/weighted-bonds.csv");
  const a30 = await json(`${V30}/actual/archive.json`), a28 = await json(`${V28}/actual/archive.json`);
  const refs = rows.flatMap(r => r.fields.claim_transactions === "" ? [] : r.fields.claim_transactions.split("|").map((tx, i) => {
    requireEvidence(/^0x[0-9a-f]{64}$/.test(tx), "original claim hash");
    const priorIndex = a30.results.findIndex(x => x.tx === tx);
    return { locator: r.locator, collection: W, tokenId: r.fields.token_id, occurrence: i + 1, tx, priorIndex };
  }));
  equal([rows.length, refs.length, new Set(refs.map(r => r.tx)).size, refs.filter(r => r.priorIndex >= 0).length], [43, 23, 23, 7], "derived population");
  requireEvidence(refs.every(r => !a28.results.some(x => x.tx === r.tx)), "prior phase28 overlap");
  const current = await json(`${V31}/observations.json`);
  requireEvidence(current.pin === "113279837" && current.pendingRequests === 0 && !current.blocker, "accepted current pin");
  const weighted = await json(`${ARCH}/weighted/probe.sources.json`);
  const earlier = await json(`${ARCH}/earlier-cp/probe-alchemy-retry.source.json`);
  return { bindings, producerBindings, inputs, declarations, rows, refs, a30, a28, current, contracts: { ...earlier.contracts, ...weighted }, weighted, seal, cleanup };
}
export async function wires(root, captures) {
  const map = new Map();
  for (const c of captures) {
    requireEvidence(Number.isSafeInteger(c.id) && c.id > 0 && !map.has(c.id), "wire ID uniqueness");
    const bodies = {};
    for (const k of ["request", "response"]) {
      if (!c[k]) { bodies[k] = null; continue; }
      await bind(resolve(root, c[k].path), c[k]);
      bodies[k] = await json(resolve(root, c[k].path));
    }
    equal(bodies.request, { jsonrpc: "2.0", id: c.id, method: c.method, params: c.params }, "wire request");
    if (bodies.response) equal([bodies.response.jsonrpc, bodies.response.id], ["2.0", c.id], "wire response identity");
    requireEvidence(!bodies.response || c.response.raw && (c.http?.status ?? c.httpStatus) === 200, "safe raw response");
    if ("result" in c && !c.failure) equal(c.result, bodies.response.result, "normalized wire result");
    map.set(c.id, { ...bodies, capture: c });
  }
  return map;
}
export const quantity = v => typeof v === "string" && /^0x(?:0|[1-9a-f][0-9a-f]*)$/.test(v) && BigInt(v) < 2n ** 256n;
const hash = v => typeof v === "string" && /^0x[0-9a-f]{64}$/.test(v);
const address = v => typeof v === "string" && /^0x[0-9a-f]{40}$/.test(v);
const hex = v => typeof v === "string" && /^0x(?:[0-9a-f]{2})*$/.test(v);
export function canonical(tx, o) {
  const { transaction: t, receipt: r, byHash: h, byNumber: n } = o;
  equal(h, n, "complete canonical block");
  equal([t.hash, r.transactionHash], [tx, tx], "transaction/receipt identity");
  requireEvidence(hash(tx) && hash(h.hash) && hash(h.parentHash) && quantity(h.timestamp) && quantity(t.blockNumber)
    && quantity(t.transactionIndex) && quantity(t.value) && quantity(t.nonce) && hex(t.input), "canonical schema");
  equal([t.blockHash, t.blockNumber, t.transactionIndex], [r.blockHash, r.blockNumber, r.transactionIndex], "receipt block/index");
  equal([t.blockHash, t.blockNumber], [h.hash, h.number], "header association");
  equal([t.from, t.to], [r.from, r.to], "endpoints");
  requireEvidence(address(t.from) && (t.to === null || address(t.to)) && r.status === "0x1" && BigInt(t.blockNumber) <= BigInt(ANCHOR.number), "status/endpoints/cutoff");
  if (t.chainId) requireEvidence(quantity(t.chainId) && BigInt(t.chainId) === 4663n, "transaction chainId");
  requireEvidence(h.transactions.every(hash) && new Set(h.transactions).size === h.transactions.length
    && h.transactions[Number(BigInt(t.transactionIndex))] === tx && h.transactions.filter(x => x === tx).length === 1, "unique indexed membership");
  let prev = -1n;
  for (const l of r.logs) {
    equal([l.transactionHash, l.blockHash, l.blockNumber, l.transactionIndex, l.removed], [tx, t.blockHash, t.blockNumber, t.transactionIndex, false], "log associations");
    requireEvidence(address(l.address) && l.topics.every(hash) && hex(l.data) && quantity(l.logIndex) && BigInt(l.logIndex) > prev, "log schema/order");
    prev = BigInt(l.logIndex);
  }
  return r.logs.length;
}
export async function treeFiles(root) {
  const paths = [];
  for (const x of await readdir(root, { withFileTypes: true })) {
    if (x.isDirectory()) paths.push(...await treeFiles(join(root, x.name)));
    else { requireEvidence(x.isFile(), "regular evidence file"); paths.push(join(root, x.name)); }
  }
  return paths.sort();
}
