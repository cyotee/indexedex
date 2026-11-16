import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";

export type ReadMethod = "eth_chainId" | "eth_getTransactionByHash" | "eth_getTransactionReceipt"
  | "eth_getBlockByHash" | "eth_getBlockByNumber";
export type RpcResult<T> =
  | { readonly kind: "success"; readonly id: number; readonly value: T }
  | { readonly kind: "failure"; readonly id: number; readonly reason: string };
type Capture = {
  readonly id: number; readonly method: ReadMethod; readonly params: readonly unknown[];
  readonly request: { readonly path: string; readonly bytes: number; readonly sha256: string };
  readonly response: { readonly path: string; readonly bytes: number; readonly sha256: string;
    readonly raw: boolean; readonly receivedBytes: number } | null;
  readonly http: { readonly status: number; readonly contentType: string | null; readonly contentEncoding: string | null } | null;
  readonly transportError?: { readonly name: string; readonly message: string };
  readonly outcome: string;
};
const envelope = z.object({ jsonrpc: z.literal("2.0"), id: z.number().int().safe() }).passthrough();
// Direct HTTP has no provider middleware, retries, redirects, discovery or hidden methods.
export class ReceiptRpc {
  private sequence = 0;
  readonly captures: Capture[] = [];
  private readonly secrets: readonly string[];
  constructor(private readonly endpoint: URL, private readonly directory: string) {
    this.secrets = [endpoint.href, endpoint.username, endpoint.password,
      ...endpoint.pathname.split("/").filter((s) => s.length >= 8).flatMap((s) => [s, decodeURIComponent(s)]),
      ...endpoint.searchParams.values()].filter(Boolean);
  }
  private redact(text: string): string {
    let safe = text;
    for (const secret of this.secrets) safe = safe.replaceAll(secret, "<redacted>");
    return safe.replace(/https?:\/\/[^\s"'<>\\]+/gi, "<redacted-url>");
  }
  async read<T>(method: ReadMethod, params: readonly unknown[], schema: z.ZodType<T>): Promise<RpcResult<T>> {
    const id = ++this.sequence;
    const requestBytes = Buffer.from(canonical({ jsonrpc: "2.0", id, method, params }));
    const requestPath = `${String(id).padStart(4, "0")}.request.json`;
    await writeFile(join(this.directory, requestPath), requestBytes, { flag: "wx" });
    const requestIdentity = { path: requestPath, bytes: requestBytes.length, sha256: fingerprint(requestBytes) };
    const fail = (reason: string): RpcResult<T> => ({ kind: "failure", id, reason });
    let observed: { readonly bytes: Buffer; readonly status: number; readonly contentType: string | null;
      readonly contentEncoding: string | null };
    try {
      observed = await new Promise((resolve, reject) => {
        const send = this.endpoint.protocol === "https:" ? httpsRequest : httpRequest;
        const req = send(this.endpoint, { method: "POST", agent: false, signal: AbortSignal.timeout(20000),
          headers: { "content-type": "application/json", "accept-encoding": "identity", "content-length": requestBytes.length } }, (res) => {
          const chunks: Buffer[] = [];
          res.on("data", (chunk: Buffer) => chunks.push(chunk));
          res.once("error", reject);
          res.once("end", () => resolve({ bytes: Buffer.concat(chunks), status: res.statusCode ?? 0,
            contentType: typeof res.headers["content-type"] === "string" ? res.headers["content-type"] : null,
            contentEncoding: typeof res.headers["content-encoding"] === "string" ? res.headers["content-encoding"] : null }));
        });
        req.once("error", reject); req.end(requestBytes);
      });
    } catch (error) {
      if (!(error instanceof Error)) throw error;
      // Transport messages may contain endpoint credentials. Never emit them.
      this.captures.push({ id, method, params, request: requestIdentity, response: null, http: null,
        transportError: { name: this.redact(error.name), message: this.redact(error.message) }, outcome: "transport-failure" });
      return fail("transport-failure");
    }
    const decoded = observed.bytes.toString("utf8");
    const safe = this.redact(decoded);
    const raw = safe === decoded;
    const saved = raw ? observed.bytes : Buffer.from(safe);
    const responsePath = `${String(id).padStart(4, "0")}.${raw ? "response.raw" : "response.redacted"}`;
    await writeFile(join(this.directory, responsePath), saved, { flag: "wx" });
    let result: RpcResult<T>;
    if (observed.status !== 200) result = fail(`http-status:${observed.status}`);
    else if (!raw) result = fail("credential-bearing-response-redacted");
    else {
      try {
        const json: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(observed.bytes));
        const parsed = envelope.safeParse(json);
        if (!parsed.success || parsed.data.id !== id) result = fail("response-envelope-or-id");
        else if ("error" in parsed.data) result = fail("rpc-error");
        else if (!("result" in parsed.data)) result = fail("missing-result");
        else if (parsed.data.result === null) result = fail("null-result");
        else {
          const value = schema.safeParse(parsed.data.result);
          result = value.success ? { kind: "success", id, value: value.data } : fail("result-schema");
        }
      } catch (error) {
        if (!(error instanceof SyntaxError || error instanceof TypeError)) throw error;
        result = fail("invalid-json-or-utf8");
      }
    }
    this.captures.push({ id, method, params, request: requestIdentity,
      response: { path: responsePath, bytes: saved.length, sha256: fingerprint(saved), raw, receivedBytes: observed.bytes.length },
      http: { status: observed.status, contentType: observed.contentType === null ? null : this.redact(observed.contentType),
        contentEncoding: observed.contentEncoding === null ? null : this.redact(observed.contentEncoding) },
      outcome: result.kind === "success" ? "success" : result.reason });
    return result;
  }
}
