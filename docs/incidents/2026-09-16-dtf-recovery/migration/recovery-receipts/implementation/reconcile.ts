import assert from "node:assert/strict";
import { readFile, writeFile, readdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { z } from "zod";
import { id } from "ethers";
import { preparationInput } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { preparedEnvelope } from "../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { executionManifest } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

// Independent producer-side oracle: no collector/association/CSV/reconciliation imports.
const base = dirname(fileURLToPath(import.meta.url)), actual = join(base, "actual");
const input = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery";
const digest = (b: Uint8Array) => createHash("sha256").update(b).digest("hex");
const json = async (p: string): Promise<unknown> => JSON.parse(await readFile(p, "utf8"));
const binding = z.object({ bytes: z.number().int(), sha256: z.string() });
const inputManifest = z.object({ files: z.record(binding) }).parse(await json(join(input, "manifest.json")));
async function authenticate(path: string, expected: z.infer<typeof binding>) {
  const b = await readFile(resolve(input, path));
  assert.equal(b.length, expected.bytes); assert.equal(digest(b), expected.sha256);
  return { path, ...expected };
}
const sb = inputManifest.files["sources.json"]; assert.ok(sb);
await authenticate("sources.json", sb);
const sources = z.object({ chainId: z.literal(4663),
  evidenceCutoff: z.object({ block: z.literal(108944663), hash: z.literal("0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") }),
  sources: z.array(binding.extend({ path: z.string() })) }).parse(await json(join(input, "sources.json")));
const declarations = [];
for (const [path, b] of Object.entries(inputManifest.files)) declarations.push(await authenticate(path, b));
for (const b of sources.sources) declarations.push(await authenticate(b.path, b));

function csv(text: string): readonly Readonly<Record<string, string>>[] {
  const cells = [...text.matchAll(/("(?:[^"]|"")*"|[^",\r\n]*)(,|\r?\n|$)/g)];
  const rows: string[][] = []; let row: string[] = [];
  let consumed = 0;
  for (const cell of cells) {
    if (cell[0] === "") continue;
    assert.equal(cell.index, consumed); consumed += cell[0].length;
    const raw = cell[1]; assert.notEqual(raw, undefined);
    row.push(raw?.startsWith('"') ? raw.slice(1, -1).replaceAll('""', '"') : raw ?? "");
    if (cell[2] !== ",") { rows.push(row); row = []; }
  }
  assert.equal(consumed, text.length); assert.equal(row.length, 0);
  const header = rows.shift(); assert.ok(header);
  assert.equal(new Set(header).size, header.length);
  return rows.map((r) => {
    assert.equal(r.length, header.length);
    return Object.fromEntries(header.map((h, i) => { const v = r[i]; assert.notEqual(v, undefined); return [h, v ?? ""]; }));
  });
}
const originals = [];
for (const path of ["conversions.csv", "observed-recoveries.csv"]) {
  const rows = csv(await readFile(join(input, path), "utf8"));
  originals.push(...rows.map((fields, i) => ({ locator: `${path}#row=${i + 2}`, path, fields })));
}
const q = z.string().regex(/^0x(?:0|[1-9a-f][0-9a-f]*)$/);
const h = z.string().regex(/^0x[0-9a-f]{64}$/), a = z.string().regex(/^0x[0-9a-f]{40}$/);
const assoc = { blockHash: h, blockNumber: q, transactionIndex: q };
const txSchema = z.object({ ...assoc, hash: h, from: a, to: a.nullable(), value: q, input: z.string() }).passthrough();
const logSchema = z.object({ ...assoc, transactionHash: h, logIndex: q, address: a,
  topics: z.array(h), data: z.string(), removed: z.literal(false) }).passthrough();
const receiptSchema = z.object({ ...assoc, transactionHash: h, from: a, to: a.nullable(),
  status: z.literal("0x1"), logs: z.array(logSchema) }).passthrough();
const blockSchema = z.object({ hash: h, number: q, parentHash: h, timestamp: q, transactions: z.array(h) }).passthrough();
const captures = z.array(z.object({ id: z.number(), method: z.enum(["eth_chainId", "eth_getTransactionByHash",
  "eth_getTransactionReceipt", "eth_getBlockByHash", "eth_getBlockByNumber"]), params: z.array(z.unknown()),
  request: binding.extend({ path: z.string() }), response: binding.extend({ path: z.string(), raw: z.literal(true),
    receivedBytes: z.number() }), http: z.object({ status: z.literal(200) }), outcome: z.literal("success") }))
  .parse(await json(join(actual, "http-manifest.json")));
