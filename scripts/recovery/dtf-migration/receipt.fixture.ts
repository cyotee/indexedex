import { createServer } from "node:http";
import { once } from "node:events";
import { mkdtemp, mkdir, writeFile, rm, realpath } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { id } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { ANCHOR, block, receipt, transaction } from "./receipt-association.js";
import { claimSource, legacy, sy } from "./receipt-input.js";
import type { ReceiptSelection } from "./receipt-input.js";
import { ReceiptRpc } from "./receipt-rpc.js";
import { collectReceipts } from "./receipt-evidence.js";

export const wallet = `0x${"1".repeat(40)}`;
export const txHash = `0x${"a".repeat(64)}`;
export const claimHash = `0x${"b".repeat(64)}`;
export const blockHash = `0x${"c".repeat(64)}`;
export const claimBlockHash = `0x${"d".repeat(64)}`;
const parentHash = `0x${"e".repeat(64)}`;
const word = (v: string) => BigInt(v).toString(16).padStart(64, "0");
const addressTopic = (v: string) => `0x${v.slice(2).padStart(64, "0")}`;
const transferTopic = id("Transfer(address,address,uint256)");
export const purchaseTx = transaction.parse({ hash: txHash, blockHash, blockNumber: "0xa", transactionIndex: "0x0",
  from: wallet, to: legacy.weighted, value: "0x0", input: "0x12345678", nonce: "0x1" });
export const purchaseBlock = block.parse({ hash: blockHash, number: "0xa", parentHash, timestamp: "0x20", transactions: [txHash] });
const commonLog = { blockHash, blockNumber: "0xa", transactionIndex: "0x0", transactionHash: txHash, removed: false };
export const purchaseReceipt = receipt.parse({ ...commonLog, from: wallet, to: legacy.weighted, status: "0x1", logs: [
  { ...commonLog, address: legacy.weightedNft, logIndex: "0x1", data: "0x",
    topics: [transferTopic, addressTopic(legacy.zero), addressTopic(wallet), `0x${word("3")}`] },
  { ...commonLog, address: legacy.dtf, logIndex: "0x2", data: `0x${word("12")}`,
    topics: [transferTopic, addressTopic(wallet), addressTopic(legacy.weighted)] },
  { ...commonLog, address: legacy.weightedNft, logIndex: "0x3", data: `0x${word("7")}${word("10")}${word("90")}`,
    topics: [id("BondPurchased(uint256,address,uint256,uint256,uint256)"), `0x${word("3")}`, addressTopic(wallet)] },
] });
const claimCommon = { blockHash: claimBlockHash, blockNumber: "0xb", transactionIndex: "0x0", transactionHash: claimHash, removed: false };
export const claimTx = { ...purchaseTx, ...claimCommon, hash: claimHash, to: claimSource,
  input: `${id("withdrawClaim(uint256)").slice(0, 10)}${word("5")}` };
export const claimReceipt = receipt.parse({ ...purchaseReceipt, ...claimCommon, to: claimSource, logs: [
  { ...claimCommon, address: sy, logIndex: "0x1", data: `0x${word("9")}`,
    topics: [transferTopic, addressTopic(`0x${"2".repeat(40)}`), addressTopic(wallet)] },
  { ...claimCommon, address: claimSource, logIndex: "0x2", data: `0x${word("5")}${word("9")}`,
    topics: [id("ClaimWithdrawn(address,uint256,uint256)"), addressTopic(wallet)] },
] });
const csv = (header: readonly string[], rows: readonly (readonly string[])[]) =>
  [header, ...rows].map((r) => r.map((v) => `"${v}"`).join(",")).join("\n") + "\n";
