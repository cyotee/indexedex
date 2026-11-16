import { request } from "node:https";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { OUT, WT, sha, check, EvidenceError } from "./inputs.mjs";

export async function endpoint() {
  const toml = await readFile(`${WT}/foundry.toml`, "utf8");
  const aliases = [...toml.matchAll(/^robinhood_mainnet_alchemy\s*=\s*"([^"]+)"\s*$/gm)];
  check(aliases.length === 1 && aliases[0][1] === "https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}", "RPC alias changed");
  check(Boolean(process.env.ALCHEMY_KEY), "selected credential unavailable");
  return new URL(aliases[0][1].replace("${ALCHEMY_KEY}", encodeURIComponent(process.env.ALCHEMY_KEY)));
}
export class ReadRpc {
  sequence = 0;
  captures = [];
  constructor(url) { this.url = url; }
  redact(text) {
    let safe = text;
    for (const secret of [this.url.href, process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")]) {
      if (secret) safe = safe.replaceAll(secret, "<redacted>");
    }
    return safe.replace(/https?:\/\/[^\s"'<>\\]+/gi, "<redacted-url>");
  }
  async start() { await mkdir(join(OUT, "http"), { recursive: false }); }
  async read(method, params) {
    check(["eth_chainId", "eth_getTransactionByHash", "eth_getTransactionReceipt", "eth_getBlockByHash",
      "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(method), "forbidden method");
    const id = ++this.sequence;
    check(id <= 350, "finite request bound exceeded");
    const body = Buffer.from(JSON.stringify({ jsonrpc: "2.0", id, method, params }));
    const prefix = `http/${String(id).padStart(4, "0")}`;
    const reqIdentity = { path: `${prefix}.request.json`, bytes: body.length, sha256: sha(body) };
    await writeFile(join(OUT, reqIdentity.path), body, { flag: "wx" });
    const capture = { id, method, params, startedAt: new Date().toISOString(), request: reqIdentity,
      response: null, http: null, failure: null, result: null };
    try {
      const observed = await new Promise((resolve, reject) => {
        const req = request(this.url, { method: "POST", agent: false, signal: AbortSignal.timeout(20000),
          headers: { "content-type": "application/json", "accept-encoding": "identity", "content-length": body.length } }, res => {
          const chunks = [];
          res.on("data", b => chunks.push(b));
          res.once("error", reject);
          res.once("end", () => resolve({ bytes: Buffer.concat(chunks), status: res.statusCode,
            contentType: res.headers["content-type"] ?? null, contentEncoding: res.headers["content-encoding"] ?? null }));
        });
        req.once("error", reject); req.end(body);
      });
      const decoded = new TextDecoder("utf-8", { fatal: true }).decode(observed.bytes);
      const safe = this.redact(decoded), raw = safe === decoded;
      const bytes = raw ? observed.bytes : Buffer.from(safe);
      capture.response = { path: `${prefix}.response.${raw ? "raw" : "redacted"}`, bytes: bytes.length,
        sha256: sha(bytes), raw, receivedBytes: observed.bytes.length };
      await writeFile(join(OUT, capture.response.path), bytes, { flag: "wx" });
      capture.http = { status: observed.status, contentType: this.redact(String(observed.contentType)),
        contentEncoding: this.redact(String(observed.contentEncoding)) };
      if (observed.status !== 200) capture.failure = { kind: "http", status: observed.status };
      else if (!raw) capture.failure = { kind: "redacted-nonraw" };
      else {
        const parsed = JSON.parse(decoded);
        if (parsed.jsonrpc !== "2.0" || parsed.id !== id) capture.failure = { kind: "envelope-or-id", envelope: parsed };
        else if ("error" in parsed) capture.failure = { kind: "rpc", error: parsed.error };
        else if (!("result" in parsed) || parsed.result === null) capture.failure = { kind: "missing-or-null-result" };
        else capture.result = parsed.result;
      }
    } catch (error) {
      if (!(error instanceof Error)) throw error;
      capture.failure = { kind: "transport-or-parse", name: this.redact(error.name), message: this.redact(error.message), nonraw: true };
    }
    capture.finishedAt = new Date().toISOString();
    this.captures.push(capture);
    return capture;
  }
}
export function result(capture) {
  if (capture.failure) throw new EvidenceError(`request ${capture.id}: ${capture.failure.kind}`);
  return capture.result;
}
