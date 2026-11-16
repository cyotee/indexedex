import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import { resolve, join } from "node:path";
import { z } from "zod";

export const inputRoot = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery";
export const cutoff = 108944663n;
export const anchorHash = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
export const identity = z.object({ path: z.string(), bytes: z.number().int(), sha256: z.string() });
export async function body(path: string) { return readFile(path); }
export function digest(bytes: Uint8Array) {
  return { bytes: bytes.byteLength, sha256: createHash("sha256").update(bytes).digest("hex") };
}
export async function json(path: string): Promise<unknown> { return JSON.parse((await body(path)).toString("utf8")); }
export async function bound(directory: string, value: z.infer<typeof identity>) {
  assert.deepEqual(digest(await body(resolve(directory, value.path))), { bytes: value.bytes, sha256: value.sha256 }, value.path);
  return value;
}
export function csv(bytes: Uint8Array, path: string) {
  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  const token = /("(?:[^"]|"")*"|[^",\r\n]*)(,|\r\n|\n|$)/gy;
  const records: string[][] = [];
  let record: string[] = [], cursor = 0;
  while (cursor < text.length) {
    token.lastIndex = cursor;
    const match = token.exec(text);
    assert.ok(match && match.index === cursor && token.lastIndex > cursor, `CSV token ${path}:${cursor}`);
    const value = match[1]; assert.ok(value !== undefined);
    record.push(value.startsWith('"') ? value.slice(1, -1).replaceAll('""', '"') : value);
    cursor = token.lastIndex;
    if (match[2] !== ",") { records.push(record); record = []; }
  }
  assert.equal(record.length, 0);
  const header = records.shift(); assert.ok(header && new Set(header).size === header.length);
  return records.map((values, index) => {
    assert.equal(values.length, header.length, `${path} width`);
    return { locator: `${path}#row=${index + 2}`, row: index + 2, path,
      fields: Object.fromEntries(header.map((key, i) => [key, values[i] ?? ""])) };
  });
}
export function field(row: ReturnType<typeof csv>[number], name: string) {
  const value = row.fields[name]; assert.ok(value !== undefined, name); return value;
}
export async function authenticate() {
  const manifest = z.object({ files: z.record(identity.omit({ path: true })) }).parse(await json(join(inputRoot, "manifest.json")));
  const sourceBinding = manifest.files["sources.json"]; assert.ok(sourceBinding);
  await bound(inputRoot, { path: "sources.json", ...sourceBinding });
  const source = z.object({ sources: z.array(identity.extend({ id: z.string() })), chainId: z.literal(4663),
    evidenceCutoff: z.object({ block: z.literal(108944663), hash: z.literal(anchorHash) }) }).passthrough()
    .parse(await json(join(inputRoot, "sources.json")));
  const declarations = [...source.sources.map((s) => ({ ...s, declaration: s.id })),
    ...Object.entries(manifest.files).map(([path, value]) => ({ path, ...value, declaration: "manifest" }))];
  for (const d of declarations) await bound(inputRoot, d);
  return { declarations, source, paths: [...new Set(["manifest.json", ...declarations.map((d) => d.path)])] };
}
const hash = z.string().regex(/^0x[0-9a-f]{64}$/);
const address = z.string().regex(/^0x[0-9a-fA-F]{40}$/);
const quantity = z.string().regex(/^0x(?:0|[1-9a-f][0-9a-f]*)$/).refine((n) => BigInt(n) < 2n ** 256n);
const data = z.string().regex(/^0x(?:[0-9a-f]{2})*$/);
const associated = { blockHash: hash, blockNumber: quantity, transactionIndex: quantity };
const txSchema = z.object({ ...associated, hash, from: address, to: address.nullable(),
  input: data, value: quantity, nonce: quantity }).passthrough();
const logSchema = z.object({ ...associated, transactionHash: hash, logIndex: quantity,
  address, topics: z.array(hash), data, removed: z.literal(false) }).passthrough();
const receiptSchema = z.object({ ...associated, transactionHash: hash, from: address, to: address.nullable(),
  status: z.literal("0x1"), logs: z.array(logSchema) }).passthrough();
const blockSchema = z.object({ hash, number: quantity, parentHash: hash, timestamp: quantity,
  transactions: z.array(hash) }).passthrough();
const captureSchema = z.object({ id: z.number().int(), method: z.enum(["eth_chainId", "eth_getTransactionByHash",
  "eth_getTransactionReceipt", "eth_getBlockByHash", "eth_getBlockByNumber"]), params: z.array(z.unknown()),
  request: identity, response: identity.extend({ raw: z.literal(true), receivedBytes: z.number().int() }),
  http: z.object({ status: z.literal(200) }).passthrough(), outcome: z.literal("success") });
