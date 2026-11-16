import { readFile, readdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface, Transaction, HDNodeWallet, keccak256 } from "ethers";
import { z } from "zod";
import { intent, completion, receipt, ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { canonical, fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { interfaceFile, save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const here = dirname(fileURLToPath(import.meta.url));
const run = z.string().parse(process.argv[2]);
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
function requireProof(value: boolean, message: string): asserts value {
  if (!value) throw new ExecutionError("STATE", message);
}
const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
const erc = new Interface([
  "event Transfer(address indexed from,address indexed to,uint256 amount)",
  "event Deposit(address indexed sender,address indexed owner,uint256 assets,uint256 shares)",
  "event Withdraw(address indexed sender,address indexed receiver,address indexed owner,uint256 assets,uint256 shares)",
  "event DiamondFunctionRemoved(bytes4 indexed selector,address indexed oldFacet)",
  "event DiamondFunctionAdded(bytes4 indexed selector,address indexed newFacet)",
]);
const nft = new Interface(["event Transfer(address indexed from,address indexed to,uint256 indexed tokenId)"]);
const interfaces = [migration, allocation, recovery, erc, nft];
const decode = (mined: z.infer<typeof receipt>) => mined.logs.flatMap((log) => {
  for (const abi of interfaces) {
    const event = abi.getEvent(log.topics[0] ?? "");
    if (!event || event.inputs.filter((input) => input.indexed).length + 1 !== log.topics.length) continue;
    const decoded = abi.parseLog({ topics: [...log.topics], data: log.data });
    if (decoded) return [{ address: log.address, name: decoded.name, values: decoded.args.toArray().map(String) }];
  }
  return [];
});
const journals = (await readdir(run)).filter((name) => name.startsWith("journal-"));
const completions = [];
for (const directory of journals) {
  for (const name of await readdir(join(run, directory))) {
    if (!name.endsWith(".receipt.json")) continue;
    const done = completion.parse(await json(join(run, directory, name)));
    const record = intent.parse(await json(join(run, directory, name.replace(".receipt.json", ".intent.json"))));
    const signed = Transaction.from(record.signedTransaction);
    requireProof(signed.isSigned() && signed.from?.toLowerCase() === record.transaction.from
      && signed.hash === record.transactionHash && signed.chainId === 4663n
      && signed.nonce.toString() === record.nonce && signed.to?.toLowerCase() === record.transaction.to
      && signed.data === record.transaction.data && signed.value.toString() === record.transaction.value,
    `signed journal mismatch: ${directory}/${name}`);
    requireProof(done.intentHash === fingerprint(canonical(record))
      && done.receipt.transactionHash === signed.hash && BigInt(done.receipt.status) === 1n,
    `completion binding mismatch: ${directory}/${name}`);
    completions.push({ directory, name, record, done, events: decode(done.receipt) });
  }
}
const resumes = [];
for (const label of ["donation", "issuance", "owner-bond"]) {
  const before = z.object({ intent, receipt, transaction: z.record(z.string(), z.unknown()),
    completionPresent: z.literal(false) }).parse(await json(join(run, `${label}-before-resume.json`)));
  const matched = completions.filter((entry) => entry.record.id === before.intent.id);
  requireProof(matched.length === 1 && matched[0] !== undefined, `${label}: missing unique completion`);
  const after = matched[0];
  requireProof(canonical(before.intent) === canonical(after.record)
    && canonical(before.receipt) === canonical(after.done.receipt), `${label}: canonical raw receipt changed`);
  const signed = Transaction.from(before.intent.signedTransaction);
  requireProof(before.transaction["hash"] === signed.hash
    && before.transaction["from"] === signed.from?.toLowerCase()
    && BigInt(z.string().parse(before.transaction["nonce"])) === BigInt(signed.nonce)
    && before.transaction["input"] === signed.data, `${label}: canonical transaction differs`);
  resumes.push({ label, hash: signed.hash, signer: signed.from, nonce: signed.nonce,
    method: before.intent.method, selector: signed.data.slice(0, 10),
    receiptFieldsCompared: Object.keys(before.receipt), rawReceiptEqual: true,
    signatureVerified: true, events: after.events, journal: `${after.directory}/${after.name}` });
}
const activation = completions.find((entry) => entry.record.method === "activateMigration");
requireProof(activation !== undefined, "missing actual activation");
const expected = allocation.fragments.filter((fragment) => fragment.type === "function").map((fragment) => {
  const fn = allocation.getFunction(fragment.format("sighash"));
  requireProof(fn !== null, "missing allocation function");
  return { name: fn.name, selector: fn.selector };
});
const removed = activation.events.filter((event) => event.name === "DiamondFunctionRemoved");
requireProof(expected.length === 10 && removed.length === 10
  && canonical(expected.map((entry) => entry.selector).sort())
    === canonical(removed.map((entry) => entry.values[0]).sort()), "wrong actual ten-selector removal set");
const deployment = completions.find((entry) => entry.record.stage === "deploy");
requireProof(deployment !== undefined, "missing actual parent deployment");
const gas = z.object({ gasUsed: z.string() }).passthrough().parse(deployment.done.receipt);
const fixtures = z.array(receipt).parse(await json(join(run, "fixture-receipts.json")));
const economics = [];
for (const phase of ["stage1", "partial", "final"]) {
  const record = z.object({ observations: z.array(z.record(z.string(), z.unknown())),
    syntheticOriginalAllocation: z.record(z.string(), z.unknown()), originalCredit: z.string() })
    .parse(await json(join(run, `claim-vault-${phase}.json`)));
  const linked = [];
  for (const item of record.observations) {
    for (const [key, value] of Object.entries(item)) {
      if (!key.toLowerCase().includes("transaction") && !["minimumFailure", "batchFailure", "laterFailure"].includes(key)) continue;
      const txHash = z.string().parse(value);
      const mined = fixtures.find((entry) => entry.transactionHash === txHash);
      requireProof(mined !== undefined, `missing fixture receipt ${txHash}`);
      if (item["kind"] === "rejection" || item["kind"] === "removed-loader" || key.endsWith("Failure")) {
        requireProof(BigInt(mined.status) === 0n && mined.logs.length === 0, "negative has economic logs");
      } else requireProof(BigInt(mined.status) === 1n, "positive receipt failed");
      linked.push({ key, hash: txHash, status: mined.status, events: decode(mined) });
    }
  }
  economics.push({ phase, originalCredit: record.originalCredit, original: record.syntheticOriginalAllocation,
    observations: record.observations.map(({ trace: _trace, ...rest }) => rest), linked });
}
const acquisition = z.object({ originalWallet: z.string(), transactions: z.array(z.object({
  transactionHash: z.string(), nonce: z.number(), to: z.string(), data: z.string(), receipt,
})) }).passthrough().parse(await json(join(run, "claim-vault-acquisition.json")));
const wallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/105");
const acquired = [];
for (const item of acquisition.transactions) {
  const raw = await wallet.signTransaction({ to: item.to, data: item.data, nonce: item.nonce, chainId: 4663,
    gasLimit: 2000000n, gasPrice: BigInt(z.object({ effectiveGasPrice: z.string() }).passthrough().parse(item.receipt).effectiveGasPrice), type: 0 });
  const signed = Transaction.from(raw);
  requireProof(keccak256(raw) === item.transactionHash && signed.from?.toLowerCase() === acquisition.originalWallet,
    "controlled acquisition signature/hash differs");
  acquired.push({ hash: signed.hash, signer: signed.from, nonce: signed.nonce, raw, events: decode(item.receipt) });
}
const route = [];
for (const name of (await readdir(join(here, "route-proof"))).filter((name) => /^route-tx-\d+\.json$/.test(name))) {
  const item = z.object({ raw: z.string(), data: z.string(), receipt,
    before: z.record(z.string(), z.string()), after: z.record(z.string(), z.string()),
    trace: z.object({ output: z.string().optional() }).passthrough() })
    .passthrough().parse(await json(join(here, "route-proof", name)));
  const signed = Transaction.from(item.raw);
  requireProof(signed.hash === item.receipt.transactionHash && signed.from?.toLowerCase() === acquisition.originalWallet
    && signed.chainId === 4663n && signed.data === item.data, "isolated route signature mismatch");
  if (BigInt(item.receipt.status) === 0n) requireProof(canonical(item.before) === canonical(item.after)
    && item.receipt.logs.length === 0, "route rollback differs");
  route.push({ file: name, hash: signed.hash, signer: signed.from, nonce: signed.nonce,
    status: item.receipt.status, before: item.before, after: item.after, output: item.trace.output,
    events: decode(item.receipt) });
}
await save(join(here, "receipt-audit.json"), {
  run, verifiedSignedCompletions: completions.length, resumes, activation: {
    hash: activation.done.receipt.transactionHash, expected, removed,
  }, deployment: { hash: deployment.done.receipt.transactionHash, gasUsed: BigInt(gas.gasUsed).toString(),
    limitation: "Actual current permissive-local receipt only; no gas experiment or target-feasibility acceptance" },
  acquired, route, economics, fixtureReceipts: fixtures.length,
  limits: ["Synthetic originals are not operational awards", "No exact historical source/bytecode equivalence asserted"],
});
console.log(JSON.stringify({ signedCompletions: completions.length, resumes: resumes.length,
  removed: removed.length, parentGas: BigInt(gas.gasUsed).toString(), status: "receipt-audit-complete" }));
