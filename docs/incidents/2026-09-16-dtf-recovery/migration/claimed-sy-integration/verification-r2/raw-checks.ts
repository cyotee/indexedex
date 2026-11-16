import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Interface } from "ethers";
import { z } from "zod";
import { canonical, required } from "../implementation/probe/evidence.js";
import type { receipts } from "../implementation/probe/receipts.js";

const object = z.record(z.string(), z.unknown());
const rpc = z.object({
  request: z.object({ id: z.number(), jsonrpc: z.literal("2.0"), method: z.string(), params: z.array(z.unknown()) }),
  body: z.string(),
}).passthrough();
const tx = z.object({
  hash: z.string(), from: z.string(), to: z.string().nullable(),
  input: z.string(), blockNumber: z.string(), blockHash: z.string(), transactionIndex: z.string(),
}).passthrough();
const receipt = z.object({
  transactionHash: z.string(), blockHash: z.string(), blockNumber: z.string(),
  transactionIndex: z.string(), status: z.string(), logs: z.array(object),
}).passthrough();
const abi = new Interface([
  "function withdrawClaim(uint256) returns(uint256)",
  "function surrenderMigrationWeightedSy(bytes32,uint256,uint256,uint256) returns(uint256,uint256)",
  "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)",
]);
const source = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
const book = z.object({ tag: z.string(), values: z.record(z.string(), z.unknown()) });
const observed = z.object({
  kind: z.literal("observed"), transaction: tx, receipt,
  trace: z.unknown(), books: z.array(book).length(2),
});
const frame = z.object({
  to: z.string(), input: z.string(), calls: z.array(z.unknown()).default([]),
  error: z.string().optional(),
}).passthrough();
const flatten = (raw: unknown): z.infer<typeof frame>[] => {
  const row = frame.parse(raw);
  return [row, ...row.calls.flatMap(flatten)];
};
export async function rawChecks(context: {
  readonly wire: string; readonly books: string;
  readonly staking: string; readonly bond: string;
  readonly signed: Awaited<ReturnType<typeof receipts>>;
}) {
  const transactions = new Map<string, z.infer<typeof tx>>();
  const receipts = new Map<string, z.infer<typeof receipt>>();
  const blocks = new Map<string, z.infer<typeof object>>();
  let responses = 0;
  for (const line of (await readFile(context.wire, "utf8")).trim().split("\n")) {
    const row = rpc.safeParse(JSON.parse(line));
    if (!row.success) continue;
    const response = z.object({ id: z.number(), jsonrpc: z.literal("2.0"), result: z.unknown() }).parse(JSON.parse(row.data.body));
    assert.equal(response.id, row.data.request.id);
    responses++;
    switch (row.data.request.method) {
      case "eth_getBlockByNumber": {
        const value = object.parse(response.result);
        blocks.set(z.string().parse(value["hash"]), value);
        break;
      }
      case "eth_getTransactionByHash": {
        const value = tx.parse(response.result);
        transactions.set(value.hash, value);
        break;
      }
      case "eth_getTransactionReceipt": {
        const value = receipt.parse(response.result);
        receipts.set(value.transactionHash, value);
        break;
      }
      case "eth_chainId":
      case "eth_blockNumber": break;
      default: throw new TypeError(`Unexpected canonical observer method ${row.data.request.method}`);
    }
  }
  for (const [hash, transaction] of transactions) {
    const mined = required(receipts.get(hash));
    const header = required(blocks.get(transaction.blockHash));
    assert.equal(header["number"], transaction.blockNumber);
    assert.equal(mined.blockHash, transaction.blockHash);
    assert.equal(mined.blockNumber, transaction.blockNumber);
    assert.equal(mined.transactionIndex, transaction.transactionIndex);
    assert.equal(z.array(z.string()).parse(header["transactions"])[Number(BigInt(transaction.transactionIndex))], hash);
    for (const log of mined.logs) {
      assert.equal(log["transactionHash"], hash);
      assert.equal(log["blockHash"], transaction.blockHash);
      assert.equal(log["blockNumber"], transaction.blockNumber);
      assert.equal(log["transactionIndex"], transaction.transactionIndex);
      assert.equal(log["removed"], false);
    }
  }
  const resumes = [];
  for (const resume of context.signed.resumes) {
    const hash = resume.before.receipt.transactionHash;
    assert.equal(canonical(required(transactions.get(hash))), canonical(resume.before.transaction));
    assert.equal(canonical(required(receipts.get(hash))), canonical(resume.before.receipt));
    assert.equal(canonical(required(receipts.get(hash))), canonical(resume.after.receipt));
    resumes.push({ label: resume.label, hash, nonce: resume.before.intent.nonce,
      fields: Object.keys(resume.before.receipt).sort() });
  }
  const observations = [];
  const sourceCalls = [];
  const failures = [];
  const successes = [];
  for (const line of (await readFile(context.books, "utf8")).trim().split("\n")) {
    const parsed = observed.safeParse(JSON.parse(line));
    if (!parsed.success) continue;
    const row = parsed.data;
    const hash = row.transaction.hash;
    assert.equal(canonical(row.transaction), canonical(required(transactions.get(hash))));
    assert.equal(canonical(row.receipt), canonical(required(receipts.get(hash))));
    const before = required(row.books[0]).values, after = required(row.books[1]).values;
    const n = (values: Record<string, unknown>, key: string) =>
      BigInt(z.array(z.string()).min(1).parse(values[key])[0] ?? "");
    if (row.transaction.to === source) {
      const weight = z.bigint().parse(abi.decodeFunctionData("withdrawClaim", row.transaction.input)[0]);
      const output = n(after, "walletSy") - n(before, "walletSy");
      assert.equal(n(before, "rawWeight") - n(after, "rawWeight"), weight);
      assert.equal(n(before, "rawSupply") - n(after, "rawSupply"), weight);
      const shares = n(before, "sourceShares") - n(after, "sourceShares");
      assert.equal(n(before, "vaultSupply") - n(after, "vaultSupply"), shares);
      assert.equal(n(before, "vaultSy") - n(after, "vaultSy"), output);
      assert.equal(n(before, "sySupply"), n(after, "sySupply"));
      assert.equal(shares, weight * n(before, "sourceShares") / n(before, "rawSupply"));
      assert.equal(output, shares * (n(before, "vaultSy") + 1n) / (n(before, "vaultSupply") + 10000000000n));
      sourceCalls.push({ hash, weight: String(weight), shares: String(shares), output: String(output) });
    } else {
      assert.equal(n(before, "rawWeight"), 7000000000000000000n);
      assert.equal(n(after, "rawWeight"), n(before, "rawWeight"));
      assert.equal(n(before, "rawSupply"), n(after, "rawSupply"));
      if (BigInt(row.receipt.status) === 0n) {
        assert.equal(canonical(before), canonical(after), hash);
        assert.deepEqual(row.receipt.logs, []);
        const frames = flatten(row.trace);
        const args = abi.decodeFunctionData("surrenderMigrationWeightedSy", row.transaction.input);
        const q = z.bigint().parse(args[1]);
        const prior = z.tuple([z.tuple([z.string(), z.string(), z.string(), z.string()])]).parse(before["eligibility"])[0].map(BigInt);
        const Q = required(prior[2]), C = required(prior[3]);
        const credit = q === Q ? C : C * q / Q;
        const funding = new Interface(["function exchangeIn(address,uint256,address,uint256,address,bool,uint256)"])
          .encodeFunctionData("exchangeIn", [row.transaction.to, credit, context.staking, credit, context.bond, false,
            z.number().parse(row.receipt["blockTimestamp"])]);
        const late = frames.some(f => f.to === context.staking && f.input === funding);
        assert(frames.every(f => f.to !== source));
        failures.push({ hash, rawWeightStillConsumed: true, unchangedBooks: true, actualChildFundingReached: late });
      } else {
        const args = abi.decodeFunctionData("surrenderMigrationWeightedSy", row.transaction.input);
        const q = z.bigint().parse(args[1]);
        const prior = z.tuple([z.tuple([z.string(), z.string(), z.string(), z.string()])]).parse(before["eligibility"])[0].map(BigInt);
        const next = z.tuple([z.tuple([z.string(), z.string(), z.string(), z.string()])]).parse(after["eligibility"])[0].map(BigInt);
        const Q = required(prior[2]), C = required(prior[3]);
        const credit = q === Q ? C : C * q / Q;
        assert.deepEqual(next, [required(prior[0]) + q, required(prior[1]) + credit, Q - q, C - credit]);
        assert.equal(n(before, "walletSy") - n(after, "walletSy"), q);
        assert.equal(n(after, "parentSy") - n(before, "parentSy"), q);
        assert.equal(n(after, "inventory") - n(before, "inventory"), q);
        assert.equal(n(before, "allowance") - n(after, "allowance"), q);
        assert.equal(n(after, "newSupply") - n(before, "newSupply"), credit);
        assert.equal(n(after, "newBacking") - n(before, "newBacking"), credit);
        assert.equal(n(after, "walletBonds") - n(before, "walletBonds"), 1n);
        successes.push({ hash, q: String(q), credit: String(credit), before: prior.map(String), after: next.map(String) });
      }
    }
    observations.push(row);
  }
  assert.equal(sourceCalls.length, 6);
  assert.equal(failures.length, 6);
  assert.equal(failures.filter(f => f.actualChildFundingReached).length, 2);
  assert.equal(successes.length, 4);
  assert(sourceCalls.some(c => c.weight === "1" && c.output === "0"));
  return { responses, blocks: blocks.size, transactions: transactions.size, receipts: receipts.size,
    canonicalResumes: resumes, sourceCalls, failures, successes, observations };
}