export async function rawArchive(directory: string, hashes: readonly string[]) {
  const captures = z.array(captureSchema).parse(await json(join(directory, "http-manifest.json")));
  const wire = new Map<string, { readonly id: number; readonly result: unknown }>();
  const fileNames: string[] = [];
  for (const [index, c] of captures.entries()) {
    assert.equal(c.id, index + 1);
    for (const item of [c.request, c.response]) { await bound(join(directory, "http"), item); fileNames.push(item.path); }
    assert.equal(c.response.receivedBytes, c.response.bytes);
    assert.deepEqual(await json(join(directory, "http", c.request.path)), {
      jsonrpc: "2.0", id: c.id, method: c.method, params: c.params,
    });
    const response = z.object({ jsonrpc: z.literal("2.0"), id: z.literal(c.id), result: z.unknown() }).strict()
      .parse(await json(join(directory, "http", c.response.path)));
    assert.ok(response.result !== null && response.result !== undefined);
    const key = JSON.stringify([c.method, c.params]); assert.ok(!wire.has(key), key);
    wire.set(key, { id: c.id, result: response.result });
  }
  assert.deepEqual((await readdir(join(directory, "http"))).sort(), fileNames.sort());
  const get = (method: string, params: readonly unknown[]) => {
    const item = wire.get(JSON.stringify([method, params])); assert.ok(item); return item;
  };
  assert.equal(BigInt(quantity.parse(get("eth_chainId", []).result)), 4663n);
  const anchor = blockSchema.parse(get("eth_getBlockByNumber", [`0x${cutoff.toString(16)}`, false]).result);
  assert.equal(anchor.hash, anchorHash); assert.equal(BigInt(anchor.number), cutoff);
  const usedIds = new Set([1, 2]);
  const observations = new Map<string, {
    readonly transaction: z.infer<typeof txSchema>; readonly receipt: z.infer<typeof receiptSchema>;
    readonly byHash: z.infer<typeof blockSchema>; readonly byNumber: z.infer<typeof blockSchema>;
    readonly requestIds: readonly number[];
  }>();
  let logs = 0;
  for (const h of hashes) {
    const tq = get("eth_getTransactionByHash", [h]), rq = get("eth_getTransactionReceipt", [h]);
    const tx = txSchema.parse(tq.result), receipt = receiptSchema.parse(rq.result);
    const bq = get("eth_getBlockByHash", [tx.blockHash, false]);
    const nq = get("eth_getBlockByNumber", [tx.blockNumber, false]);
    const b = blockSchema.parse(bq.result), n = blockSchema.parse(nq.result);
    assert.deepEqual(b, n); assert.equal(tx.hash, h); assert.equal(receipt.transactionHash, h);
    assert.equal(tx.blockHash, b.hash); assert.equal(tx.blockNumber, b.number);
    for (const key of ["blockHash", "blockNumber", "transactionIndex", "from", "to"] as const) {
      assert.equal(tx[key]?.toLowerCase(), receipt[key]?.toLowerCase(), `${h}:${key}`);
    }
    assert.ok(BigInt(tx.blockNumber) <= cutoff);
    assert.equal(new Set(b.transactions).size, b.transactions.length);
    assert.equal(b.transactions.filter((entry) => entry === h).length, 1);
    assert.equal(b.transactions[Number(BigInt(tx.transactionIndex))], h);
    let previous = -1n;
    for (const l of receipt.logs) {
      for (const key of ["blockHash", "blockNumber", "transactionIndex"] as const) assert.equal(l[key], tx[key]);
      assert.equal(l.transactionHash, h); assert.ok(BigInt(l.logIndex) > previous);
      previous = BigInt(l.logIndex); logs++;
    }
    const requestIds = [tq.id, rq.id, bq.id, nq.id]; requestIds.forEach((id) => usedIds.add(id));
    assert.ok(Math.min(...requestIds) > 2);
    observations.set(h, { transaction: { ...tx, from: tx.from.toLowerCase(), to: tx.to?.toLowerCase() ?? null },
      receipt: { ...receipt, from: receipt.from.toLowerCase(), to: receipt.to?.toLowerCase() ?? null,
        logs: receipt.logs.map((l) => ({ ...l, address: l.address.toLowerCase() })) },
      byHash: b, byNumber: n, requestIds });
  }
  assert.equal(usedIds.size, captures.length, "no unrequested method/params");
  return { captures, observations, logs, anchor };
}
