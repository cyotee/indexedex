import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readFile, writeFile, readdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import { resolve, relative, basename, dirname } from "node:path";
import { z } from "zod";
import { Transaction, keccak256 } from "ethers";

const root = process.cwd();
const here = dirname(fileURLToPath(import.meta.url));
const exec = promisify(execFile);
const git = async (args: string[]) => (await exec("git", args, { cwd: root,
  env: { ...process.env, GIT_MASTER: "1" } })).stdout;
async function list(directory: string): Promise<string[]> {
  const result: string[] = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) result.push(...await list(path));
    else if (entry.isFile()) result.push(path);
  }
  return result.sort();
}
const base = "acdbe319f3a20c3af6bea594c62461b6c7988717";
const runs = (await readdir(resolve(here, "runtime-03"))).filter((n) => n.startsWith("rehearsal-"));
assert.equal(runs.length, 1);
const runtime = resolve(here, "runtime-03", runs[0]!);
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8")) as unknown;
const hex = z.string().regex(/^0x[0-9a-f]*$/i);
const hash = z.string().regex(/^0x[0-9a-f]{64}$/i);
const address = z.string().regex(/^0x[0-9a-f]{40}$/i);
const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string() });
async function bind(path: string) {
  const bytes = await readFile(path);
  return { path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") };
}
const head = (await git(["rev-parse", "HEAD"])).trim();
const branch = (await git(["branch", "--show-current"])).trim();
assert.equal(head, base);
assert.equal(branch, "work/dtf-migration-phase-18-earlier-receipt");
const diff = (await git(["-c", "diff.ignoreSubmodules=all", "diff", "--name-only"])).trim().split("\n");
const additions = [
  "scripts/recovery/dtf-migration/earlier-receipt.test.ts",
  "scripts/recovery/dtf-migration/rehearsal-earlier-receipt.ts",
  "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceiptConfiguration.t.sol",
  "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceipt.t.sol",
];
const files = [...new Set([...diff, ...additions])].sort();
const migration = "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/";
for (const file of files) assert(
  file.startsWith(migration) || file.startsWith("scripts/recovery/dtf-migration/")
  || file.startsWith("scripts/foundry/recovery/dtf-migration/")
  || file.startsWith("test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/")
  || file.startsWith("test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/")
  || file === "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md", file);
const source = await Promise.all(files.map((p) => bind(resolve(root, p))));
const immutable = [];
for (const directory of ["source", "source-verification"]) {
  for (const file of await list(resolve(here, "..", directory))) {
    immutable.push(await bind(file));
  }
}
for (const [path, expected] of [
  ["source/contract.md", "173bc343faf90a1d01ada52f16f86b0d707f6d87687bc438d9e209654bcbdc91"],
  ["source-verification/report.md", "86d0c1a22ffd398b528f9008c658a8fc51c39f273cdd50275faabd64668fbf35"],
] as const) assert.equal((await bind(resolve(here, "..", path))).sha256, expected);
const verifierSeal = z.object({ producerSealSha256: z.string() }).passthrough()
  .parse(await json(resolve(here, "../source-verification/seal.json")));
assert.equal((await bind(resolve(here, "../source/seal.json"))).sha256, verifierSeal.producerSealSha256);
const sealedMembership = new Set<string>();
for (const directory of ["source", "source-verification"]) {
  sealedMembership.add(resolve(here, "..", directory, "seal.json"));
  const sealed = z.object({ evidence: z.array(binding) }).passthrough()
    .parse(await json(resolve(here, "..", directory, "seal.json")));
  for (const prior of sealed.evidence) {
    sealedMembership.add(resolve(here, "..", directory, prior.path));
    const current = await bind(resolve(here, "..", directory, prior.path));
    assert.equal(current.sha256, prior.sha256, prior.path);
    assert.equal(current.bytes, prior.bytes, prior.path);
  }
}
assert.deepEqual(new Set(immutable.map((b) => b.path)), sealedMembership);
const admitted = z.object({ inputs: z.array(binding) }).passthrough().parse(await json(resolve(here, "../source/seal.json")));
const authority = [];
for (const prior of admitted.inputs.filter((b) => !b.path.startsWith(root + "/"))) {
  const current = await bind(prior.path);
  assert.equal(current.sha256, prior.sha256, prior.path);
  assert.equal(current.bytes, prior.bytes, prior.path);
  authority.push(current);
}
const implementationBrief = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase18-earlier-receipt-implementation-brief.md";
authority.push(await bind(implementationBrief));
const code = z.object({ address, code: hex, codeHash: hash });
const runtimeCodes = z.array(code.extend({ role: z.string() })).parse(await json(resolve(runtime, "runtime-code.json")));
const children = z.array(code.extend({
  role: z.string(), facets: z.array(code.extend({ name: z.string() })),
})).parse(await json(resolve(runtime, "deployed-runtime-bindings.json")));
const libraries = z.array(code.extend({ name: z.string(), source: z.string() }))
  .parse(await json(resolve(runtime, "linked-library-runtime.json")));
const captures = [...runtimeCodes, ...children, ...children.flatMap((c) => c.facets), ...libraries];
for (const capture of captures) {
  assert.equal(keccak256(capture.code), capture.codeHash);
  assert((capture.code.length - 2) / 2 <= 24576, capture.address);
}
const ranges = z.array(z.object({ start: z.number(), length: z.number() }));
const artifactSchema = z.object({
  deployedBytecode: z.object({
    object: z.string(), immutableReferences: z.record(z.string(), ranges).default({}),
    linkReferences: z.record(z.string(), z.record(z.string(), ranges)).default({}),
  }),
  metadata: z.object({ compiler: z.object({ version: z.string() }),
    sources: z.record(z.string(), z.object({ keccak256: hash }).passthrough()) }).passthrough(),
}).passthrough();
const artifacts = [];
const checkedSources = new Map<string, string>();
const productionCoverage = new Set<string>();
const named = [...children.flatMap((c) => c.facets),
  ...runtimeCodes.filter((c) => c.role === "package").map((c) => ({ ...c, name: "UniswapV4DetfMigrationDFPkg" })),
  ...libraries];
for (const deployed of named) {
  const name = deployed.name;
  const path = resolve(root, "out", "source" in deployed ? basename(z.string().parse(deployed.source)) : `${name}.sol`, `${name}.json`);
  const artifact = artifactSchema.parse(await json(path));
  assert(artifact.metadata.compiler.version.startsWith("0.8.38"));
  const expected = artifact.deployedBytecode.object.replace(/^0x/, "").toLowerCase().split("");
  const observed = deployed.code.slice(2).toLowerCase().split("");
  assert.equal(expected.length, observed.length, name);
  for (const [source, names] of Object.entries(artifact.deployedBytecode.linkReferences)) {
    for (const [libraryName, slots] of Object.entries(names)) for (const slot of slots) {
      assert.equal(slot.length, 20);
      const linked = `0x${observed.slice(slot.start * 2, (slot.start + slot.length) * 2).join("")}`;
      assert(libraries.some((l) => l.address === linked && l.name === libraryName && l.source === source),
        `${name} missing authenticated link ${source}:${libraryName} at ${linked}`);
    }
  }
  if ("source" in deployed && expected.slice(0, 42).join("") === `73${"0".repeat(40)}`) {
    assert.equal(`0x${observed.slice(2, 42).join("")}`, deployed.address);
    for (let i = 2; i < 42; i++) { expected[i] = "0"; observed[i] = "0"; }
  }
  const mask = [...Object.values(artifact.deployedBytecode.immutableReferences).flat(),
    ...Object.values(artifact.deployedBytecode.linkReferences).flatMap((r) => Object.values(r).flat())];
  for (const { start, length } of mask) for (let i = start * 2; i < (start + length) * 2; i++) {
    expected[i] = "0"; observed[i] = "0";
  }
  assert.equal(expected.join(""), observed.join(""), name);
  for (const [file, input] of Object.entries(artifact.metadata.sources)) {
    const prior = checkedSources.get(file);
    if (prior) assert.equal(prior, input.keccak256, file);
    else {
      const actual = keccak256(await readFile(resolve(root, file)));
      assert.equal(actual, input.keccak256, file);
      checkedSources.set(file, actual);
    }
    productionCoverage.add(file);
  }
  artifacts.push({ ...await bind(path), name, runtimeBytes: observed.length / 2, masks: mask.length });
}
for (const facet of runtimeCodes.filter((c) => c.role === "facet")) {
  assert(children.flatMap((c) => c.facets).some((c) => c.address === facet.address && c.codeHash === facet.codeHash));
}
for (const file of files.filter((f) => f.startsWith(migration))) assert(productionCoverage.has(file), file);
const originalSchema = z.object({
  originalId: hash, originalWallet: address, source: address, originalUnits: z.string(),
  originalEth: z.string(), originalDtf: z.string(), evidenceId: hash, contributionsKnown: z.literal(true),
});
const manifestSchema = z.object({ input: z.object({
  sources: z.array(z.object({ path: z.string(), sha256: z.string(), bytes: z.string() }).passthrough()),
}).passthrough() }).passthrough();
const inputs = new Map<string, Awaited<ReturnType<typeof bind>>>();
for (const name of (await list(runtime)).filter((p) => basename(p) === "manifest.json")) {
  const manifest = manifestSchema.parse(await json(name));
  for (const input of manifest.input.sources) {
    const actual = await bind(resolve(root, input.path));
    assert.equal(actual.sha256, input.sha256, input.path);
    assert.equal(String(actual.bytes), input.bytes, input.path);
    inputs.set(actual.path, actual);
  }
}
const receiptSchema = z.object({
  transactionHash: hash, from: address, to: address.nullable(), status: hex,
  gasUsed: hex, blockHash: hash, blockNumber: hex, logs: z.array(z.unknown()),
}).passthrough();
let signedCount = 0;
for (const name of (await readdir(runtime)).filter((p) => p.includes("signed-") && p.endsWith(".json"))) {
  const signed = z.object({ raw: hex, transactionHash: hash, to: address, data: hex, nonce: z.number(),
    from: address.optional(), signer: address.optional(), receipt: receiptSchema }).passthrough().parse(await json(resolve(runtime, name)));
  const tx = Transaction.from(signed.raw);
  assert.equal(tx.hash, signed.transactionHash);
  assert.equal(tx.from?.toLowerCase(), (signed.from ?? signed.signer)?.toLowerCase());
  assert.equal(tx.to?.toLowerCase(), signed.to.toLowerCase());
  assert.equal(tx.data, signed.data);
  assert.equal(tx.nonce, signed.nonce);
  assert.equal(tx.chainId, 4663n);
  assert.equal(signed.receipt.transactionHash, tx.hash);
  assert.equal(signed.receipt.from, tx.from?.toLowerCase());
  assert.equal(signed.receipt.to, tx.to?.toLowerCase());
  assert([0n, 1n].includes(BigInt(signed.receipt.status)));
  assert(BigInt(signed.receipt.gasUsed) > 0n);
  signedCount++;
}
for (const stage of ["donation", "issuance", "owner-bond"]) {
  const before = z.object({ completionPresent: z.literal(false), intent: z.object({
    signedTransaction: hex, transactionHash: hash, nonce: z.string().regex(/^[0-9]+$/),
  }).passthrough(), receipt: receiptSchema }).passthrough().parse(await json(resolve(runtime, `${stage}-before-resume.json`)));
  const after = z.object({ sameCanonicalReceipt: z.literal(true), transactionHash: hash }).passthrough()
    .parse(await json(resolve(runtime, `${stage}-resumed.json`)));
  const tx = Transaction.from(before.intent.signedTransaction);
  assert.equal(tx.hash, before.intent.transactionHash);
  assert.equal(tx.hash, before.receipt.transactionHash);
  assert.equal(tx.hash, after.transactionHash);
  assert.equal(tx.chainId, 4663n);
  assert.equal(BigInt(tx.nonce), BigInt(before.intent.nonce));
  assert.equal(tx.from?.toLowerCase(), before.receipt.from);
  assert.equal(BigInt(before.receipt.status), 1n);
}
const state = z.object({
  walletInternal: z.string(), custodyInternal: z.string(), allowance: z.string(),
  rate: z.string(), total: z.string(), E: z.string(), B: z.string(),
  surrender: z.array(z.string()).length(4), supply: z.string(), backing: z.string(),
});
const economics = [];
for (const phase of ["partial", "changed-rate"]) {
  const result = z.object({ original: originalSchema, before: state, after: state, nativeAmount: z.string(),
    q: z.string(), credit: z.string(), rLow: z.string(), rHigh: z.string(), transactionHash: hash,
  }).passthrough().parse(await json(resolve(runtime, `earlier-receipt-${phase}.json`)));
  const q = BigInt(result.nativeAmount) * 10n ** 27n / BigInt(result.before.rate);
  const Q = BigInt(result.before.surrender[2]!);
  const C = BigInt(result.before.surrender[3]!);
  const credit = q === Q ? C : C * q / Q;
  assert.equal(String(q), result.q); assert.equal(String(credit), result.credit);
  assert.equal(result.rLow, result.before.rate); assert.equal(result.rHigh, result.before.rate);
  assert.equal(result.before.rate, result.after.rate); assert.equal(result.before.total, result.after.total);
  assert.equal(BigInt(result.before.walletInternal) - BigInt(result.after.walletInternal), q);
  assert.equal(BigInt(result.after.custodyInternal) - BigInt(result.before.custodyInternal), q);
  assert.equal(BigInt(result.after.B) - BigInt(result.before.B), q);
  assert.equal(BigInt(result.before.allowance) - BigInt(result.after.allowance), BigInt(result.nativeAmount));
  assert.equal(result.before.E, result.after.E);
  assert.equal(BigInt(result.after.surrender[2]!), Q - q);
  assert.equal(BigInt(result.after.surrender[3]!), C - credit);
  assert.equal(BigInt(result.after.supply) - BigInt(result.before.supply), credit);
  assert.equal(BigInt(result.after.backing) - BigInt(result.before.backing), credit);
  economics.push({ phase, q: String(q), credit: String(credit), rate: result.before.rate,
    configurationCredit: String(C + BigInt(result.before.surrender[1]!)), after: result.after });
}
const cleanup = z.object({ node: z.literal("exited"), runtime: z.literal("removed"), checkpoint: z.string() })
  .passthrough().parse(await json(resolve(runtime, "cleanup.json")));
assert(!existsSync(cleanup.checkpoint));
assert(!existsSync(resolve(root, ".omo-runtime/dtf-migration-earlier-receipt")));
await exec("/bin/zsh", ["-lc", "lsof -nP -iTCP:18568 -sTCP:LISTEN; [ $? -eq 1 ]"]);
const checks = {
  sourceScope: files.length, productionRoots: files.filter((f) => f.startsWith(migration)).length,
  immutableFiles: immutable.length, authorityInputs: authority.length, preparedInputs: inputs.size,
  artifactBindings: artifacts.length, uniqueArtifacts: new Set(artifacts.map((a) => a.path)).size,
  compilerSources: checkedSources.size, runtimeCaptures: captures.length, linkedLibraries: libraries.length,
  rawSignedReceipts: signedCount, realInterruptedResumes: 3,
};
const result = { schema: "earlier-receipt-implementation-audit/1", base, branch, checks, economics,
  source, immutable, authority, inputs: [...inputs.values()], artifacts, cleanup, stopped: true };
if (process.argv.includes("--seal")) {
  const prior = z.object({ source: z.array(binding) }).passthrough().parse(await json(resolve(here, "audit.json")));
  assert.equal(JSON.stringify(prior.source), JSON.stringify(source), "source changed after audit");
  const evidence = [];
  for (const file of await list(here)) {
    if (["seal.json", "seal.log"].includes(relative(here, file))) continue;
    evidence.push(await bind(file));
  }
  const seal = { ...result, evidence, report: await bind(resolve(here, "report.md")),
    selfExclusions: ["seal.json", "seal.log"], noPendingOperation: true };
  await writeFile(resolve(here, "seal.json"), `${JSON.stringify(seal, null, 2)}\n`);
} else {
  await writeFile(resolve(here, "audit.json"), `${JSON.stringify(result, null, 2)}\n`);
}
console.log(JSON.stringify({ status: "validated", checks, seal: process.argv.includes("--seal"),
  worktree: root, runtime: relative(root, runtime), report: basename(resolve(here, "report.md")) }));
