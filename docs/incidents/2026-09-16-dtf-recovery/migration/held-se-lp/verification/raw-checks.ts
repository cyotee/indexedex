import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { Interface, Transaction } from "ethers";
import { z } from "zod";
import { canonical, json, required } from "../implementation/evidence.js";
import type { heldEconomics } from "../implementation/held-economics.js";
import type { receipts } from "../implementation/receipts.js";

const object = z.record(z.string(), z.unknown());
const quantity = z.string().regex(/^0x[0-9a-f]+$/i);
const wireRow = z.object({
  request: z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()) }),
  body: z.string(),
});
const response = z.object({ id: z.number(), jsonrpc: z.literal("2.0"), result: z.unknown() });
const account = z.object({
  storage: z.record(z.string(), quantity).default({}),
  code: z.string().optional(),
}).passthrough();
const diff = z.object({ pre: z.record(z.string(), account), post: z.record(z.string(), account) });

/** Independent additions to the inspected producer reconcilers; reads only. */
export async function rawChecks(context: {
  readonly runtime: string;
  readonly wirePath: string;
  readonly signed: Awaited<ReturnType<typeof receipts>>;
  readonly held: Awaited<ReturnType<typeof heldEconomics>>;
}) {
  const { runtime, signed, held } = context;
  const transactions = new Map<string, Record<string, unknown>>();
  const receiptsByHash = new Map<string, Record<string, unknown>>();
  const blocks = new Map<string, Record<string, unknown>>();
  let responses = 0;
  let lastId = 0;
  for (const line of (await readFile(context.wirePath, "utf8")).trim().split("\n")) {
    const parsed: unknown = JSON.parse(line);
    const row = wireRow.safeParse(parsed);
    if (!row.success) {
      z.object({ status: z.literal("producer-capture-closed"), blocks: z.number() }).parse(parsed);
      continue;
    }
    const reply = response.parse(JSON.parse(row.data.body));
    assert.equal(reply.id, row.data.request.id);
    assert(reply.id > lastId);
    lastId = reply.id;
    responses++;
    const method = row.data.request.method;
    if (method === "eth_getBlockByNumber") {
      const value = object.parse(reply.result);
      blocks.set(z.string().parse(value["hash"]), value);
    } else if (method === "eth_getTransactionByHash") {
      const value = object.parse(reply.result);
      assert.equal(value["hash"], row.data.request.params[0]);
      transactions.set(z.string().parse(value["hash"]), value);
    } else if (method === "eth_getTransactionReceipt") {
      const value = object.parse(reply.result);
      assert.equal(value["transactionHash"], row.data.request.params[0]);
      receiptsByHash.set(z.string().parse(value["transactionHash"]), value);
    }
  }
  assert(transactions.size > 600);
  for (const [hash, tx] of transactions) {
    const mined = required(receiptsByHash.get(hash));
    const block = required(blocks.get(z.string().parse(tx["blockHash"])));
    assert.equal(tx["blockNumber"], block["number"]);
    assert.equal(mined["blockHash"], tx["blockHash"]);
    assert.equal(mined["blockNumber"], tx["blockNumber"]);
    assert.equal(mined["transactionIndex"], tx["transactionIndex"]);
    assert.equal(mined["from"], tx["from"]);
    assert.equal(mined["to"], tx["to"]);
    assert.equal(BigInt(z.number().int().parse(mined["blockTimestamp"])),
      BigInt(z.string().parse(block["timestamp"])));
    assert(z.array(z.string()).parse(block["transactions"]).includes(hash));
    for (const log of z.array(object).parse(mined["logs"])) {
      assert.equal(log["transactionHash"], hash);
      assert.equal(log["transactionIndex"], tx["transactionIndex"]);
      assert.equal(log["blockHash"], tx["blockHash"]);
      assert.equal(log["blockNumber"], tx["blockNumber"]);
      assert.equal(log["removed"], false);
    }
  }
  const donorProofs = [];
  for (const row of held.acquisition.rows) {
    for (const operation of [row.release, row.donation]) {
      if (!operation) continue;
      const hash = operation.transaction.hash;
      assert.equal(canonical(operation.transaction), canonical(required(transactions.get(hash))));
      assert.equal(canonical(operation.receipt), canonical(required(receiptsByHash.get(hash))));
      assert.equal(BigInt(operation.transaction.r), 1n);
      assert.equal(BigInt(operation.transaction.s), 1n);
      assert.match(operation.provenance, /impersonated/);
    }
    if (!row.release) continue;
    const delta = diff.parse(row.release.stateDiff);
    const before = required(delta.pre[row.source]);
    const after = required(delta.post[row.source]);
    const slots = [...new Set([...Object.keys(before.storage), ...Object.keys(after.storage)])];
    const amounts = slots.map(slot => BigInt(after.storage[slot] ?? "0x0") - BigInt(before.storage[slot] ?? "0x0"));
    assert.deepEqual(amounts.map(String).sort(), ["-10020", "10020"]);
    for (const [address, value] of Object.entries(delta.post)) {
      assert.equal(value.code, undefined);
      if (address !== row.source) assert.deepEqual(value.storage, {});
    }
    assert.equal(delta.post[held.acquisition.beforeAuthority.collector], undefined);
    donorProofs.push({ source: row.source, hash: row.release.transaction.hash, slots, amounts, diff: delta });
  }
  const canonicalResumes = [];
  for (const resume of signed.resumes) {
    const hash = resume.before.receipt.transactionHash;
    const transaction = required(transactions.get(hash));
    const mined = required(receiptsByHash.get(hash));
    assert.equal(canonical(transaction), canonical(resume.before.transaction));
    assert.equal(canonical(mined), canonical(resume.before.receipt));
    assert.equal(canonical(mined), canonical(resume.after.receipt));
    canonicalResumes.push({ operation: resume.label, hash, transaction, before: resume.before,
      after: resume.after, rawReceipt: mined, fields: Object.keys(mined).sort() });
  }
  const migrationArtifact = z.object({ abi: z.array(z.unknown()) }).passthrough().parse(
    await json(resolve("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json")));
  const migration = new Interface(JSON.stringify(migrationArtifact.abi));
  const transfer = new Interface(["event Approval(address indexed owner,address indexed spender,uint256 amount)"]);
  const recurrences = [];
  for (const configured of held.configuredRows) {
    let Q = BigInt(configured.configuration.input.originalUnits);
    let C = BigInt(configured.configuration.quotedCredit);
    let delivered = 0n;
    const rows = [];
    for (const observation of configured.rows) {
      const signedRow = required(signed.signed.find(row => row.hash === observation.transactionHash));
      const actual = Transaction.from(signedRow.raw);
      const args = migration.decodeFunctionData("surrenderMigrationHeldSeLp", actual.data);
      const q = z.bigint().parse(args[1]);
      const credit = q === Q ? C : C * q / Q;
      assert(q > 0n && q <= Q && credit > 0n);
      assert.equal(actual.from?.toLowerCase(), configured.configuration.input.originalWallet);
      assert.notEqual(actual.signature?.r, "0x" + "0".repeat(63) + "1");
      assert.equal(BigInt(observation.credit), credit);
      const remainingAllowance = Q === BigInt(configured.configuration.input.originalUnits)
        ? BigInt(configured.configuration.input.originalUnits) - q : 2n ** 256n - 1n - q;
      const approvals = signedRow.receipt.logs.filter(log => log.address === configured.configuration.input.source)
        .map(log => transfer.parseLog(log)).filter(log => log?.name === "Approval");
      assert(approvals.some(log => log?.args[0].toLowerCase() === actual.from?.toLowerCase()
        && log?.args[1].toLowerCase() === signed.manifest.proxy && log?.args[2] === remainingAllowance));
      rows.push({ hash: actual.hash, Q, C, q, credit, remainingAllowance,
        canonicalReceipt: required(receiptsByHash.get(observation.transactionHash)) });
      Q -= q; C -= credit; delivered += credit;
    }
    assert.equal(Q, 0n); assert.equal(C, 0n);
    assert.equal(delivered, BigInt(configured.configuration.quotedCredit));
    recurrences.push({ source: configured.configuration.input.source, delivered, rows });
  }
  const deployment = required(signed.signed.find(row => row.path.includes("/journal-deploy/")));
  const pkgArtifact = z.object({ abi: z.array(z.unknown()) }).passthrough().parse(
    await json(resolve("out/UniswapV4DetfMigrationDFPkg.sol/UniswapV4DetfMigrationDFPkg.json")));
  const pkg = new Interface(JSON.stringify(pkgArtifact.abi));
  assert.equal(deployment.to?.toLowerCase(), signed.manifest.package);
  const proxyArgs = pkg.decodeFunctionData("deployVault", deployment.data)[0].toObject(true);
  const manifest = object.parse(await json(resolve(runtime, "pre-capture.json")));
  const deploymentInputs = object.parse(manifest["deployment"]);
  // Result.toObject(true) represents empty ABI arrays as {}, so compare the
  // complete canonical ABI encoding instead of that lossy display conversion.
  assert.equal(pkg.encodeFunctionData("deployVault", [deploymentInputs]), deployment.data);
  return { responses, blocks: blocks.size, transactions: transactions.size, receipts: receiptsByHash.size,
    donorProofs, canonicalResumes, recurrences, deployment: {
      raw: deployment.raw, hash: deployment.hash, package: signed.manifest.package,
      proxy: signed.manifest.proxy, registry: signed.manifest.registry,
      decodedDisplay: proxyArgs, exactArguments: deploymentInputs, calldata: deployment.data,
    } };
}
