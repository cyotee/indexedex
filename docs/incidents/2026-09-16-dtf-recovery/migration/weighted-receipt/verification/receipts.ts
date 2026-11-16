import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { intent, receipt } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { canonical } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(fileURLToPath(import.meta.url));
const runtime = resolve(z.string().parse(process.argv[2]));
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const fields = ["blockHash", "blockNumber", "blockTimestamp", "contractAddress", "cumulativeGasUsed",
  "effectiveGasPrice", "from", "gasUsed", "logs", "logsBloom", "status", "to",
  "transactionHash", "transactionIndex", "type"].sort();
function checkSigned(raw: string, expected: z.infer<typeof intent>) {
  const tx = Transaction.from(raw);
  assert.equal(tx.hash, expected.transactionHash);
  assert.equal(keccak256(raw), expected.transactionHash);
  assert.equal(tx.chainId, 4663n);
  assert.equal(tx.from?.toLowerCase(), expected.transaction.from.toLowerCase());
  assert.equal(tx.to?.toLowerCase(), expected.transaction.to.toLowerCase());
  assert.equal(tx.nonce.toString(), expected.nonce);
  assert.equal(tx.data, expected.transaction.data);
  assert.equal(tx.value.toString(), expected.transaction.value);
  assert(tx.signature);
  return { hash: tx.hash, signer: tx.from, nonce: tx.nonce, to: tx.to, data: tx.data,
    value: tx.value.toString(), chainId: tx.chainId.toString(), gasLimit: tx.gasLimit.toString(),
    gasPrice: tx.gasPrice?.toString(), signature: tx.signature.serialized };
}
const completions = new Map<string, { readonly intent: z.infer<typeof intent>; readonly receipt: z.infer<typeof receipt> }>();
const signed = [];
for (const directory of (await readdir(runtime)).filter((name) => name.startsWith("journal-")).sort()) {
  for (const file of (await readdir(join(runtime, directory))).filter((name) => name.endsWith(".intent.json")).sort()) {
    const path = join(runtime, directory, file);
    const i = intent.parse(await json(path));
    const result = z.object({ receipt }).passthrough().parse(await json(path.replace(".intent.json", ".receipt.json")));
    assert.deepEqual(Object.keys(result.receipt).sort(), fields, path);
    assert.equal(result.receipt.transactionHash, i.transactionHash);
    assert.equal(BigInt(result.receipt.status), 1n);
    assert.equal(result.receipt.from, i.transaction.from);
    assert.equal(result.receipt.to, i.transaction.to);
    const key = `${i.domainHash}/${i.id}`;
    assert.equal(completions.has(key), false, `duplicate domain operation ${key}`);
    completions.set(key, { intent: i, receipt: result.receipt });
    signed.push({ path, ...checkSigned(i.signedTransaction, i), receipt: result.receipt });
  }
}
const resumes = [];
const rpcTransaction = z.object({
  hash: z.string(), from: z.string(), to: z.string(), nonce: z.string(), input: z.string(),
  value: z.string(), chainId: z.string(), blockHash: z.string(), blockNumber: z.string(),
  gas: z.string(), gasPrice: z.string(), r: z.string(), s: z.string(), v: z.string(),
}).passthrough();
for (const name of ["donation", "issuance", "owner-bond"]) {
  const before = z.object({ completionPresent: z.literal(false), intent, receipt, transaction: rpcTransaction })
    .parse(await json(join(runtime, `${name}-before-resume.json`)));
  const after = completions.get(`${before.intent.domainHash}/${before.intent.id}`);
  assert(after);
  const tx = Transaction.from(before.intent.signedTransaction);
  const decoded = checkSigned(before.intent.signedTransaction, before.intent);
  assert.deepEqual(after.intent, before.intent);
  assert.deepEqual(Object.keys(before.receipt).sort(), fields);
  assert.equal(canonical(before.receipt), canonical(after.receipt));
  assert.equal(BigInt(before.receipt.status), 1n);
  assert.equal(before.transaction.hash, decoded.hash);
  assert.equal(before.transaction.from, decoded.signer?.toLowerCase());
  assert.equal(before.transaction.to, decoded.to?.toLowerCase());
  assert.equal(BigInt(before.transaction.nonce), BigInt(decoded.nonce));
  assert.equal(before.transaction.input, decoded.data);
  assert.equal(BigInt(before.transaction.value), BigInt(decoded.value));
  assert.equal(BigInt(before.transaction.chainId), 4663n);
  assert.equal(BigInt(before.transaction.gas), tx.gasLimit);
  assert.equal(BigInt(before.transaction.gasPrice), tx.gasPrice);
  assert.equal(before.transaction.r, tx.signature?.r);
  assert.equal(before.transaction.s, tx.signature?.s);
  assert.equal(BigInt(before.transaction.v), tx.signature?.networkV);
  assert.equal(before.transaction.blockHash, before.receipt.blockHash);
  assert.equal(before.transaction.blockNumber, before.receipt.blockNumber);
  resumes.push({ name, decoded, fields, before: before.receipt, after: after.receipt });
}
const commands = [];
for (const name of (await readdir(runtime)).filter((name) => name.endsWith(".command.json")).sort()) {
  const record = z.object({ command: z.array(z.string()), code: z.number().nullable(), signal: z.string().nullable() })
    .parse(await json(join(runtime, name)));
  commands.push({ file: name, ...record });
}
const crashes = commands.filter((c) => c.command.includes("--fault-after-mined"));
assert.equal(crashes.length, 3);
for (const c of crashes) { assert.equal(c.code, null); assert.equal(c.signal, "SIGKILL"); }
const wsSigned = [];
for (const name of (await readdir(runtime)).filter((name) => name.startsWith("ws-signed-")).sort()) {
  const row = z.object({ signer: z.string(), nonce: z.number(), raw: z.string(), transactionHash: z.string(),
    to: z.string(), data: z.string(), receipt }).parse(await json(join(runtime, name)));
  const tx = Transaction.from(row.raw);
  assert.equal(tx.hash, row.transactionHash);
  assert.equal(keccak256(row.raw), row.transactionHash);
  assert.equal(tx.chainId, 4663n);
  assert.equal(tx.from?.toLowerCase(), row.signer);
  assert.equal(tx.nonce, row.nonce);
  assert.equal(tx.to?.toLowerCase(), row.to.toLowerCase());
  assert.equal(tx.data, row.data);
  assert.equal(tx.value, 0n);
  assert.deepEqual(Object.keys(row.receipt).sort(), fields);
  assert.equal(row.receipt.transactionHash, row.transactionHash);
  assert.equal(row.receipt.from, row.signer);
  assert.equal(row.receipt.to, row.to.toLowerCase());
  if (BigInt(row.receipt.status) === 0n) assert.equal(row.receipt.logs.length, 0);
  wsSigned.push({ file: name, signer: row.signer, nonce: row.nonce, raw: row.raw, receipt: row.receipt });
}
const fixture = z.array(receipt).parse(await json(join(runtime, "fixture-receipts.json")));
for (const row of fixture) assert.deepEqual(Object.keys(row).sort(), fields);
const pre = z.object({
  local: z.object({ instanceId: z.string(), forkBlockNumber: z.literal("108944663"),
    forkBlockHash: z.literal("0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") }),
}).passthrough().parse(await json(join(runtime, "pre-capture.json")));
await writeFile(join(here, "receipts.json"), JSON.stringify({
  runtime, local: pre.local, signed, resumes, commands, wsSigned, fixtureReceipts: fixture.length,
  wsFailed: wsSigned.filter((row) => BigInt(row.receipt.status) === 0n).length,
}, null, 2) + "\n", { flag: "wx" });
console.log(`RECEIPTS_CONFIRMED journals=${signed.length} resumes=${resumes.length} signedWS=${wsSigned.length}`);
