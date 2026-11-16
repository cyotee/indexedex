import { FetchRequest, Interface, JsonRpcProvider, Network, Wallet, keccak256 } from "ethers";
import { z } from "zod";
import { hash, hex } from "./schema.js";
import { ExecutionError, quantity, receipt, rpcLog } from "./execution-schema.js";
import { canonical } from "./provenance.js";
import type { ExecutionManifest, Mode, Receipt } from "./execution-schema.js";

export const DEV = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
// Public Anvil development key. Never selected for nonlocal execution.
const DEV_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const headerSchema = z.object({ hash, number: quantity, transactions: z.array(hash) }).passthrough();

export async function canonicalReceipt(provider: Pick<JsonRpcProvider, "send">, txHash: string): Promise<Receipt | undefined> {
  const raw: unknown = await provider.send("eth_getTransactionReceipt", [txHash]);
  if (raw === null) return undefined;
  const mined = receipt.parse(raw);
  const block = headerSchema.parse(await provider.send("eth_getBlockByNumber", [mined.blockNumber, false]));
  const index = Number(BigInt(mined.transactionIndex));
  if (mined.transactionHash !== txHash || block.hash !== mined.blockHash || block.number !== mined.blockNumber
    || !Number.isSafeInteger(index) || block.transactions[index] !== txHash) {
    throw new ExecutionError("AMBIGUOUS", "receipt is not canonical or transaction order differs");
  }
  const logs = z.array(rpcLog).parse(await provider.send("eth_getLogs", [{ blockHash: mined.blockHash }]));
  const selected = logs.filter((l) => l.transactionHash === txHash);
  if (canonical(selected) !== canonical(mined.logs)) throw new ExecutionError("AMBIGUOUS", "canonical transaction logs differ");
  let previous = -1n;
  for (const log of logs) {
    const position = BigInt(log.logIndex);
    if (position !== previous + 1n || log.blockHash !== mined.blockHash || log.blockNumber !== mined.blockNumber
      || block.transactions[Number(BigInt(log.transactionIndex))] !== log.transactionHash) {
      throw new ExecutionError("AMBIGUOUS", "canonical log order or transaction identity differs");
    }
    previous = position;
  }
  if (mined.logs.some((l) => l.transactionIndex !== mined.transactionIndex)) {
    throw new ExecutionError("AMBIGUOUS", "receipt log transaction index differs");
  }
  return mined;
}

export class Rpc {
  private position: Receipt | undefined;
  private beforePosition = false;
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
          || mode.chainId !== this.manifest.chainId || mode.proxy !== this.manifest.proxy) {
          throw new ExecutionError("DOMAIN", "fresh chain/proxy confirmations required");
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
    const data = iface.encodeFunctionData(method, args);
    const position = this.position;
    let value: string;
    if (position && block === position.blockNumber) {
      const header = await this.header(block);
      const index = Number(BigInt(position.transactionIndex));
      const next = index + (this.beforePosition ? 0 : 1);
      if (header.hash !== position.blockHash || header.transactions[index] !== position.transactionHash) {
        throw new ExecutionError("AMBIGUOUS", "transaction-prefix header changed");
      }
      if (next < header.transactions.length) {
        const frame = z.object({
          type: z.literal("CALL"), from: z.string(), to: z.string(), input: hex, output: hex,
          calls: z.array(z.object({ type: z.string(), from: z.string(), to: z.string(), input: hex, output: hex,
            error: z.string().optional() }).passthrough()).optional(), error: z.string().optional(),
        }).passthrough().parse(await this.send("debug_traceCall", [
          { from: this.manifest.signer, to, data }, block, { tracer: "callTracer", txIndex: `0x${next.toString(16)}` },
        ]));
        if (frame.error || frame.from.toLowerCase() !== this.manifest.signer
          || frame.to.toLowerCase() !== to.toLowerCase() || frame.input !== data) {
          throw new ExecutionError("STATE", "transaction-prefix getter execution differs");
        }
        for (const child of frame.calls ?? []) {
          if (child.error) throw new ExecutionError("STATE", "transaction-prefix getter reverted");
          if (child.type === "DELEGATECALL") {
            const binding = this.manifest.bindings.find((b) => b.address === child.to.toLowerCase());
            if (!binding || child.from.toLowerCase() !== to.toLowerCase() || child.input !== data
              || child.output !== frame.output
              || keccak256(hex.parse(await this.send("eth_getCode", [binding.address, block]))) !== binding.codeHash) {
              throw new ExecutionError("STATE", "transaction-prefix executing code is unbound");
            }
          }
        }
        value = frame.output;
      } else value = hex.parse(await this.send("eth_call", [{ to, data }, block]));
      if ((await this.header(block)).hash !== position.blockHash) throw new ExecutionError("AMBIGUOUS", "transaction-prefix header changed");
    } else value = hex.parse(await this.send("eth_call", [{ to, data }, block]));
    return iface.decodeFunctionResult(method, value);
  }
  async atReceipt<T>(mined: Receipt, action: () => Promise<T>, before = false): Promise<T> {
    const previous = this.position;
    const previousBefore = this.beforePosition;
    this.position = mined;
    this.beforePosition = before;
    try { return await action(); } finally { this.position = previous; this.beforePosition = previousBefore; }
  }
  async canonicalReceipt(txHash: string): Promise<Receipt | undefined> {
    return canonicalReceipt(this, txHash);
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
