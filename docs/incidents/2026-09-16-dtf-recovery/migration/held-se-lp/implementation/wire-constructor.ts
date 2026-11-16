import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { AbiCoder, Interface, Signature, Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { canonical, json, required } from "./evidence.js";
import type { bindings } from "./bindings.js";
import type { receipts } from "./receipts.js";

// Inspected phase19 wire/constructor algorithms, applied to the fresh producer run.
export async function wireAndConstructor(context: {
  readonly runtime: string; readonly wirePath: string;
  readonly bound: Awaited<ReturnType<typeof bindings>>;
  readonly signed: Awaited<ReturnType<typeof receipts>>;
}) {
const { runtime, wirePath, bound, signed } = context;
const wireRow = z.object({
  request: z.object({ method: z.string() }).passthrough(), body: z.string(),
});
const wire = (await readFile(wirePath, "utf8")).trim().split("\n")
  .map(line => wireRow.safeParse(JSON.parse(line))).filter(row => row.success).map(row => row.data);
const object = z.record(z.string(), z.unknown());
const rawReceipts = new Map<string, Record<string, unknown>>();
const rawTransactions = new Map<string, Record<string, unknown>>();
for (const row of wire) {
  const response = z.object({ result: object }).passthrough().safeParse(JSON.parse(row.body));
  if (!response.success) continue;
  const result = response.data.result;
  if (row.request.method === "eth_getTransactionReceipt") {
    rawReceipts.set(z.string().parse(result["transactionHash"]), result);
  }
  if (row.request.method === "eth_getTransactionByHash") {
    rawTransactions.set(z.string().parse(result["hash"]), result);
  }
}
const fieldProof = [];
for (const [hash, raw] of rawTransactions) {
  const type = Number(BigInt(z.string().parse(raw["type"])));
  assert(type === 0 || type === 2);
  const gas = z.string().parse(raw["gas"]);
  const tx = Transaction.from({
    type, to: z.string().nullable().parse(raw["to"]), nonce: Number(BigInt(z.string().parse(raw["nonce"]))),
    gasLimit: BigInt(gas), value: BigInt(z.string().parse(raw["value"])),
    data: z.string().parse(raw["input"]), chainId: BigInt(z.string().parse(raw["chainId"])),
    ...(type === 0 ? { gasPrice: BigInt(z.string().parse(raw["gasPrice"])) } : {
      maxFeePerGas: BigInt(z.string().parse(raw["maxFeePerGas"])),
      maxPriorityFeePerGas: BigInt(z.string().parse(raw["maxPriorityFeePerGas"])),
      accessList: z.array(z.object({ address: z.string(), storageKeys: z.array(z.string()) }))
        .parse(raw["accessList"]),
    }),
    signature: Signature.from({ r: z.string().parse(raw["r"]), s: z.string().parse(raw["s"]),
      v: Number(BigInt(z.string().parse(raw["v"]))) }),
  });
  const impersonated = raw["r"] === "0x1" && raw["s"] === "0x1";
  if (!impersonated) {
    assert.equal(tx.hash, hash);
    assert.equal(tx.from?.toLowerCase(), raw["from"]);
  }
  assert.equal(tx.chainId, 4663n);
  const mined = required(rawReceipts.get(hash));
  assert.equal(mined["blockHash"], raw["blockHash"]);
  assert.equal(mined["transactionIndex"], raw["transactionIndex"]);
  assert.equal(mined["blockNumber"], raw["blockNumber"]);
  fieldProof.push({ hash, signatureReconstruction: impersonated
    ? "Anvil impersonated acquisition/fixture transaction: synthetic r=s=1, no cryptographic signer claim"
    : "canonical RPC fields, not captured raw signing bytes",
    signer: impersonated ? null : tx.from, receiptFields: Object.keys(mined).sort(),
    logs: z.array(z.unknown()).parse(mined["logs"]).length });
}
assert.equal(rawReceipts.size, rawTransactions.size);


const artifact = z.object({ abi: z.array(z.unknown()), bytecode: z.object({ object: z.string() }),
  deployedBytecode: z.object({ immutableReferences: z.record(z.string(),
    z.array(z.object({ start: z.number(), length: z.number() }))) }) }).passthrough()
  .parse(await json(resolve("out/UniswapV4DetfMigrationDFPkg.sol/UniswapV4DetfMigrationDFPkg.json")));
const broadcast = z.object({ transactions: z.array(z.object({
  hash: z.string(), transaction: z.object({ input: z.string() }).passthrough(),
  additionalContracts: z.array(z.object({ address: z.string(), initCode: z.string(),
    contractName: z.string().nullable().optional() }).passthrough()),
}).passthrough()) }).passthrough().parse(await json(resolve(runtime, "environment-mined-transactions.json")));
const creationTx = required(broadcast.transactions.find(tx => tx.additionalContracts
  .some(c => c.address.toLowerCase() === signed.manifest.package)));
const creation = required(creationTx.additionalContracts.find(c => c.address.toLowerCase() === signed.manifest.package));
const bytecode = artifact.bytecode.object.replace(/^0x/, "");
assert(creation.initCode.slice(2).startsWith(bytecode));
const deployment = new Interface(["function deployPkg(bytes initCode,bytes initArgs,bytes32 salt)"]);
const deployedArgs = deployment.decodeFunctionData("deployPkg", creationTx.transaction.input);
assert.equal(deployedArgs[0], `0x${bytecode}`);
assert.equal(`${deployedArgs[0]}${z.string().parse(deployedArgs[1]).slice(2)}`, creation.initCode);
const constructor = new Interface(JSON.stringify(artifact.abi)).deploy;
const decoded = AbiCoder.defaultAbiCoder().decode(constructor.inputs,
  z.string().parse(deployedArgs[1]))[0];
const args = z.object({
  baseInit: z.object({ erc20Facet: z.string(), erc5267Facet: z.string(), erc2612Facet: z.string(),
    multiAssetBasicVaultFacet: z.string(), multiAssetStandardVaultFacet: z.string(),
    productFacets: z.array(z.string()).length(5), feeOracle: z.string(), vaultRegistryDeployment: z.string(),
    bondNftVaultPkg: z.string(), rebasingClaimTokenPkg: z.string(), syPkg: z.string() }),
  ownableFacet: z.string(), migrationFacet: z.string(), allocationFacet: z.string(), recoveryFacet: z.string(),
  claimVaultAllocationFacet: z.string(), rewardTokenPkg: z.string(),
}).parse(decoded.toObject(true));
const base = args.baseInit;
const expected = [base.erc20Facet, base.erc5267Facet, base.erc2612Facet,
  base.multiAssetBasicVaultFacet, base.multiAssetStandardVaultFacet, ...base.productFacets,
  base.feeOracle, base.vaultRegistryDeployment, base.bondNftVaultPkg, base.rebasingClaimTokenPkg,
  base.syPkg, args.ownableFacet, args.migrationFacet, args.allocationFacet, args.recoveryFacet,
  args.claimVaultAllocationFacet, args.rewardTokenPkg, signed.manifest.package];
const code = required(bound.captures.find(c => c.address === signed.manifest.package)).code;
const immutableValues = Object.entries(artifact.deployedBytecode.immutableReferences)
  .sort(([a], [b]) => Number(a) - Number(b)).map(([id, ranges], index) => {
    const value = required(expected[index]).toLowerCase();
    for (const span of ranges) {
      assert.equal(span.length, 20);
      assert.equal(`0x${code.slice(2 + span.start * 2, 2 + (span.start + span.length) * 2)}`, value);
    }
    return { id, value, ranges };
  });
assert.equal(immutableValues.length, expected.length);

const canonicalComparisons = [];
for (const entry of [...signed.signed, ...signed.reconstructed]) {
  const raw = required(rawReceipts.get(required(entry.hash)));
  assert.equal(canonical(raw), canonical(entry.receipt), required(entry.hash));
  canonicalComparisons.push({ hash: entry.hash, comparedFields: Object.keys(raw).sort() });
}
for (const resume of signed.resumes) {
  const raw = required(rawReceipts.get(resume.before.receipt.transactionHash));
  assert.equal(canonical(raw), canonical(resume.before.receipt));
  assert.equal(canonical(raw), canonical(resume.after.receipt));
}
assert.equal(required(rawTransactions.get(creationTx.hash))["input"], creationTx.transaction.input);
return { wire: { responses: wire.length, receipts: rawReceipts.size, transactions: rawTransactions.size, fieldProof },
  constructor: { transactionHash: creationTx.hash, initCodeHash: keccak256(creation.initCode), args, immutableValues },
  canonicalComparisons };
}
