import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";
import { id } from "ethers";
import { z } from "zod";

// Independent raw-row/RPC oracle: no collector, CSV, association or reconciliation imports.
const base = dirname(fileURLToPath(import.meta.url)), actual = join(base, "actual");
const input = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery";
const digest = (b: Uint8Array) => createHash("sha256").update(b).digest("hex");
async function json(path: string): Promise<unknown> { return JSON.parse(await readFile(path, "utf8")); }
const binding = z.object({ bytes: z.number(), sha256: z.string() });
const manifest = z.object({ files: z.record(binding) }).parse(await json(join(input, "manifest.json")));
const sources = z.object({ sources: z.array(binding.extend({ id: z.string(), path: z.string() })) })
  .parse(await json(join(input, "sources.json")));
const bindings = [...Object.entries(manifest.files).map(([path, b]) => ({ path, ...b })), ...sources.sources];
for (const b of bindings) {
  const bytes = await readFile(join(input, b.path));
  assert.equal(bytes.length, b.bytes, b.path); assert.equal(digest(bytes), b.sha256, b.path);
}
async function csv(path: string): Promise<readonly Readonly<Record<string, string>>[]> {
  // These frozen CSVs quote every field and have no embedded newlines. Require
  // complete token consumption; this decoder is independent of the operator's.
  const text = await readFile(join(input, path), "utf8");
  const lines = text.trimEnd().split(/\r?\n/);
  const records = lines.map((line) => {
    const matches = [...line.matchAll(/"((?:[^"]|"")*)"(,|$)/g)];
    assert.equal(matches.map((m) => m[0]).join(""), line);
    return matches.map((m) => (m[1] ?? "").replaceAll('""', '"'));
  });
  const header = records.shift(); assert.ok(header);
  return records.map((r, i) => {
    assert.equal(r.length, header.length);
    return { ...Object.fromEntries(header.map((h, n) => [h, r[n] ?? ""])), locator: `${path}#row=${i + 2}` };
  });
}
const weighted = await csv("evidence/weighted-bonds.csv"), earlier = await csv("evidence/earlier-cp-bonds.csv");
const claims = (await csv("conversions.csv")).filter((r) => r["kind"] === "legacy_weight_to_sy");
const transfers = await csv("evidence/transfers.csv");
const refs = [...weighted.map((row) => ({ kind: "weighted", row, tx: row["purchase_tx"] })),
  ...earlier.map((row) => ({ kind: "earlier", row, tx: row["purchase_tx"] })),
  ...claims.map((row) => ({ kind: "claim", row, tx: row["tx"] }))];
assert.deepEqual([weighted.length, earlier.length, claims.length, new Set(refs.map((r) => r.tx)).size], [43, 16, 18, 77]);
const captureSchema = z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()),
  request: binding.extend({ path: z.string() }), response: binding.extend({ path: z.string(), raw: z.boolean() }).nullable(),
  outcome: z.string() }).passthrough();
const captures = z.array(captureSchema).parse(await json(join(actual, "http-manifest.json")));
const allowed = new Set(["eth_chainId", "eth_getTransactionByHash", "eth_getTransactionReceipt", "eth_getBlockByHash", "eth_getBlockByNumber"]);
const raw = new Map<number, unknown>();
for (const c of captures) {
  assert.ok(allowed.has(c.method));
  const request = await readFile(join(actual, "http", c.request.path));
  assert.equal(request.length, c.request.bytes); assert.equal(digest(request), c.request.sha256);
  const q = z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()) }).parse(JSON.parse(request.toString()));
  assert.equal(q.id, c.id); assert.equal(q.method, c.method); assert.deepEqual(q.params, c.params);
  if (c.response) {
    const bytes = await readFile(join(actual, "http", c.response.path));
    assert.equal(bytes.length, c.response.bytes); assert.equal(digest(bytes), c.response.sha256);
    if (c.response.raw && c.outcome === "success") {
      const response = z.object({ jsonrpc: z.literal("2.0"), id: z.number(), result: z.unknown() }).parse(JSON.parse(bytes.toString()));
      assert.equal(response.id, c.id); raw.set(c.id, response.result);
    }
  }
}
const archive = z.object({ authenticated: z.boolean(), references: z.number(), distinctTransactions: z.number(),
  results: z.array(z.object({ tx: z.string(), references: z.array(z.string()), conflicts: z.array(z.string()),
    requestIds: z.array(z.number()), observed: z.unknown() })) }).parse(await json(join(actual, "archive.json")));
