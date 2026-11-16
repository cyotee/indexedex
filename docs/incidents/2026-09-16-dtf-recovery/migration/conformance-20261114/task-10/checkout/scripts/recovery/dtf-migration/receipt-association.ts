import { z } from "zod";
import { hash, hex } from "./schema.js";

export const ANCHOR = { number: "108944663", hash: "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733" } as const;
export const quantity = z.string().regex(/^0x(?:0|[1-9a-f][0-9a-f]*)$/).refine((v) => BigInt(v) < 2n ** 256n);
export const rpcAddress = z.string().regex(/^0x[0-9a-fA-F]{40}$/).transform((v) => v.toLowerCase());
const association = { blockHash: hash, blockNumber: quantity, transactionIndex: quantity };
export const transaction = z.object({
  ...association, hash, from: rpcAddress, to: rpcAddress.nullable(), value: quantity,
  input: hex, nonce: quantity,
}).passthrough().readonly();
export const log = z.object({
  ...association, transactionHash: hash, logIndex: quantity, address: rpcAddress,
  topics: z.array(hash).readonly(), data: hex, removed: z.literal(false),
}).passthrough().readonly();
export const receipt = z.object({
  ...association, transactionHash: hash, from: rpcAddress, to: rpcAddress.nullable(),
  status: z.enum(["0x0", "0x1"]), logs: z.array(log).readonly(),
}).passthrough().readonly();
export const block = z.object({
  hash, number: quantity, parentHash: hash, timestamp: quantity,
  transactions: z.array(hash).readonly(),
}).passthrough().readonly();
export type Transaction = z.infer<typeof transaction>;
export type Receipt = z.infer<typeof receipt>;
export type Block = z.infer<typeof block>;
export type Log = z.infer<typeof log>;
export type Associated = {
  readonly transaction: Transaction; readonly receipt: Receipt;
  readonly byHash: Block; readonly byNumber: Block;
};
export function associationConflicts(expected: string, observed: Associated): readonly string[] {
  const { transaction: tx, receipt: r, byHash: b, byNumber: n } = observed;
  const conflicts: string[] = [];
  if (tx.hash !== expected || r.transactionHash !== expected) conflicts.push("transaction-hash");
  if (tx.blockHash !== r.blockHash || b.hash !== tx.blockHash || n.hash !== b.hash) conflicts.push("block-hash");
  if (tx.blockNumber !== r.blockNumber || tx.blockNumber !== b.number || b.number !== n.number) conflicts.push("block-number");
  if (BigInt(tx.blockNumber) > BigInt(ANCHOR.number)) conflicts.push("after-anchor");
  if (tx.transactionIndex !== r.transactionIndex) conflicts.push("transaction-index");
  if (tx.from !== r.from || tx.to !== r.to) conflicts.push("receipt-endpoints");
  if (new Set(b.transactions).size !== b.transactions.length || new Set(n.transactions).size !== n.transactions.length
    || b.transactions.length !== n.transactions.length
    || b.transactions.some((h, i) => h !== n.transactions[i])
    || b.transactions.filter((h) => h === expected).length !== 1
    || b.transactions[Number(BigInt(tx.transactionIndex))] !== expected) conflicts.push("block-membership");
  if (b.parentHash !== n.parentHash || b.timestamp !== n.timestamp) conflicts.push("canonical-header");
  const indices = new Set<string>();
  let preceding = -1n;
  for (const l of r.logs) {
    if (l.transactionHash !== expected || l.blockHash !== tx.blockHash || l.blockNumber !== tx.blockNumber
      || l.transactionIndex !== tx.transactionIndex) conflicts.push(`log-association:${l.logIndex}`);
    if (indices.has(l.logIndex) || BigInt(l.logIndex) <= preceding) conflicts.push(`log-order:${l.logIndex}`);
    indices.add(l.logIndex); preceding = BigInt(l.logIndex);
  }
  if (r.status !== "0x1") conflicts.push("transaction-reverted");
  return conflicts;
}
