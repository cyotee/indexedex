import { FetchRequest, Interface, JsonRpcProvider, Network, Wallet } from "ethers";
import { z } from "zod";
import { hash, hex } from "./schema.js";
import { ExecutionError, quantity, receipt } from "./execution-schema.js";
import type { ExecutionManifest, Mode, Receipt } from "./execution-schema.js";

export const DEV = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
// Public Anvil development key. Never selected for nonlocal execution.
const DEV_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const headerSchema = z.object({ hash, number: quantity }).passthrough();

export class Rpc {
  readonly provider: JsonRpcProvider;
  readonly endpoint: URL;
  constructor(readonly manifest: ExecutionManifest) {
    const endpoint = process.env[manifest.rpcEnv];
    if (!endpoint) throw new ExecutionError("DOMAIN", "missing selected RPC environment variable");
    this.endpoint = new URL(endpoint);
    if (!["http:", "https:"].includes(this.endpoint.protocol)) throw new ExecutionError("DOMAIN", "HTTP RPC required");
    const request = new FetchRequest(endpoint);
    request.timeout = 15000;
    this.provider = new JsonRpcProvider(request, new Network("migration", BigInt(manifest.chainId)),
      { staticNetwork: true, batchMaxCount: 1, cacheTimeout: -1 });
  }

  async send(method: string, params: readonly unknown[]): Promise<unknown> {
    try { return await this.provider.send(method, [...params]); }
    catch (error) {
      if (error instanceof Error) {
        const revert = "data" in error && typeof error.data === "string" && /^0x[0-9a-f]*$/i.test(error.data) ? error.data : "unavailable";
        throw new ExecutionError("RPC", `${method} failed; revert=${revert}; endpoint redacted`);
      }
      throw error;
    }
  }

  async guard(mode: Mode): Promise<void> {
    if (BigInt(quantity.parse(await this.send("eth_chainId", []))).toString() !== this.manifest.chainId) {
      throw new ExecutionError("DOMAIN", "wrong chain");
    }
    const loopback = ["127.0.0.1", "localhost", "[::1]"].includes(this.endpoint.hostname);
    if (this.manifest.purpose === "synthetic-local" && !loopback) throw new ExecutionError("DOMAIN", "synthetic input is local only");
    if (this.manifest.local) {
      if (!loopback) throw new ExecutionError("DOMAIN", "local identity requires loopback");
      const metadata = z.object({
        instanceId: z.string(),
        forkedNetwork: z.object({
          chainId: z.number().int().safe(), forkBlockNumber: z.number().int().safe(), forkBlockHash: hash,
        }),
      }).passthrough().parse(await this.send("anvil_metadata", []));
      const expected = this.manifest.local;
      if (metadata.instanceId !== expected.instanceId
        || String(metadata.forkedNetwork.chainId) !== this.manifest.chainId
        || String(metadata.forkedNetwork.forkBlockNumber) !== expected.forkBlockNumber
        || metadata.forkedNetwork.forkBlockHash !== expected.forkBlockHash) {
        throw new ExecutionError("DOMAIN", "Anvil instance or fork identity changed");
      }
      const block = await this.header(`0x${BigInt(expected.forkBlockNumber).toString(16)}`);
      if (block.hash !== expected.forkBlockHash) throw new ExecutionError("DOMAIN", "historical fork header changed");
    }
    switch (mode.kind) {
      case "simulate": return;
      case "local":
        if (!loopback || !this.manifest.local || mode.instanceId !== this.manifest.local.instanceId
          || this.manifest.signer !== DEV) throw new ExecutionError("DOMAIN", "explicit exact local identity required");
        return;
      case "broadcast":
        if (this.manifest.purpose !== "operational-review" || this.manifest.local || loopback
          || mode.chainId !== this.manifest.chainId || mode.proxy !== this.manifest.proxy
          || mode.snapshotId !== (this.manifest.snapshotId ?? "uncaptured")) {
          throw new ExecutionError("DOMAIN", "fresh chain/proxy/snapshot confirmations required");
        }
        return;
      default: return assertNever(mode);
    }
  }

