import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Transaction } from "ethers";
import { z } from "zod";
import { fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const root = dirname(fileURLToPath(import.meta.url));
const json = async (file: string): Promise<unknown> => JSON.parse(await readFile(join(root, file), "utf8"));
const sampleSchema = z.object({ method: z.string(), stage: z.string().optional(), selected: z.number(),
  unrelated: z.number(), originalsPerRecipient: z.array(z.number()).optional(),
  estimate: z.string(), signedLimit: z.string(), gasUsed: z.string(), transactionHash: z.string() }).passthrough();
const samples = z.array(sampleSchema).parse(await json("signed-envelopes/operation-gas.json"));
const constrained = z.array(z.object({ method: z.string(), parent: z.string(), envelope: z.string(),
  gasUsed: z.string(), transactionHash: z.string() }).passthrough()).parse(await json("signed-envelopes/constrained-receipts.json"));
assert.equal(constrained.length, 4);
assert.equal(new Set(constrained.map((row) => row.parent)).size, 2);
assert.ok(constrained.every((row) => row.envelope === "32000000"));
const signedLog = await readFile(join(root, "attempt-signed-final/raw.log"), "utf8");
for (const sample of samples) {
  assert.ok(BigInt(sample.estimate) <= 32_000_000n);
  assert.equal(sample.signedLimit, "32000000");
  assert.ok(signedLog.split("\n").some((line) => line.includes(sample.transactionHash)
    && line.includes(`"gasUsed":"${sample.gasUsed}"`) && line.includes(`"estimate":"${sample.estimate}"`)),
  `sample missing from raw log: ${sample.transactionHash}`);
}
const signed = z.array(z.object({ transactionHash: z.string(), rawSignedTransaction: z.string() }).passthrough())
  .parse(await json("signed-envelopes/transactions.json"));
for (const row of signed) {
  const transaction = Transaction.from(row.rawSignedTransaction);
  assert.equal(transaction.hash, row.transactionHash);
  assert.equal(transaction.gasLimit, 32_000_000n);
}
const baseline = z.object({ sources: z.record(z.string(), z.string()) }).passthrough()
  .parse(await json("attempt-forge-1/commands.json"));
const permitted = new Set([
  "scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol",
  "docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts",
  "scripts/recovery/dtf-migration/execution.test.ts",
]);
const changed: string[] = [];
for (const [file, expected] of Object.entries(baseline.sources)) {
  if (fingerprint(await readFile(file)) !== expected) {
    changed.push(file);
    assert.ok(permitted.has(file), `unrelated source changed: ${file}`);
  }
}
const commands = [];
for (const name of (await readdir(root)).filter((name) => name.startsWith("attempt-")).sort()) {
  if (!(await readdir(join(root, name))).includes("commands.json")) {
    assert.match(name, /^attempt-audit-[0-9]+$/);
    continue; // This runner's command receipt is emitted after its child exits.
  }
  commands.push(await json(`${name}/commands.json`));
}
const negatives = z.object({
  boundary: z.object({ rejected: z.literal(true), nonceBefore: z.unknown(), nonceAfter: z.unknown() }).passthrough(),
  underfunded: z.object({ allConfigurationsRolledBack: z.literal(true), beforeHash: z.string(), afterHash: z.string() }).passthrough(),
  savedIntent: z.object({ rejected: z.literal(true), nonceBefore: z.unknown(), nonceAfter: z.unknown() }).passthrough(),
}).passthrough().parse(await json("gas-negatives.json"));
assert.deepEqual(negatives.boundary.nonceBefore, negatives.boundary.nonceAfter);
assert.deepEqual(negatives.savedIntent.nonceBefore, negatives.savedIntent.nonceAfter);
assert.equal(negatives.underfunded.beforeHash, negatives.underfunded.afterHash);
const operations = samples.filter((sample) => sample.originalsPerRecipient);
for (const size of [1, 8, 16, 32, 64]) {
  assert.ok(operations.some((sample) => sample.method === "configureIndependentAllocations" && sample.selected === size));
  assert.ok(operations.some((sample) => sample.selected === 1 && sample.originalsPerRecipient?.[0] === size));
}
assert.ok(operations.some((sample) => sample.method === "issueIndependentAllocations" && sample.selected === 32));
const recovery = samples.filter((sample) => sample.method === "recoverMigrationNfts");
assert.equal(recovery.length, 5);
for (const selected of [1, 8]) assert.equal(recovery.filter((sample) =>
  sample.stage === "WeightedClaim" && sample.selected === selected).length, 2);
const policyRawPath = "docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/implementation/chain-gas-limits.log";
const policyRaw = await readFile(policyRawPath);
const table = samples.map((sample) => `| ${sample.method}${sample.stage ? `/${sample.stage}` : ""} | ${sample.selected} | ${sample.originalsPerRecipient?.join(",") ?? "-"} | ${sample.unrelated} | ${sample.estimate} | ${sample.signedLimit} | ${sample.gasUsed} | ${sample.transactionHash} |`).join("\n");
const report = `# Task 11 batch limits

Gas-only evidence for current bytecode, chain 4663, historical block 108944663
(0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733).
The authenticated transaction limit is 32,000,000; the recorded header limit
is 0x4000000000000, so the applicable minimum is 32,000,000. The local 100m
block setting is never the admission policy. The retained raw policy log is
\`${policyRawPath}\`, SHA-256 \`${fingerprint(policyRaw)}\`.
\`signed-envelopes/source-manifest.json\` binds its historical diagnosis record.

Largest tested admitted shapes: loading 64 recipients with one whole original
each; independent issuance 32 recipients with one whole original each; one
recipient with 64 whole originals for loading and issuance. These axes do not
admit their Cartesian product or arbitrary calldata. The 3/2 estimate envelope
for each admitted sample fits the ceiling. Existing operator operations select
one complete recipient, so no production signing/resume mismatch was exposed
and no global signing-policy change was made. Regroup only between complete
records; never split or merge an economic original. The Foundry 64-recipient
issuance is measured above the limit, and its actual capped local simulation
rejects before signing/sending with unchanged nonce.

Recovery admits up to eight WeightedClaim stages or one other typed step.
The signed samples cover one and eight at custody populations 8 and 24, plus
one WeightedUnstake. Recovery samples are independent local snapshot branches:
each receipt was checked canonical at capture, then the branch was reverted
to preserve identical selected source state. They are historical experiment
receipts, not simultaneously surviving final-chain receipts. The existing
fork gas suite separately asserts selected cost is independent of 24 unrelated
surrenders. Holder transfers/approvals/surrenders are fixture setup, not admitted
gas samples; their permissive envelopes do not establish target feasibility.

Two distinct owners/parents retain two-step preparation/publication and four
signed 32m construction receipts. Historical preparations 19,746,568/19,595,700
and publications 29,905,302/29,344,006 remain historical-source observations;
the new table/receipt files carry current measurements. No obsolete
44,353,454 number is substituted.

Every number below occurs in \`attempt-signed-final/raw.log\`; receipts and signed
bytes are in \`signed-envelopes/{transactions,constrained-receipts,operation-gas}.json\`.
Accepting command argv and exit codes are in each attempt's raw.log/commands.json.
Earlier failed attempts remain recorded and are not successful measurements.

| Operation | Selected | Originals per recipient | Unrelated configured/custody population | Estimate | Signed gas | Actual gasUsed | Transaction |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
${table}

Task 10's 10,000 DTF donor/bundle blocker remains open. These isolated gas
experiments do not certify its missing mixed-book, NFT 3 or lifecycle rehearsal.
No claimed-SY witness pin was retuned. No public transaction or commit was made.
`;
await writeFile(join(root, "batch-limits.md"), report, { flag: "wx" });
await writeFile(join(root, "commands.json"), JSON.stringify({ attempts: commands }, null, 2), { flag: "wx" });
await writeFile(join(root, "source-audit.json"), JSON.stringify({
  baseline: "attempt-forge-1/commands.json", changedExistingFiles: changed,
  preservedBaselineSources: Object.keys(baseline.sources).length - changed.length,
  signedTransactions: signed.length, samples: samples.length, constructions: constrained,
  protected: ["scripts/recovery/dtf-migration/rehearsal-proof.ts", "scripts/recovery/dtf-migration/rehearsal-claimed-sy-witness.ts"],
}, null, 2), { flag: "wx" });
console.log("TASK_11_EVIDENCE_AUDIT_PASS", JSON.stringify({ signed: signed.length, samples: samples.length }));
