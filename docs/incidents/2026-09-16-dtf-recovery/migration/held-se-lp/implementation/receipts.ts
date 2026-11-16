// Adapted read-only from accepted phase19 evidence; original files remain unchanged.
import assert from "node:assert/strict";
import { dirname, resolve } from "node:path";
import { HDNodeWallet, Interface, Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { address, canonical, files, hash, hex, json, required, sha, uint } from "./evidence.js";

// Own receipt verifier: raw RPC signature r/s are quantities, not even-byte hex.
const quantity = z.string().regex(/^0x[0-9a-f]+$/i);
const log = z.object({
  address, topics: z.array(hash), data: hex, logIndex: quantity,
}).passthrough();
export const receipt = z.object({
  blockHash: hash, blockNumber: quantity, blockTimestamp: z.number(),
  contractAddress: address.nullable(), cumulativeGasUsed: quantity, effectiveGasPrice: quantity,
  from: address, gasUsed: quantity, logs: z.array(log), logsBloom: hex, status: quantity,
  to: address.nullable(), transactionHash: hash, transactionIndex: quantity, type: quantity,
}).passthrough();
const intent = z.object({
  domainHash: z.string(), id: z.string(), nonce: uint, method: z.string(),
  signedTransaction: hex, transactionHash: hash,
  transaction: z.object({ from: address, to: address, data: hex, value: uint }),
}).passthrough();
const completion = z.object({
  intentHash: z.string(), receipt, state: z.record(z.string(), z.string()),
}).passthrough();

export async function receipts(runtime: string) {
  const names = await files(runtime);
  const signed = [];
  const completions: { readonly path: string; readonly intent: unknown;
    readonly completion: z.infer<typeof completion> }[] = [];
  for (const path of names.filter(p => p.endsWith(".intent.json"))) {
    const raw = await json(path);
    const record = intent.parse(raw);
    const tx = Transaction.from(record.signedTransaction);
    const done = completion.parse(await json(path.replace(".intent.json", ".receipt.json")));
    assert.equal(tx.hash, record.transactionHash);
    assert.equal(tx.hash, keccak256(record.signedTransaction));
    assert.equal(tx.chainId, 4663n);
    assert.equal(tx.from?.toLowerCase(), record.transaction.from.toLowerCase());
    assert.equal(tx.to?.toLowerCase(), record.transaction.to.toLowerCase());
    assert.equal(tx.data, record.transaction.data);
    assert.equal(tx.value, BigInt(record.transaction.value));
    assert.equal(BigInt(tx.nonce), BigInt(record.nonce));
    assert.equal(done.intentHash, sha(canonical(raw)));
    assert.equal(done.receipt.transactionHash, tx.hash);
    assert.equal(done.receipt.from, tx.from?.toLowerCase());
    assert.equal(done.receipt.to, tx.to?.toLowerCase());
    assert.equal(BigInt(done.receipt.status), 1n);
    assert(BigInt(done.receipt.gasUsed) > 0n && BigInt(done.receipt.gasUsed) <= tx.gasLimit);
    completions.push({ path, intent: raw, completion: done });
    signed.push({ path, hash: tx.hash, signer: tx.from, nonce: tx.nonce, to: tx.to,
      value: tx.value, data: tx.data, raw: record.signedTransaction, receipt: done.receipt });
  }
  const wallet = z.object({
    raw: hex, transactionHash: hash, to: address, data: hex, nonce: z.number(),
    from: address.optional(), signer: address.optional(), receipt,
  }).passthrough();
  for (const path of names.filter(p => /(?:ed|er|ws|held)-signed-[^/]+\.json$/.test(p))) {
    const entry = wallet.parse(await json(path));
    const tx = Transaction.from(entry.raw);
    assert.equal(tx.hash, entry.transactionHash);
    assert.equal(tx.hash, keccak256(entry.raw));
    assert.equal(tx.from?.toLowerCase(), (entry.from ?? entry.signer)?.toLowerCase());
    assert.equal(tx.to?.toLowerCase(), entry.to.toLowerCase());
    assert.equal(tx.data, entry.data);
    assert.equal(tx.chainId, 4663n);
    assert.equal(tx.nonce, entry.nonce);
    assert.equal(entry.receipt.transactionHash, tx.hash);
    assert.equal(entry.receipt.from, tx.from?.toLowerCase());
    assert.equal(entry.receipt.to, tx.to?.toLowerCase());
    assert(BigInt(entry.receipt.gasUsed) > 0n && BigInt(entry.receipt.gasUsed) <= tx.gasLimit);
    signed.push({ path, hash: tx.hash, signer: tx.from, nonce: tx.nonce, to: tx.to,
      value: tx.value, data: tx.data, raw: entry.raw, receipt: entry.receipt });
  }
  const reconstructed = [];
  for (const name of ["claim-vault-acquisition.json", "dtf-custody-se-acquisition.json"]) {
    const acquisition = z.object({
      originalWallet: address, derivationIndex: z.number(), transactions: z.array(z.object({
        transactionHash: hash, to: address, data: hex, nonce: z.number(), receipt,
      })),
    }).passthrough().parse(await json(resolve(runtime, name)));
    const signer = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
      undefined, `m/44'/60'/0'/0/${acquisition.derivationIndex}`);
    assert.equal(signer.address.toLowerCase(), acquisition.originalWallet);
    for (const entry of acquisition.transactions) {
      const raw = await signer.signTransaction({ to: entry.to, data: entry.data, nonce: entry.nonce,
        chainId: 4663n, gasLimit: 2000000n, gasPrice: BigInt(entry.receipt.effectiveGasPrice), type: 0 });
      const tx = Transaction.from(raw);
      assert.equal(tx.hash, entry.transactionHash);
      assert.equal(tx.hash, entry.receipt.transactionHash);
      assert.equal(tx.from?.toLowerCase(), entry.receipt.from);
      assert.equal(tx.to?.toLowerCase(), entry.receipt.to);
      reconstructed.push({ path: resolve(runtime, name), raw, hash: tx.hash, signer: tx.from, nonce: tx.nonce,
        receipt: entry.receipt, origin: "offline deterministic reconstruction; not original signing capture" });
    }
  }
  const resumes = [];
  for (const [label, directory] of [["donation", "journal-fund"], ["issuance", "journal-issue"], ["owner-bond", "journal-owner-bond"]]) {
    const before = z.object({
      completionPresent: z.literal(false), intent, receipt,
      transaction: z.object({
        hash, nonce: quantity, gas: quantity, gasPrice: quantity, r: quantity, s: quantity, v: quantity,
      }).passthrough(),
    }).passthrough().parse(await json(resolve(runtime, `${label}-before-resume.json`)));
    const after = completion.parse(await json(resolve(runtime, required(directory), `${before.intent.id}.receipt.json`)));
    const tx = Transaction.from(before.intent.signedTransaction);
    assert.equal(tx.hash, before.transaction.hash);
    assert.equal(tx.hash, before.receipt.transactionHash);
    assert.equal(BigInt(tx.nonce), BigInt(before.transaction.nonce));
    assert.equal(tx.gasLimit, BigInt(before.transaction.gas));
    assert.equal(tx.gasPrice, BigInt(before.transaction.gasPrice));
    assert.equal(BigInt(required(tx.signature).r), BigInt(before.transaction.r));
    assert.equal(BigInt(required(tx.signature).s), BigInt(before.transaction.s));
    assert.equal(required(tx.signature).networkV, BigInt(before.transaction.v));
    assert.deepEqual(before.receipt, after.receipt);
    assert.equal(completions.filter(c => dirname(c.path) === resolve(runtime, required(directory))
      && intent.parse(c.intent).transactionHash === tx.hash).length, 1);
    resumes.push({ label, before, after, comparedFields: Object.keys(before.receipt), raw: tx.serialized });
  }
  const manifest = z.object({ proxy: address, registry: address, package: address }).passthrough()
    .parse(await json(resolve(runtime, "post-capture.json")));
  const registry = new Interface(["event NewVault(address indexed vault,address indexed package,bytes32 vaultFeeIds,bytes32 indexed contentsId,bytes4[] vaultTypes,address[] tokens)"]);
  const deployment = required(completions.find(c => c.path.includes("/journal-deploy/")));
  assert(deployment.completion.receipt.logs.filter(l => l.address === manifest.registry)
    .map(l => registry.parseLog({ topics: [...l.topics], data: l.data }))
    .some(l => l?.name === "NewVault" && l.args[0].toLowerCase() === manifest.proxy
      && l.args[1].toLowerCase() === manifest.package));
  const nonceKeys = new Map<string, string>();
  for (const entry of signed) {
    const key = `${entry.signer}:${entry.nonce}`;
    const prior = nonceKeys.get(key);
    if (prior) assert.equal(prior, entry.hash);
    nonceKeys.set(key, required(entry.hash ?? undefined));
  }
  return { manifest, registrationReceipt: deployment.completion.receipt, signed, reconstructed, completions, resumes };
}
