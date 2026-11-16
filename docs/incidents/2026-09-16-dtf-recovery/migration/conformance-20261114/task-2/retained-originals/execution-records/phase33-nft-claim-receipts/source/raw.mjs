import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { check, sha, json } from "./inputs.mjs";

export const equal = (a, b, label) => check(isDeepStrictEqual(a, b), label);
export const q = v => typeof v === "string" && /^0x(?:0|[1-9a-f][0-9a-f]*)$/.test(v) && BigInt(v) < 2n ** 256n;
const hash = v => typeof v === "string" && /^0x[0-9a-f]{64}$/.test(v);
const address = v => typeof v === "string" && /^0x[0-9a-f]{40}$/.test(v);
const hex = v => typeof v === "string" && /^0x(?:[0-9a-f]{2})*$/.test(v);
export async function rawHttp(root, captures) {
  const result = new Map(), paths = [];
  for (const c of captures) {
    check(Number.isSafeInteger(c.id) && c.id > 0 && !result.has(c.id), "unique integer RPC id");
    const bodies = {};
    for (const kind of ["request", "response"]) {
      const b = c[kind];
      if (!b) { bodies[kind] = null; continue; }
      const path = join(root, b.path), bytes = await readFile(path);
      check(bytes.length === b.bytes && sha(bytes) === b.sha256, `raw entity binding: ${path}`);
      paths.push(path);
      bodies[kind] = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    }
    equal(bodies.request, { id: c.id, jsonrpc: "2.0", method: c.method, params: c.params }, "exact request");
    const response = bodies.response;
    if (c.failure || c.outcome && c.outcome !== "success") {
      result.set(c.id, { capture: c, request: bodies.request, response, value: null, failure: true });
      continue;
    }
    check(c.http.status === 200 && c.response.raw && c.response.bytes === c.response.receivedBytes, "raw HTTP success");
    check(response.jsonrpc === "2.0" && response.id === c.id && !("error" in response)
      && "result" in response && response.result !== null, "response envelope");
    if ("result" in c) equal(response.result, c.result, "manifest normalized result");
    result.set(c.id, { capture: c, request: bodies.request, response, value: response.result, failure: false });
  }
  check(new Set(paths).size === paths.length, "unique raw files");
  return result;
}
export function canonical(txHash, o) {
  const { transaction: t, receipt: r, byHash: b, byNumber: n } = o;
  check(hash(txHash) && t.hash === txHash && r.transactionHash === txHash, "transaction identity");
  check(hash(t.blockHash) && q(t.blockNumber) && q(t.transactionIndex) && q(t.value) && q(t.nonce) && hex(t.input), "transaction schema");
  check(address(t.from) && (t.to === null || address(t.to)) && t.from === r.from && t.to === r.to, "transaction endpoints");
  if ("chainId" in t) check(q(t.chainId) && BigInt(t.chainId) === 4663n, "transaction chain");
  check(t.blockNumber === r.blockNumber && t.blockNumber === b.number && t.blockHash === r.blockHash
    && t.blockHash === b.hash && t.transactionIndex === r.transactionIndex, "canonical associations");
  check(BigInt(t.blockNumber) <= 108944663n && r.status === "0x1", "anchor cutoff and success");
  check(hash(b.hash) && hash(b.parentHash) && q(b.timestamp) && q(b.number) && b.transactions.every(hash), "block schema");
  equal(b, n, "entire block canonical equality");
  check(new Set(b.transactions).size === b.transactions.length && b.transactions.filter(x => x === txHash).length === 1
    && b.transactions[Number(BigInt(t.transactionIndex))] === txHash, "exact unique block membership");
  let previous = -1n;
  for (const l of r.logs) {
    check(l.transactionHash === txHash && l.blockHash === t.blockHash && l.blockNumber === t.blockNumber
      && l.transactionIndex === t.transactionIndex && l.removed === false, "log association");
    check(q(l.logIndex) && BigInt(l.logIndex) > previous && address(l.address)
      && l.topics.every(hash) && hex(l.data), "log schema and strict order");
    previous = BigInt(l.logIndex);
  }
  return r.logs.length;
}
// Separate CSV state machine: no producer table/row list is an oracle.
export function csv(text) {
  const records = [], row = [];
  let value = "", quote = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quote && text[i + 1] === '"') { value += '"'; i++; } else quote = !quote;
    } else if (!quote && (c === "," || c === "\n" || c === "\r")) {
      row.push(value); value = "";
      if (c !== ",") {
        if (c === "\r" && text[i + 1] === "\n") i++;
        records.push([...row]); row.length = 0;
      }
    } else value += c;
  }
  check(!quote, "closed CSV");
  if (value || row.length) { row.push(value); records.push([...row]); }
  const header = records.shift();
  check(header && new Set(header).size === header.length, "CSV headers");
  return records.map((r, i) => {
    check(r.length === header.length, "CSV rectangularity");
    return { locator: `evidence/weighted-bonds.csv#row=${i + 2}`, fields: Object.fromEntries(header.map((h, j) => [h, r[j]])) };
  });
}
export async function checkHttpFiles(out, captures) {
  const actual = (await readdir(join(out, "http"))).sort();
  const expected = captures.flatMap(c => [c.request.path, c.response?.path].filter(Boolean))
    .map(p => p.replace(/^http\//, "")).sort();
  equal(actual, expected, "no orphan HTTP entities");
}