  wallet(mode: Mode): Wallet {
    switch (mode.kind) {
      case "simulate": throw new ExecutionError("DOMAIN", "simulation cannot load a signer");
      case "local": return new Wallet(DEV_KEY);
      case "broadcast": {
        const key = process.env[mode.keyEnv];
        if (!key) throw new ExecutionError("DOMAIN", "selected signing key unavailable");
        const wallet = new Wallet(key);
        if (wallet.address.toLowerCase() !== this.manifest.signer) throw new ExecutionError("DOMAIN", "wrong signer");
        return wallet;
      }
      default: return assertNever(mode);
    }
  }

  async header(tag = "latest") { return headerSchema.parse(await this.send("eth_getBlockByNumber", [tag, false])); }
  async nonce(tag: "latest" | "pending"): Promise<bigint> {
    return BigInt(quantity.parse(await this.send("eth_getTransactionCount", [this.manifest.signer, tag])));
  }
  async call(to: string, iface: Interface, method: string, args: readonly unknown[] = [], block = "latest") {
    const value = hex.parse(await this.send("eth_call", [{ to, data: iface.encodeFunctionData(method, args) }, block]));
    return iface.decodeFunctionResult(method, value);
  }
  async canonicalReceipt(txHash: string): Promise<Receipt | undefined> {
    const value = await this.send("eth_getTransactionReceipt", [txHash]);
    if (value === null) return undefined;
    const mined = receipt.parse(value);
    if (mined.transactionHash !== txHash || (await this.header(mined.blockNumber)).hash !== mined.blockHash) {
      throw new ExecutionError("AMBIGUOUS", "receipt is not canonical");
    }
    return mined;
  }
  close(): void { this.provider.destroy(); }
}
export function assertNever(value: never): never { throw new ExecutionError("DOMAIN", `unknown variant ${String(value)}`); }

// Subscription acknowledgement precedes the caller's send. A single immediate
// receipt read also covers automining between the subscription and send response.
export async function subscribeReceipt(rpc: Pick<Rpc, "endpoint" | "canonicalReceipt">, txHash: string) {
  const endpoint = new URL(rpc.endpoint);
  endpoint.protocol = endpoint.protocol === "https:" ? "wss:" : "ws:";
  const socket = new WebSocket(endpoint);
  const signal = AbortSignal.timeout(60000);
  let acknowledge: () => void = () => undefined;
  let fail: (reason: unknown) => void = () => undefined;
  const ready = new Promise<void>((resolve, reject) => { acknowledge = resolve; fail = reject; });
  let deliver: (value: Receipt) => void = () => undefined;
  let rejectReceipt: (reason: unknown) => void = () => undefined;
  const result = new Promise<Receipt>((resolve, reject) => { deliver = resolve; rejectReceipt = reject; });
  // A rejection can precede caller await during send; keep it handled, not swallowed.
  void result.catch(() => undefined);
  const check = async () => {
    try { const value = await rpc.canonicalReceipt(txHash); if (value) deliver(value); }
    catch (error) { rejectReceipt(error); }
  };
  const abort = () => {
    const error = new ExecutionError("AMBIGUOUS", "bounded receipt subscription ended; resume must reconcile");
    fail(error); rejectReceipt(error); socket.close();
  };
  signal.addEventListener("abort", abort, { once: true });
  socket.addEventListener("open", () => socket.send(JSON.stringify({
    jsonrpc: "2.0", id: 1, method: "eth_subscribe", params: ["newHeads"],
  })), { once: true });
  socket.addEventListener("error", abort, { once: true });
  socket.addEventListener("close", abort, { once: true });
  socket.addEventListener("message", (event) => {
    try {
      const message = z.object({ id: z.number().optional(), result: z.unknown().optional(),
        method: z.string().optional(), error: z.unknown().optional() }).passthrough().parse(JSON.parse(String(event.data)));
      if (message.id === 1 && typeof message.result === "string") acknowledge();
      else if (message.error) abort();
      else if (message.method === "eth_subscription") void check();
    } catch (error) { fail(error); rejectReceipt(error); }
  });
  try { await ready; } catch (error) { socket.close(); throw error; }
  return {
    async mined(): Promise<Receipt> { await check(); return result; },
    close(): void {
      signal.removeEventListener("abort", abort);
      socket.removeEventListener("close", abort);
      socket.close();
    },
  };
}
