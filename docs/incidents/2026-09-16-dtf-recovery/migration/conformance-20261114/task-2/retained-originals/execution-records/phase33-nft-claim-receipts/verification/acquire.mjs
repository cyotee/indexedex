import { request } from "node:https";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { OUT, WT, ANCHOR, intake, save, sha, equal, requireEvidence, canonical } from "./evidence.mjs";

const startedAt = new Date().toISOString();
const s = await intake();
await save("inputs.json", { declarations: s.declarations, frozen: s.inputs, sources: s.bindings, producer: s.producerBindings, originals: s.rows, refs: s.refs });
const toml = await readFile(`${WT}/foundry.toml`, "utf8");
const templates = [...toml.matchAll(/^robinhood_mainnet_alchemy\s*=\s*"([^"]+)"\s*$/gm)];
requireEvidence(templates.length === 1 && templates[0][1] === "https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}", "exact existing alias");
const key = process.env.ALCHEMY_KEY;
requireEvidence(typeof key === "string" && key.length > 0, "selected provider credential unavailable");
const url = new URL(templates[0][1].replace("${ALCHEMY_KEY}", encodeURIComponent(key)));
const safe = text => {
  let body = text;
  for (const secret of [key, encodeURIComponent(key), url.href]) body = body.replaceAll(secret, "<redacted>");
  return body.replace(/https?:\/\/[^\s"'<>\\]+/gi, "<redacted-url>");
};
await mkdir(join(OUT, "http"));
const captures = [], entries = [];
let blocker = null, anchor = null, endAnchor = null;
async function rpc(method, params) {
  requireEvidence(["eth_chainId", "eth_getTransactionByHash", "eth_getTransactionReceipt", "eth_getBlockByHash", "eth_getBlockByNumber"].includes(method), "allowed RPC");
  const id = captures.length + 1;
  requireEvidence(id <= 67, "finite acquisition cap");
  const prefix = `http/${String(id).padStart(4, "0")}`;
  const body = Buffer.from(JSON.stringify({ jsonrpc: "2.0", id, method, params }));
  const c = { id, method, params, startedAt: new Date().toISOString(), request: { path: `${prefix}.request.json`, bytes: body.length, sha256: sha(body) }, response: null, http: null, failure: null };
  await writeFile(join(OUT, c.request.path), body, { flag: "wx" });
  try {
    const observed = await new Promise((resolve, reject) => {
      const req = request(url, { method: "POST", agent: false, signal: AbortSignal.timeout(20000),
        headers: { "content-type": "application/json", "accept-encoding": "identity", "content-length": body.length } }, res => {
        const chunks = [];
        res.on("data", b => chunks.push(b)); res.once("error", reject);
        res.once("end", () => resolve({ bytes: Buffer.concat(chunks), status: res.statusCode, type: res.headers["content-type"] ?? null, encoding: res.headers["content-encoding"] ?? null }));
      });
      req.once("error", reject); req.end(body);
    });
    const text = new TextDecoder("utf-8", { fatal: true }).decode(observed.bytes);
    const redacted = safe(text), raw = redacted === text;
    const bytes = raw ? observed.bytes : Buffer.from(redacted);
    c.response = { path: `${prefix}.response.${raw ? "raw" : "redacted"}`, bytes: bytes.length, sha256: sha(bytes), raw, receivedBytes: observed.bytes.length };
    c.http = { status: observed.status, contentType: safe(String(observed.type)), contentEncoding: safe(String(observed.encoding)) };
    await writeFile(join(OUT, c.response.path), bytes, { flag: "wx" });
    const envelope = JSON.parse(redacted);
    if (observed.status !== 200 || !raw || envelope.jsonrpc !== "2.0" || envelope.id !== id || envelope.error || envelope.result == null) {
      c.failure = { kind: "http-or-envelope-or-rpc", envelope };
    } else c.result = envelope.result;
  } catch (error) {
    if (!(error instanceof Error)) throw error;
    c.failure = { kind: "transport-or-parse", name: safe(error.name), message: safe(error.message) };
  }
  c.finishedAt = new Date().toISOString(); captures.push(c);
  // Refusal is terminal; no alternative provider, method or retry.
  requireEvidence(c.failure === null, `stopped RPC failure ${id}`);
  return c;
}
try {
  const chain = await rpc("eth_chainId", []);
  requireEvidence(BigInt(chain.result) === 4663n, "chain authentication");
  anchor = await rpc("eth_getBlockByNumber", ["0x67e5d17", false]);
  equal([anchor.result.number, anchor.result.hash], ["0x67e5d17", ANCHOR.hash], "historical anchor");
  for (const ref of s.refs.filter(r => r.priorIndex < 0)) {
    const tx = await rpc("eth_getTransactionByHash", [ref.tx]);
    const receipt = await rpc("eth_getTransactionReceipt", [ref.tx]);
    const byHash = await rpc("eth_getBlockByHash", [tx.result.blockHash, false]);
    const byNumber = await rpc("eth_getBlockByNumber", [tx.result.blockNumber, false]);
    const observed = { transaction: tx.result, receipt: receipt.result, byHash: byHash.result, byNumber: byNumber.result };
    canonical(ref.tx, observed);
    const entry = { ...ref, observed, requestIds: [tx.id, receipt.id, byHash.id, byNumber.id], capture: "independent-new-phase33" };
    entries.push(entry); await save(`${ref.tx}.json`, entry);
  }
  endAnchor = await rpc("eth_getBlockByNumber", ["0x67e5d17", false]);
  equal(endAnchor.result, anchor.result, "ending full anchor");
} catch (error) {
  if (!(error instanceof Error)) throw error;
  blocker = { name: safe(error.name), message: safe(error.message) };
} finally {
  await save("http-manifest.json", captures);
  await save("archive.json", { provider: "robinhood_mainnet_alchemy", chainId: "4663", historicalAnchor: ANCHOR,
    startedAt, stoppedAt: new Date().toISOString(), anchor, endAnchor, entries, failures: captures.filter(c => c.failure), blocker, pendingRequests: 0 });
}
console.log(JSON.stringify({ collected: entries.length, requests: captures.length, blocker, pendingRequests: 0 }));
if (blocker) process.exitCode = 1;