export async function inputFixture(parent: string) {
  const root = join(parent, "input"); await mkdir(root); await mkdir(join(root, "evidence"));
  const sibling = join(parent, "2026-09-16-dtf-pre-exploit"); await mkdir(sibling);
  const tables = new Map([
    ["evidence/weighted-bonds.csv", csv(["token_id", "purchase_tx", "purchase_recipient", "current_owner", "purchase_block", "pre_attack", "original_principal_detf_raw"],
      [["3", txHash, wallet, wallet, "10", "true", "7"]])],
    ["evidence/earlier-cp-bonds.csv", csv(["token_id", "owner", "original_lp_shares_raw", "direct_dtf_paid_raw", "direct_weth_paid_raw", "routed_dtf_received_by_detf_raw", "purchase_tx"], [])],
    ["evidence/transfers.csv", csv(["event_id", "block", "transaction_index", "log_index", "tx", "asset", "from", "to", "amount_raw", "token_id"], [
      [`${legacy.weightedNft}:${txHash}:1`, "10", "0", "1", txHash, legacy.weightedNft, legacy.zero, wallet, "", "3"],
      [`${legacy.dtf}:${txHash}:2`, "10", "0", "2", txHash, legacy.dtf, wallet, legacy.weighted, "12", ""],
      [`${sy}:${claimHash}:1`, "11", "0", "1", claimHash, sy, `0x${"2".repeat(40)}`, wallet, "9", ""],
    ])],
    ["../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv", csv(["tx", "category", "bond_token_id", "dtf_wei", "payer", "bond_recipient"], [[txHash, "bond", "3", "12", wallet, wallet]])],
    ["conversions.csv", csv(["conversion_id", "kind", "recipient", "principal_raw", "output_raw", "output_asset", "output_decimals", "block", "tx"], [
      ["claim", "legacy_weight_to_sy", wallet, "5", "9", sy, "9", "11", claimHash],
      ["conversion", "detf_to_sdetf", legacy.weighted, "", "12", legacy.dtf, "18", "10", txHash],
    ])],
    ["observed-recoveries.csv", csv(["recovery_id", "recipient", "asset", "decimals", "observed_amount_raw", "block", "tx", "log_index", "R_eth", "deduct_from_R"], [
      ["recovery", wallet, sy, "9", "9", "11", claimHash, "1", "", "false"],
    ])],
  ]);
  const binding = (text: string) => ({ bytes: Buffer.byteLength(text), sha256: fingerprint(text) });
  const sources = { chainId: 4663, incident: { lastFullBlock: 19, attackBlock: 20, attackTransactionIndex: 1, attackTransaction: txHash },
    evidenceCutoff: { block: Number(ANCHOR.number), hash: ANCHOR.hash, utc: "historical" }, sourceNotes: [],
    sources: [...tables].filter(([p]) => p.startsWith("evidence")).map(([path, text]) => ({
      id: path.includes("weighted-bonds") ? "S008" : path.includes("earlier") ? "S009" : "S011", path, description: "fixture", ...binding(text),
    })) };
  tables.set("sources.json", canonical(sources));
  for (const [path, text] of tables) await writeFile(join(root, path), text);
  await writeFile(join(root, "manifest.json"), canonical({ files: Object.fromEntries([...tables].map(([p, t]) => [p, binding(t)])) }));
  return root;
}
const wireRequest = z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()) });
export type WireRequest = z.infer<typeof wireRequest>;
export function fixtureResponse(q: WireRequest): unknown {
  let result: unknown;
  switch (q.method) {
    case "eth_chainId": result = "0x1237"; break;
    case "eth_getTransactionByHash": result = q.params[0] === txHash ? purchaseTx : claimTx; break;
    case "eth_getTransactionReceipt": result = q.params[0] === txHash ? purchaseReceipt : claimReceipt; break;
    case "eth_getBlockByNumber":
    case "eth_getBlockByHash":
      result = q.params[0] === `0x${BigInt(ANCHOR.number).toString(16)}`
        ? { ...purchaseBlock, number: `0x${BigInt(ANCHOR.number).toString(16)}`, hash: ANCHOR.hash }
        : q.params[0] === "0xb" || q.params[0] === claimBlockHash
          ? { ...purchaseBlock, hash: claimBlockHash, number: "0xb", transactions: [claimHash] } : purchaseBlock;
      break;
    default: throw new TypeError(`unexpected test method ${q.method}`);
  }
  return { jsonrpc: "2.0", id: q.id, result };
}
export async function wireFixture(respond: (q: WireRequest) => unknown) {
  const server = createServer(async (req, res) => {
    let body = ""; for await (const chunk of req) body += String(chunk);
    const q = wireRequest.parse(JSON.parse(body));
    res.setHeader("content-type", "application/json"); res.end(JSON.stringify(respond(q)));
  });
  const ready = once(server, "listening"); server.listen(0, "127.0.0.1"); await ready;
  const address = server.address();
  if (!address || typeof address === "string") throw new TypeError("fixture address");
  return { url: new URL(`http://127.0.0.1:${address.port}`), async close() {
    const closed = once(server, "close"); server.close(); await closed;
  } };
}
export async function collectionFixture(respond: (q: WireRequest) => unknown = fixtureResponse,
  selection: ReceiptSelection = "purchases-and-claims") {
  const parent = await mkdtemp(join(await realpath(tmpdir()), "dtf-receipts-"));
  const root = await inputFixture(parent);
  const server = await wireFixture(respond);
  const output = join(parent, "archive");
  try {
    const rpc = new ReceiptRpc(server.url, join(output, "http"));
    const archive = await collectReceipts(root, output, rpc, selection);
    return { archive, captures: rpc.captures };
  } finally { await server.close(); await rm(parent, { recursive: true }); }
}