const reconciled = z.array(z.object({ locator: z.string(), tx: z.string(), historicalFields: z.record(z.string()),
  conflicts: z.array(z.string()) }).passthrough()).parse(await json(join(actual, "reconciliation.json")));
assert.equal(archive.results.length, 77); assert.equal(archive.references, 77); assert.equal(archive.distinctTransactions, 77);
assert.equal(reconciled.length, 77);
const qSchema = z.string().regex(/^0x(?:0|[1-9a-f][0-9a-f]*)$/);
const logSchema = z.object({ address: z.string(), topics: z.array(z.string()), data: z.string(), logIndex: qSchema,
  transactionHash: z.string(), transactionIndex: qSchema, blockHash: z.string(), blockNumber: qSchema, removed: z.literal(false) });
const txSchema = z.object({ hash: z.string(), from: z.string(), to: z.string().nullable(), input: z.string(), value: qSchema,
  blockHash: z.string(), blockNumber: qSchema, transactionIndex: qSchema }).passthrough();
const receiptSchema = z.object({ transactionHash: z.string(), from: z.string(), to: z.string().nullable(),
  blockHash: z.string(), blockNumber: qSchema, transactionIndex: qSchema, status: z.string(), logs: z.array(logSchema) }).passthrough();
const blockSchema = z.object({ hash: z.string(), number: qSchema, parentHash: z.string(), timestamp: qSchema, transactions: z.array(z.string()) }).passthrough();
const transferTopic = id("Transfer(address,address,uint256)");
const lower = (v: string | undefined) => (v ?? "").toLowerCase();
const resultFor = (method: string, param: string) => {
  const matching = captures.filter((c) => c.method === method && c.params[0] === param);
  assert.equal(matching.length, 1, `${method}:${param}`);
  const c = matching[0]; assert.ok(c);
  return raw.get(c.id);
};
const rows: unknown[] = [];
for (const ref of refs) {
  assert.ok(ref.tx); const txHash = ref.tx.toLowerCase();
  const indexed = archive.results.find((r) => r.tx === txHash); assert.ok(indexed);
  assert.deepEqual(indexed.references, [ref.row["locator"]]);
  const row = reconciled.find((r) => r.locator === ref.row["locator"]); assert.ok(row);
  const { locator, ...fields } = ref.row; assert.deepEqual(row.historicalFields, fields);
  if (!archive.authenticated) {
    assert.ok(row.conflicts.includes("chain-or-anchor-authentication-failed"));
    rows.push({ locator, tx: txHash, unavailable: true, conflicts: row.conflicts }); continue;
  }
  const txRaw = resultFor("eth_getTransactionByHash", txHash), receiptRaw = resultFor("eth_getTransactionReceipt", txHash);
  if (txRaw === undefined || receiptRaw === undefined) {
    assert.ok(indexed.conflicts.length); assert.ok(row.conflicts.length);
    rows.push({ locator, tx: txHash, unavailable: true, conflicts: row.conflicts }); continue;
  }
  const tx = txSchema.parse(txRaw), receipt = receiptSchema.parse(receiptRaw);
  const hashRaw = resultFor("eth_getBlockByHash", tx.blockHash), numberRaw = resultFor("eth_getBlockByNumber", tx.blockNumber);
  if (hashRaw === undefined || numberRaw === undefined) {
    assert.ok(indexed.conflicts.length); assert.ok(row.conflicts.length);
    rows.push({ locator, tx: txHash, unavailable: true, conflicts: row.conflicts }); continue;
  }
  const b = blockSchema.parse(hashRaw), n = blockSchema.parse(numberRaw);
  const associationMismatches = [
    ["tx-hash", tx.hash === txHash && receipt.transactionHash === txHash],
    ["block-hash", receipt.blockHash === tx.blockHash && b.hash === tx.blockHash && n.hash === b.hash],
    ["block-number", receipt.blockNumber === tx.blockNumber && b.number === tx.blockNumber && n.number === b.number],
    ["tx-index", receipt.transactionIndex === tx.transactionIndex],
    ["endpoints", receipt.from === tx.from && receipt.to === tx.to],
    ["header", b.parentHash === n.parentHash && b.timestamp === n.timestamp],
    ["membership", JSON.stringify(b.transactions) === JSON.stringify(n.transactions)
      && b.transactions[Number(BigInt(tx.transactionIndex))] === txHash
      && b.transactions.filter((h) => h === txHash).length === 1
      && new Set(b.transactions).size === b.transactions.length],
    ["anchor", BigInt(tx.blockNumber) <= 108944663n], ["receipt-status", receipt.status === "0x1"],
  ].filter(([, matches]) => !matches).map(([name]) => name);
  let previous = -1n;
  for (const l of receipt.logs) {
    if (l.transactionHash !== txHash || l.transactionIndex !== tx.transactionIndex || l.blockHash !== tx.blockHash
      || l.blockNumber !== tx.blockNumber || BigInt(l.logIndex) <= previous) associationMismatches.push(`log:${l.logIndex}`);
    previous = BigInt(l.logIndex);
  }
  if (associationMismatches.length) {
    assert.ok(row.conflicts.length);
    rows.push({ locator, tx: txHash, associationMismatches, conflicts: row.conflicts }); continue;
  }
  const decoded = receipt.logs.filter((l) => l.topics[0] === transferTopic).map((l) => ({
    logIndex: BigInt(l.logIndex).toString(), asset: lower(l.address),
    from: `0x${l.topics[1]?.slice(-40)}`, to: `0x${l.topics[2]?.slice(-40)}`,
    tokenId: l.topics.length === 4 ? BigInt(l.topics[3] ?? "0").toString() : null,
    amount: l.topics.length === 3 ? BigInt(l.data).toString() : null,
  }));
  const saved = transfers.filter((r) => lower(r["tx"]) === txHash && (ref.kind !== "claim"
    || lower(r["asset"]) === lower(ref.row["output_asset"]) && lower(r["to"]) === lower(ref.row["recipient"])));
  const savedMismatches = saved.filter((s) => !decoded.some((d) => d.asset === lower(s["asset"])
    && d.logIndex === s["log_index"] && d.from === lower(s["from"]) && d.to === lower(s["to"])
    && (d.amount ?? "") === s["amount_raw"] && (d.tokenId ?? "") === s["token_id"]));
  const recipient = lower(ref.row[ref.kind === "weighted" ? "purchase_recipient" : ref.kind === "earlier" ? "owner" : "recipient"]);
  const source = ref.kind === "weighted" ? "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e"
    : ref.kind === "earlier" ? "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391" : "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
  const topic = id(ref.kind === "weighted" ? "BondPurchased(uint256,address,uint256,uint256,uint256)"
    : ref.kind === "earlier" ? "NewLock(uint256,address,uint256,uint256,uint256)" : "ClaimWithdrawn(address,uint256,uint256)");
  const events = receipt.logs.filter((l) => lower(l.address) === source && l.topics[0] === topic).map((l) => ({
    logIndex: BigInt(l.logIndex).toString(), topics: l.topics,
    values: (l.data.slice(2).match(/.{64}/g) ?? []).map((w) => BigInt(`0x${w}`).toString()),
  }));
  if (ref.kind === "claim") {
    const claimEvent = events.filter((e) => `0x${e.topics[1]?.slice(-40)}` === recipient
      && e.values[0] === ref.row["principal_raw"] && e.values[1] === ref.row["output_raw"]);
    const output = decoded.filter((d) => d.asset === lower(ref.row["output_asset"]) && d.to === recipient && d.amount === ref.row["output_raw"]);
    const direct = lower(tx.to ?? "") === source && tx.input === `${id("withdrawClaim(uint256)").slice(0, 10)}${BigInt(ref.row["principal_raw"] ?? "").toString(16).padStart(64, "0")}`;
    if (!claimEvent.length || output.length !== 1 || !direct || savedMismatches.length) assert.ok(row.conflicts.length);
    rows.push({ locator, tx: txHash, kind: ref.kind, caller: tx.from, callee: tx.to, value: tx.value, calldata: tx.input,
      events, output, direct, savedMismatches, conflicts: row.conflicts });
  } else {
    const mints = decoded.filter((d) => d.asset === source && d.from === `0x${"0".repeat(40)}`
      && d.tokenId === ref.row["token_id"] && d.to === recipient);
    const target = ref.kind === "weighted" ? "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7" : "0xaf0e1967c8f755c747615c5427108bc549ca1122";
    const assets = ["0xee5576fa1bcaa380e591d01245f406f3f384eb01", "0x0bd7d308f8e1639fab988df18a8011f41eacad73"].map((asset) => {
      const inbound = decoded.filter((d) => d.asset === asset && d.to === target && d.amount !== null);
      return { asset, direct: inbound.filter((d) => d.from === recipient).reduce((s, d) => s + BigInt(d.amount ?? ""), 0n).toString(),
        routed: inbound.filter((d) => d.from !== recipient).reduce((s, d) => s + BigInt(d.amount ?? ""), 0n).toString(), inbound };
    });
    const basis = ref.row[ref.kind === "weighted" ? "original_principal_detf_raw" : "original_lp_shares_raw"];
    const matching = events.filter((e) => BigInt(e.topics[1] ?? "0").toString() === ref.row["token_id"]
      && `0x${e.topics[2]?.slice(-40)}` === recipient && e.values[0] === basis);
    if (mints.length !== 1 || matching.length !== 1 || savedMismatches.length) assert.ok(row.conflicts.length);
    const produced = z.object({ assets: z.array(z.object({ asset: z.string(), observedDirect: z.string(),
      observedRouted: z.string(), attributableDirect: z.string().nullable() })) }).parse(row);
    assert.deepEqual(produced.assets.map((a) => [a.asset, a.observedDirect, a.observedRouted]),
      assets.map((a) => [a.asset, a.direct, a.routed]));
    if (row.conflicts.length) assert.ok(produced.assets.every((a) => a.attributableDirect === null));
    if (ref.kind === "earlier") {
      const directExpected = [ref.row["direct_dtf_paid_raw"], ref.row["direct_weth_paid_raw"]];
      if (assets.some((a, i) => a.direct !== directExpected[i]) || assets[0]?.routed !== ref.row["routed_dtf_received_by_detf_raw"]) {
        assert.ok(row.conflicts.length);
      }
    }
    rows.push({ locator, tx: txHash, kind: ref.kind, recipient, mints, events, assets, basis, savedMismatches, conflicts: row.conflicts });
  }
}
await writeFile(join(base, "independent-proof.json"), JSON.stringify({
  bindingChecks: bindings.length, rawRecords: refs.length, weighted: weighted.length, earlier: earlier.length, claims: claims.length,
  httpCaptures: captures.length, authenticated: archive.authenticated, rows,
  limits: "Known named records only; no eligibility, W0/Q0, prior-credit zero, current control, net contribution or exhaustive history.",
}, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ independentReferences: rows.length, bindings: bindings.length, httpCaptures: captures.length,
  referenceConflicts: reconciled.filter((r) => r.conflicts.length).length }));
