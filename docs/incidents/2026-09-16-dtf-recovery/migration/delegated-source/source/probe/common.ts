import { mkdir, writeFile, appendFile } from "node:fs/promises";
import { join } from "node:path";
import { Interface, HDNodeWallet, keccak256, Transaction } from "ethers";
import type { TransactionRequest } from "ethers";
import { z } from "zod";

export const T = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
export const V = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
export const Y = "0xb55604cf4dcdabb362078e106d20f98512391edf";
export const DONOR = "0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3";
export const PIN = "0x67e5d17";
export const PINHASH = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
export const HIST = "0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb";
export const HW = "0x2c0400cf47e5ea01364e44c237aed22d7ae86199";
export const hex = z.string().regex(/^0x(?:[0-9a-fA-F]{2})*$/);
export const qty = z.string().regex(/^0x[0-9a-fA-F]+$/);
export const address = z.string().regex(/^0x[0-9a-fA-F]{40}$/).transform(v => v.toLowerCase());
export const hash = z.string().regex(/^0x[0-9a-fA-F]{64}$/);
export const abi = new Interface([
  "function withdrawClaim(uint256) returns(uint256)", "function reassign(address,uint256)",
  "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
  "function rewards(address) view returns(uint256)", "function phase() view returns(uint8)",
  "function claimVault() view returns(address)", "function asset() view returns(address)",
  "function decimals() view returns(uint8)", "function facetAddress(bytes4) view returns(address)",
  "function redeem(uint256,address,address) returns(uint256)", "function approve(address,uint256) returns(bool)",
  "function transfer(address,uint256) returns(bool)", "function transferFrom(address,address,uint256) returns(bool)",
  "function allowance(address,address) view returns(uint256)", "function booked(address) view returns(uint256)",
  "event ClaimWithdrawn(address indexed user,uint256 stakeAmount,uint256 claimOut)",
  "event Transfer(address indexed from,address indexed to,uint256 value)",
  "event Withdraw(address indexed sender,address indexed receiver,address indexed owner,uint256 assets,uint256 shares)",
]);
export const logSchema = z.object({
  address, topics: z.array(hash), data: hex, logIndex: qty,
  blockHash: hash, blockNumber: qty, transactionHash: hash, transactionIndex: qty,
  removed: z.literal(false),
}).passthrough();
export const receiptSchema = z.object({
  status: qty, from: address, to: address.nullable(), contractAddress: address.nullable(),
  transactionHash: hash, blockHash: hash, blockNumber: qty, transactionIndex: qty,
  logs: z.array(logSchema),
}).passthrough();
export const txSchema = z.object({
  hash, from: address, to: address.nullable(), input: hex, value: qty, nonce: qty,
  chainId: qty, blockHash: hash, blockNumber: qty, transactionIndex: qty,
}).passthrough();
export const blockSchema = z.object({
  number: qty, hash, parentHash: hash, transactions: z.array(hash),
}).passthrough();
export const frameSchema = z.object({
  type: z.string(), from: address, to: address.optional(), input: hex,
  output: hex.default("0x"), error: z.string().optional(), calls: z.array(z.unknown()).default([]),
}).passthrough();
export const json = (value: unknown) => JSON.stringify(value, (_, v: unknown) =>
  typeof v === "bigint" ? v.toString() : v, 2) + "\n";
