import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { Interface } from "ethers";
import { z } from "zod";
import { canonical, fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(import.meta.filename);
const runtime = z.string().parse(process.argv[2]);
const quantity = z.string().regex(/^0x[0-9a-f]+$/i);
const hash = z.string().regex(/^0x[0-9a-f]{64}$/i);
const log = z.object({ address: z.string(), topics: z.array(hash), data: z.string(),
  transactionHash: hash, transactionIndex: quantity, blockHash: hash, blockNumber: quantity,
  removed: z.literal(false) }).passthrough();
const mined = z.object({ transactionHash: hash, transactionIndex: quantity, blockHash: hash,
  blockNumber: quantity, blockTimestamp: z.number(), status: quantity, logs: z.array(log) }).passthrough();
const transaction = z.object({ hash, transactionIndex: quantity, blockHash: hash,
  blockNumber: quantity, from: z.string(), to: z.string().nullable(), input: z.string() }).passthrough();
const block = z.object({ hash, parentHash: hash, number: quantity, timestamp: quantity,
  transactions: z.array(hash) }).passthrough();
const blocks = new Map<string, z.infer<typeof block>>();
const transactions = new Map<string, z.infer<typeof transaction>>();
const receipts = new Map<string, z.infer<typeof mined>>();
const bodies = [];
for (const line of (await readFile(join(here, "wire.ndjson"), "utf8")).trim().split("\n")) {
  const observation = z.object({ request: z.object({ id: z.number(), method: z.string() }).passthrough(),
    body: z.string() }).safeParse(JSON.parse(line));
  if (!observation.success) continue;
  const row = observation.data;
  const response = z.object({ id: z.number(), jsonrpc: z.literal("2.0"),
    result: z.unknown() }).parse(JSON.parse(row.body));
  assert.equal(response.id, row.request.id);
  bodies.push({ id: row.request.id, method: row.request.method,
    bytes: Buffer.byteLength(row.body), sha256: fingerprint(row.body) });
  switch (row.request.method) {
    case "eth_getBlockByNumber": {
      const parsed = block.parse(response.result);
      assert(!blocks.has(parsed.hash));
      blocks.set(parsed.hash, parsed);
      break;
    }
    case "eth_getTransactionByHash": {
      const parsed = transaction.parse(response.result);
      assert(!transactions.has(parsed.hash));
      transactions.set(parsed.hash, parsed);
      break;
    }
    case "eth_getTransactionReceipt": {
      const parsed = mined.parse(response.result);
      assert(!receipts.has(parsed.transactionHash));
      receipts.set(parsed.transactionHash, parsed);
      break;
    }
  }
}
const ordered = [...blocks.values()].sort((a, b) => Number(BigInt(a.number) - BigInt(b.number)));
let previous = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
let height = 108944664n;
for (const header of ordered) {
  assert.equal(header.parentHash, previous);
  assert.equal(BigInt(header.number), height++);
  previous = header.hash;
  for (const [index, hash] of header.transactions.entries()) {
    const tx = transactions.get(hash), receipt = receipts.get(hash);
    assert(tx && receipt);
    assert.equal(tx.blockHash, header.hash);
    assert.equal(receipt.blockHash, header.hash);
    assert.equal(tx.blockNumber, header.number);
    assert.equal(receipt.blockNumber, header.number);
    assert.equal(BigInt(tx.transactionIndex), BigInt(index));
    assert.equal(BigInt(receipt.transactionIndex), BigInt(index));
    assert.equal(BigInt(receipt.blockTimestamp), BigInt(header.timestamp));
    for (const event of receipt.logs) {
      assert.equal(event.transactionHash, hash);
      assert.equal(event.transactionIndex, receipt.transactionIndex);
      assert.equal(event.blockHash, header.hash);
      assert.equal(event.blockNumber, header.number);
    }
  }
}
assert.equal(ordered.reduce((sum, b) => sum + b.transactions.length, 0), transactions.size);
assert.equal(transactions.size, receipts.size);
const manifest = z.object({ proxy: z.string() }).passthrough().parse(
  JSON.parse(await readFile(join(runtime, "post-capture.json"), "utf8")));
const events = new Interface([
  "event MigrationCapitalReceived(address indexed donor,address indexed token,uint256 amount)",
  "event IndependentAllocationIssued(address indexed recipient,bytes32 indexed configurationId,uint256 indexed bondTokenId,uint256 credit,uint256 issuedAt)",
  "event MigrationOwnerFirstBondPurchased(address indexed owner,uint256 indexed bondTokenId)",
]);
const capital = new Map<string, bigint>();
const issued = [];
const purchases = [];
for (const receipt of receipts.values()) for (const event of receipt.logs) {
  if (event.address !== manifest.proxy) continue;
  const parsed = events.parseLog(event);
  if (!parsed) continue;
  switch (parsed.name) {
    case "MigrationCapitalReceived": {
      const asset = String(parsed.args[1]).toLowerCase();
      capital.set(asset, (capital.get(asset) ?? 0n) + z.bigint().parse(parsed.args[2]));
      break;
    }
    case "IndependentAllocationIssued":
      issued.push({ transactionHash: receipt.transactionHash, recipient: String(parsed.args[0]).toLowerCase(),
        configurationId: String(parsed.args[1]), bondTokenId: String(parsed.args[2]), credit: String(parsed.args[3]) });
      break;
    case "MigrationOwnerFirstBondPurchased":
      purchases.push({ transactionHash: receipt.transactionHash, owner: String(parsed.args[0]).toLowerCase(),
        bondTokenId: String(parsed.args[1]) });
      break;
  }
}
assert.equal(capital.size, 2);
for (const value of capital.values()) assert.equal(value, 1000n * 10n ** 18n);
assert.equal(issued.length, 3);
assert.equal(new Set(issued.map(r => r.recipient)).size, 3);
assert.equal(new Set(issued.map(r => r.bondTokenId)).size, 3);
assert.equal(issued.reduce((sum, r) => sum + BigInt(r.credit), 0n), 1383n);
assert.equal(purchases.length, 1);
const books = [];
for (const name of (await readdir(runtime)).filter(n => n.startsWith("claimed-source-books-"))) {
  const data = z.object({ before: z.object({ weight: z.string(), sy: z.string(), shares: z.string() }),
    after: z.object({ weight: z.string(), sy: z.string(), shares: z.string() }) }).parse(
    JSON.parse(await readFile(join(runtime, name), "utf8")));
  const txHash = z.string().parse(name.match(/0x[0-9a-f]{64}/)?.[0]);
  const tx = transactions.get(txHash), receipt = receipts.get(txHash);
  assert(tx && receipt && BigInt(receipt.status) === 1n);
  const claim = new Interface(["function withdrawClaim(uint256)",
    "event ClaimWithdrawn(address indexed user,uint256 stakeAmount,uint256 claimOut)"]);
  const requested = z.bigint().parse(claim.decodeFunctionData("withdrawClaim", tx.input)[0]);
  const event = receipt.logs.map(l => claim.parseLog(l)).find(l => l?.name === "ClaimWithdrawn");
  assert(event);
  assert.equal(String(event.args[0]).toLowerCase(), tx.from);
  assert.equal(event.args[1], requested);
  assert.equal(BigInt(data.before.weight) - BigInt(data.after.weight), requested);
  assert.equal(BigInt(data.after.sy) - BigInt(data.before.sy), event.args[2]);
  books.push({ path: name, transactionHash: txHash, requested: String(requested),
    output: String(event.args[2]), vaultShares: String(BigInt(data.before.shares) - BigInt(data.after.shares)) });
}
assert.equal(books.length, 6);
assert(books.some(b => b.requested === "1" && b.output === "0" && b.vaultShares === "0"));
const result = { status: "VERIFIER_CANONICAL_SUPPLEMENT_COMPLETE", bodies, blockCount: blocks.size,
  transactionCount: transactions.size, capital: Object.fromEntries([...capital].map(([k, v]) => [k, String(v)])),
  issued, purchases, books, allHeaderTransactionReceiptAndLogBindings: true };
await writeFile(join(here, "canonical-proof.json"), canonical(result) + "\n", { flag: "wx" });
console.log(JSON.stringify({ ...result, bodies: bodies.length }));