const responses = new Map<string, unknown>(), rawIdentities = [];
const ids = new Set<number>();
for (const c of captures) {
  assert.ok(!ids.has(c.id)); ids.add(c.id);
  for (const b of [c.request, c.response]) {
    const bytes = await readFile(join(actual, "http", b.path));
    assert.equal(bytes.length, b.bytes); assert.equal(digest(bytes), b.sha256);
    rawIdentities.push({ path: `http/${b.path}`, bytes: b.bytes, sha256: b.sha256 });
  }
  assert.equal(c.response.bytes, c.response.receivedBytes);
  assert.deepEqual(await json(join(actual, "http", c.request.path)), { jsonrpc: "2.0", id: c.id, method: c.method, params: c.params });
  const r = z.object({ jsonrpc: z.literal("2.0"), id: z.number(), result: z.unknown() }).strict()
    .parse(await json(join(actual, "http", c.response.path)));
  assert.equal(r.id, c.id);
  const key = JSON.stringify([c.method, c.params]); assert.ok(!responses.has(key)); responses.set(key, r.result);
}
assert.equal((await readdir(join(actual, "http"))).length, rawIdentities.length);
const get = (method: string, params: readonly unknown[]) => responses.get(JSON.stringify([method, params]));
assert.equal(get("eth_chainId", []), "0x1237");
const anchor = blockSchema.parse(get("eth_getBlockByNumber", ["0x67e5d17", false]));
assert.equal(BigInt(anchor.number), 108944663n); assert.equal(anchor.hash, sources.evidenceCutoff.hash);
const reconciled = z.array(z.object({ locator: z.string(), tx: z.string(), historicalFields: z.record(z.string()),
  outputs: z.array(z.unknown()), conflicts: z.array(z.string()), priorCompensation: z.null(),
  compensationDeduction: z.null(), currentCustody: z.null(), status: z.literal("reviewed-observations-only") }).passthrough())
  .parse(await json(join(actual, "reconciliation.json")));
const refs = z.object({ refs: z.array(z.object({ row: z.object({ locator: z.string(), fields: z.record(z.string()) }) })) })
  .parse(await json(join(actual, "references.json")));
assert.equal(refs.refs.length, originals.length); assert.equal(reconciled.length, originals.length);
const archive = await json(join(actual, "archive.json"));
for (const schema of [preparationInput, preparedEnvelope, executionManifest]) assert.equal(schema.safeParse(archive).success, false);
const archiveData = z.object({ authenticated: z.literal(true), results: z.array(z.object({ tx: z.string(),
  references: z.array(z.string()), conflicts: z.array(z.string()), requestIds: z.array(z.number()),
  observed: z.object({ transaction: txSchema, receipt: receiptSchema, byHash: blockSchema, byNumber: blockSchema }),
  transactionObservation: txSchema, receiptObservation: receiptSchema }).passthrough()) }).parse(archive);
assert.equal(archiveData.results.length, new Set(originals.map((v) => v.fields["tx"])).size);
const capturedInputs = z.object({ identities: z.array(binding.extend({ path: z.string() })) })
  .parse(await json(join(actual, "inputs.json")));