export class ProofError extends Error {
  constructor(readonly condition: string) { super(condition); }
}
export function check(ok: unknown, message: string): asserts ok {
  if (!ok) throw new ProofError(message);
}
export const wallet = (i: number) => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${i}`);
export async function save(path: string, value: unknown) {
  await writeFile(path, json(value), { flag: "wx" });
}

/** Raw entity capture; no retry, redirect, polling, endpoint output or fallback. */
export class Rpc {
  private id = 0;
  constructor(readonly endpoint: URL, readonly directory: string, readonly secret = "") {}
  async send(method: string, params: readonly unknown[]): Promise<unknown> {
    const request = JSON.stringify({ jsonrpc: "2.0", id: ++this.id, method, params });
    const filename = join(this.directory, `${String(this.id).padStart(5, "0")}.json`);
    await mkdir(this.directory, { recursive: true });
    try {
      const response = await fetch(this.endpoint, { method: "POST", redirect: "error",
        headers: { "content-type": "application/json" }, body: request,
        signal: AbortSignal.timeout(120000) });
      const original = await response.text();
      const body = this.secret ? original.replaceAll(this.secret, "[REDACTED]")
        .replaceAll(encodeURIComponent(this.secret), "[REDACTED]") : original;
      await save(filename, { request, response: body, httpStatus: response.status, raw: body === original });
      const envelope = z.object({ jsonrpc: z.literal("2.0"), id: z.number(),
        result: z.unknown().optional(), error: z.unknown().optional() }).parse(JSON.parse(body));
      check(response.ok && envelope.id === this.id && !envelope.error, `RPC ${method} failed; see ${filename}`);
      return envelope.result;
    } catch (error) {
      if (error instanceof ProofError) throw error;
      // Only a safe classification is retained for transport exceptions.
      await appendFile(join(this.directory, "transport-errors.ndjson"),
        JSON.stringify({ id: this.id, method, error: error instanceof Error ? error.name : "unknown" }) + "\n");
      throw new ProofError(`transport/parse ${method} failed; no retry`);
    }
  }
}
export const call = async (rpc: Rpc, target: string, method: string, args: readonly unknown[] = [], tag = "latest") =>
  abi.decodeFunctionResult(method, hex.parse(await rpc.send("eth_call",
    [{ to: target, data: abi.encodeFunctionData(method, args) }, tag])))[0];
export const numberAt = async (rpc: Rpc, target: string, method: string, args: readonly unknown[] = [], tag = "latest") =>
  z.bigint().parse(await call(rpc, target, method, args, tag));
export async function signed(rpc: Rpc, index: number, request: TransactionRequest) {
  check(rpc.endpoint.href === "http://127.0.0.1:18579/", "signing endpoint must be owned18579");
  check(BigInt(qty.parse(await rpc.send("eth_chainId", []))) === 4663n, "signing chain");
  const signer = wallet(index);
  const nonce = Number(BigInt(qty.parse(await rpc.send("eth_getTransactionCount", [signer.address, "latest"]))));
  const raw = await signer.signTransaction({ chainId: 4663, nonce, gasLimit: 5000000,
    type: 2, maxFeePerGas: 2000000000n, maxPriorityFeePerGas: 100000000n, ...request });
  const hash_ = keccak256(raw);
  const parsed = Transaction.from(raw);
  check(parsed.from === signer.address && parsed.hash === hash_, "raw signature identity");
  await save(join(rpc.directory, `signed-${hash_}.json`), { raw, from: signer.address,
    nonce, hash: hash_, provenance: "original controlled public-development signature, captured before submission" });
  check(await rpc.send("eth_sendRawTransaction", [raw]) === hash_, "submitted hash");
  await rpc.send("evm_mine", []);
  return capture(rpc, hash_, raw);
}
export async function capture(rpc: Rpc, hash_: string, raw: string | null) {
  const receipt = receiptSchema.parse(await rpc.send("eth_getTransactionReceipt", [hash_]));
  const transaction = txSchema.parse(await rpc.send("eth_getTransactionByHash", [hash_]));
  const block = blockSchema.parse(await rpc.send("eth_getBlockByNumber", [receipt.blockNumber, false]));
  const trace = frameSchema.parse(await rpc.send("debug_traceTransaction", [hash_, { tracer: "callTracer" }]));
  check(block.transactions[Number(BigInt(receipt.transactionIndex))] === hash_
    && transaction.hash === hash_ && receipt.transactionHash === hash_
    && transaction.blockHash === receipt.blockHash && block.hash === receipt.blockHash
    && transaction.blockNumber === receipt.blockNumber
    && transaction.transactionIndex === receipt.transactionIndex, "canonical membership");
  for (const l of receipt.logs) check(l.transactionHash === hash_ && l.blockHash === block.hash
    && l.blockNumber === block.number && l.transactionIndex === receipt.transactionIndex, "canonical log");
  const result = { raw, receipt, transaction, block, trace };
  await save(join(rpc.directory, `mined-${hash_}.json`), result);
  return result;
}
