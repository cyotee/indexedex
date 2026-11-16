import { request } from "node:https";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { WT, OUT, fact, sha, text } from "./common.mjs";

export async function endpoint() {
  const source = await readFile(`${WT}/foundry.toml`, "utf8");
  const aliases = [...source.matchAll(/^robinhood_mainnet_alchemy\s*=\s*"([^"]+)"\s*$/gm)];
  fact(aliases.length === 1 && aliases[0][1] === "https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}", "existing alias");
  const key = process.env.ALCHEMY_KEY;
  fact(Boolean(key), "selected existing credential unavailable");
  return new URL(aliases[0][1].replace("${ALCHEMY_KEY}", encodeURIComponent(key)));
}

// Each safe capture is durable before the next request. No retries.
export class ReadRpc {
  captures = [];
  constructor(url, directory) { this.url = url; this.directory = directory; }
  safe(value) {
    let result = value;
    for (const secret of [this.url.href, process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")]) {
      if (secret) result = result.replaceAll(secret, "<redacted>");
    }
    return result.replace(/https?:\/\/[^\s"'<>\\]+/gi, "<redacted-url>");
  }
  async read(method, params) {
    fact(["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(method), "forbidden method");
    const id = this.captures.length + 1;
    fact(id <= 400, "bounded request cap");
    const body = JSON.stringify({ jsonrpc: "2.0", id, method, params });
    const prefix = join(OUT, this.directory, String(id).padStart(4, "0"));
    await writeFile(`${prefix}.request.json`, body, { flag: "wx" });
    const capture = { id, method, params, request: { body, bytes: Buffer.byteLength(body), sha256: sha(body) },
      startedAt: new Date().toISOString(), response: null, result: null, failure: null };
    try {
      const observed = await new Promise((resolve, reject) => {
        const req = request(this.url, { method: "POST", agent: false, signal: AbortSignal.timeout(20000),
          headers: { "content-type": "application/json", "accept-encoding": "identity", "content-length": Buffer.byteLength(body) } }, res => {
          const chunks = [];
          res.on("data", chunk => chunks.push(chunk));
          res.once("error", reject);
          res.once("end", () => resolve({ bytes: Buffer.concat(chunks), status: res.statusCode }));
        });
        req.once("error", reject);
        req.end(body);
      });
      const rawText = new TextDecoder("utf-8", { fatal: true }).decode(observed.bytes);
      const safe = this.safe(rawText), raw = safe === rawText;
      capture.response = { body: safe, bytes: Buffer.byteLength(safe), sha256: sha(safe),
        raw, receivedBytes: observed.bytes.length, httpStatus: observed.status };
      await writeFile(`${prefix}.response.${raw ? "raw" : "redacted"}`, raw ? observed.bytes : safe, { flag: "wx" });
      if (!raw || observed.status !== 200) capture.failure = { kind: raw ? "http" : "redacted-nonraw" };
      else {
        const envelope = JSON.parse(rawText);
        if (envelope.jsonrpc !== "2.0" || envelope.id !== id) capture.failure = { kind: "envelope", envelope };
        else if ("error" in envelope) capture.failure = { kind: "rpc", error: envelope.error };
        else if (envelope.result === null || envelope.result === undefined) capture.failure = { kind: "missing-result" };
        else capture.result = envelope.result;
      }
    } catch (error) {
      if (!(error instanceof Error)) throw error;
      capture.failure = { kind: "transport-or-parse", name: this.safe(error.name), message: this.safe(error.message), nonraw: true };
    }
    capture.finishedAt = new Date().toISOString();
    this.captures.push(capture);
    await writeFile(`${prefix}.capture.json`, text(capture), { flag: "wx" });
    return capture;
  }
}