assert.deepEqual(new Set(capturedInputs.identities.map((v) => v.path)), new Set(["manifest.json", ...declarations.map((d) => d.path)]));
for (const b of capturedInputs.identities) await authenticate(b.path, b);
const review = []; let logs = 0;
for (const row of originals) {
  const f = row.fields, txHash = f["tx"]; assert.ok(txHash);
  const t = txSchema.parse(get("eth_getTransactionByHash", [txHash]));
  const r = receiptSchema.parse(get("eth_getTransactionReceipt", [txHash]));
  const b = blockSchema.parse(get("eth_getBlockByHash", [t.blockHash, false]));
  const n = blockSchema.parse(get("eth_getBlockByNumber", [t.blockNumber, false]));
  const result = archiveData.results.find((v) => v.tx === txHash); assert.ok(result);
  assert.deepEqual(result.conflicts, []);
  assert.deepEqual(result.observed, { transaction: t, receipt: r, byHash: b, byNumber: n });
  assert.deepEqual(result.transactionObservation, t); assert.deepEqual(result.receiptObservation, r);
  assert.deepEqual(await json(join(actual, `${txHash}.json`)), result);
  assert.deepEqual(result.references, originals.filter((v) => v.fields["tx"] === txHash).map((v) => v.locator).sort());
  const linked = captures.filter((c) => c.params[0] === txHash
    || c.method === "eth_getBlockByHash" && c.params[0] === t.blockHash
    || c.method === "eth_getBlockByNumber" && c.params[0] === t.blockNumber);
  assert.deepEqual([...result.requestIds].sort((a, b) => a - b), linked.map((c) => c.id).sort((a, b) => a - b));
  assert.deepEqual(b, n); assert.equal(t.hash, txHash); assert.equal(r.transactionHash, txHash);
  assert.equal(t.blockHash, r.blockHash); assert.equal(t.blockHash, b.hash);
  assert.equal(t.blockNumber, r.blockNumber); assert.equal(t.blockNumber, b.number);
  assert.equal(t.transactionIndex, r.transactionIndex); assert.equal(t.from, r.from); assert.equal(t.to, r.to);
  assert.ok(BigInt(t.blockNumber) <= 108944663n);
  assert.equal(new Set(b.transactions).size, b.transactions.length);
  assert.equal(b.transactions.filter((v) => v === txHash).length, 1);
  assert.equal(b.transactions[Number(BigInt(t.transactionIndex))], txHash);
  let previous = -1n;
  for (const l of r.logs) {
    assert.equal(l.transactionHash, txHash); assert.equal(l.blockHash, t.blockHash);
    assert.equal(l.blockNumber, t.blockNumber); assert.equal(l.transactionIndex, t.transactionIndex);
    assert.ok(BigInt(l.logIndex) > previous); previous = BigInt(l.logIndex); logs++;
  }
  const recovery = row.path === "observed-recoveries.csv";
  const amount = f[recovery ? "observed_amount_raw" : "output_raw"];
  assert.ok(amount && /^(0|[1-9][0-9]*)$/.test(amount));
  const asset = f[recovery ? "asset" : "output_asset"]?.toLowerCase(), recipient = f["recipient"]?.toLowerCase();
  const outputs = r.logs.filter((l) => l.address === asset && l.topics.length === 3
    && l.topics[0] === id("Transfer(address,address,uint256)")
    && /^0x0{24}[0-9a-f]{40}$/.test(l.topics[1] ?? "") && /^0x0{24}[0-9a-f]{40}$/.test(l.topics[2] ?? "")
    && `0x${l.topics[2]?.slice(-40)}` === recipient && /^0x[0-9a-f]{64}$/.test(l.data)
    && BigInt(l.data).toString() === amount && (!recovery || BigInt(l.logIndex).toString() === f["log_index"]))
    .map((l) => ({ address: l.address, from: `0x${l.topics[1]?.slice(-40)}`, to: recipient,
      logIndex: BigInt(l.logIndex).toString(), amount: BigInt(l.data).toString(), tokenId: null }));
  const flags = [];
  if (outputs.length === 0) flags.push("missing-exact-output");
  if (outputs.length > 1) flags.push("ambiguous-exact-output");
  if (BigInt(t.blockNumber).toString() !== f["block"]) flags.push("declared-output-block");
  if (originals.filter((v) => v.fields["tx"] === txHash).length > 1) flags.push("shared-transaction-output-attribution-unresolved");
  const produced = reconciled.find((v) => v.locator === row.locator); assert.ok(produced);
  assert.equal(produced.tx, txHash); assert.deepEqual(produced.historicalFields, f);
  assert.deepEqual(produced.outputs, outputs); assert.deepEqual(produced.conflicts, flags);
  assert.deepEqual(refs.refs.find((v) => v.row.locator === row.locator)?.row.fields, f);
  review.push({ ...row, outputs, conflicts: flags, transactionContext: t,
    unit: { asset, decimals: f[recovery ? "decimals" : "output_decimals"] },
    compensationDeduction: null, currentCustody: null, priorCompensation: null, status: "reviewed-observations-only" });
}
const prior = z.object({ results: z.array(z.object({ tx: z.string() })) }).parse(await json(
  "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/docs/incidents/2026-09-16-dtf-recovery/migration/receipt-evidence/implementation/actual/archive.json"));
const overlap = originals.filter((v) => prior.results.some((p) => p.tx === v.fields["tx"])).map((v) => v.locator);
const proof = { declarations, records: originals.length, distinctTransactions: new Set(originals.map((v) => v.fields["tx"])).size,
  captures: captures.length, logs, overlap, missingPrior: originals.length - overlap.length,
  methods: Object.fromEntries([...new Set(captures.map((c) => c.method))].map((m) => [m, captures.filter((c) => c.method === m).length])),
  rawIdentities, review, qualifications: ["producer-side independent algorithm, not a separate verifier",
    "recovered-authenticated-bodies-not-original-captures", "no-economic-or-source-approval"] };
await writeFile(join(base, "independent-proof.json"), JSON.stringify(proof, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ records: proof.records, transactions: proof.distinctTransactions, captures: proof.captures,
  logs, overlap: overlap.length, unresolved: review.filter((r) => r.conflicts.length).length }));
