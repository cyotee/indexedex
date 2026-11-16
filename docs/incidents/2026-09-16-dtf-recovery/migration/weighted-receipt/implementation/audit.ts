import { readFile, readdir, lstat, mkdir, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve, join, dirname, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text as streamText } from "node:stream/consumers";
import { Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { canonical } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../../../../..");
const runtime = resolve(z.string().parse(process.argv[2]));
const output = resolve(here, z.string().parse(process.argv[3]));
if (!output.startsWith(`${here}/`)) throw new Error("audit output must be owned implementation evidence");
await mkdir(output, { recursive: false });
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const save = async (name: string, value: unknown) =>
  writeFile(join(output, name), `${canonical(value)}\n`, { flag: "wx" });
const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string() });
async function identify(path: string) {
  const bytes = await readFile(path);
  return { path, bytes: bytes.byteLength, sha256: createHash("sha256").update(bytes).digest("hex") };
}
async function walk(path: string): Promise<string[]> {
  const files: string[] = [];
  for (const name of (await readdir(path)).sort()) {
    const next = join(path, name);
    const stat = await lstat(next);
    if (stat.isDirectory()) files.push(...await walk(next));
    else if (stat.isFile()) files.push(next);
    else throw new Error(`unexpected evidence symlink ${next}`);
  }
  return files;
}
const qualified = z.object({
  tree: z.array(binding), previousSeal: binding,
  preservation: z.array(z.object({ original: binding, preserved: binding }).passthrough()),
}).passthrough().parse(await json(join(here, "../source/qualification-seal.json")));
const verifier = z.object({
  verificationFiles: z.array(binding), producerQualifiedSeal: binding, report: binding,
}).passthrough().parse(await json(join(here, "../source-verification/closure.json")));
const expected = [...qualified.tree, qualified.previousSeal, ...qualified.preservation.map((p) => p.preserved),
  ...verifier.verificationFiles, verifier.producerQualifiedSeal, verifier.report];
const preserved = [];
for (const item of expected) {
  const actual = await identify(item.path);
  if (actual.bytes !== item.bytes || actual.sha256 !== item.sha256) throw new Error(`immutable input changed ${item.path}`);
  preserved.push(actual);
}
const immutableFiles = [...await walk(join(here, "../source")), ...await walk(join(here, "../source-verification"))];
const expectedMembers = new Set([
  ...qualified.tree.map((p) => p.path), join(here, "../source/qualification-seal.json"),
  ...verifier.verificationFiles.map((p) => p.path), join(here, "../source-verification/closure.json"),
].map((p) => resolve(p)));
if (immutableFiles.length !== expectedMembers.size || immutableFiles.some((p) => !expectedMembers.has(resolve(p)))) {
  throw new Error("immutable source/source-verification membership changed");
}
await save("immutable-preservation.json", {
  verifiedReferences: preserved, currentTrees: await Promise.all(immutableFiles.map(identify)),
});

async function git(args: readonly string[]) {
  const process_ = spawn("git", [...args], {
    cwd: root, env: { ...process.env, GIT_MASTER: "1", GIT_OPTIONAL_LOCKS: "0" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const closed = once(process_, "close", { signal: AbortSignal.timeout(15000) });
  const [text, errors, exit] = await Promise.all([
    streamText(process_.stdout), streamText(process_.stderr), closed,
  ]);
  if (exit[0] !== 0) throw new Error(`read-only git failed ${errors}`);
  return text;
}
const production = "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/";
const spec = "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/";
const fork = "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/";
const operator = "scripts/recovery/dtf-migration/";
const stages = "scripts/foundry/recovery/dtf-migration/";
const runbook = "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md";
const changed = (await git(["diff", "--ignore-submodules=all", "--name-only"])).trim().split("\n").filter(Boolean);
const added = (await git(["ls-files", "--others", "--exclude-standard", "--", production, spec, fork, operator, stages]))
  .trim().split("\n").filter(Boolean);
const sourcePaths = [...new Set([...changed, ...added])].sort();
const sources = [];
for (const path of sourcePaths) {
  if (![production, spec, fork, operator, stages].some((prefix) => path.startsWith(prefix)) && path !== runbook) {
    throw new Error(`source outside admitted scope ${path}`);
  }
  const full = join(root, path);
  const snapshot = join(output, "source", `${path}.txt`);
  await mkdir(dirname(snapshot), { recursive: true });
  await writeFile(snapshot, await readFile(full), { flag: "wx" });
  sources.push({ ...await identify(full), relative: path, snapshot });
}
await save("source-bindings.json", {
  head: (await git(["rev-parse", "HEAD"])).trim(), sourcePaths: sources,
  whitespace: await git(["diff", "--ignore-submodules=all", "--check"]),
  staged: await git(["diff", "--cached", "--ignore-submodules=all", "--stat"]),
});

const span = z.object({ start: z.number().int().nonnegative(), length: z.number().int().positive() });
const artifactSchema = z.object({
  metadata: z.object({
    compiler: z.object({ version: z.string() }),
    settings: z.object({ compilationTarget: z.record(z.string(), z.string()) }).passthrough(),
    sources: z.record(z.string(), z.object({ keccak256: z.string() }).passthrough()),
  }).passthrough(),
  deployedBytecode: z.object({
    object: z.string(),
    linkReferences: z.record(z.string(), z.record(z.string(), z.array(span))).default({}),
    immutableReferences: z.record(z.string(), z.array(span)).default({}),
  }).passthrough(),
}).passthrough();
const runtimeEntry = z.object({ address: z.string(), name: z.string(), code: z.string(), codeHash: z.string() });
const deployed = z.array(z.object({
  role: z.string(), address: z.string(), code: z.string(), codeHash: z.string(), facets: z.array(runtimeEntry),
})).parse(await json(join(runtime, "deployed-runtime-bindings.json")));
const named = new Map(deployed.flatMap((p) => p.facets.map((f) => [f.address, f] as const)));
const oldRuntime = z.array(z.object({
  role: z.string(), address: z.string(), code: z.string(), codeHash: z.string(),
})).parse(await json(join(runtime, "runtime-code.json")));
const packageCode = oldRuntime.find((r) => r.role === "package");
if (!packageCode) throw new Error("actual package runtime missing");
named.set(packageCode.address, { ...packageCode, name: "UniswapV4DetfMigrationDFPkg" });
const compiled = new Map<string, Awaited<ReturnType<typeof identify>> & { readonly keccak256: string }>();
const artifactBindings = [];
for (const row of named.values()) {
  if (keccak256(row.code) !== row.codeHash) throw new Error(`captured runtime hash differs ${row.name}`);
  const path = join(root, "out", `${row.name}.sol`, `${row.name}.json`);
  const artifact = artifactSchema.parse(await json(path));
  const template = artifact.deployedBytecode.object.replace(/^0x/, "");
  const actual = row.code.slice(2);
  if (actual.length !== template.length || actual.length / 2 > 24576) throw new Error(`runtime length differs ${row.name}`);
  const spans = [
    ...Object.values(artifact.deployedBytecode.immutableReferences).flat(),
    ...Object.values(artifact.deployedBytecode.linkReferences).flatMap((refs) => Object.values(refs).flat()),
  ];
  const mask = (code: string) => {
    const bytes = code.split("");
    for (const item of spans) {
      if (item.start + item.length > code.length / 2) throw new Error("declared span exceeds runtime");
      bytes.fill("0", item.start * 2, (item.start + item.length) * 2);
    }
    return bytes.join("").toLowerCase();
  };
  if (mask(template) !== mask(actual)) throw new Error(`artifact/runtime differs outside compiler spans ${row.name}`);
  for (const [source, sourceIdentity] of Object.entries(artifact.metadata.sources)) {
    const path = join(root, source);
    const bytes = await readFile(path);
    if (keccak256(bytes) !== sourceIdentity.keccak256) throw new Error(`compiled source differs ${source}`);
    if (!compiled.has(path)) compiled.set(path, { ...await identify(path), keccak256: sourceIdentity.keccak256 });
  }
  artifactBindings.push({ ...await identify(path), name: row.name, address: row.address, runtime: row.codeHash,
    runtimeBytes: actual.length / 2, compiler: artifact.metadata.compiler.version,
    target: artifact.metadata.settings.compilationTarget,
    spans: spans.map((s) => ({ ...s, actualBytes: `0x${actual.slice(s.start * 2, (s.start + s.length) * 2)}` })),
  });
}
for (const row of deployed) {
  if (keccak256(row.code) !== row.codeHash) throw new Error(`component runtime hash differs ${row.role}`);
}
const staticArtifacts = [];
for (const [file, name] of [
  ["Phase_08_Stage_00_OperatorEnvironment.s.sol", "Phase_08_Stage_00_OperatorEnvironment"],
  ["Phase_08_Stage_01_MigrationExecution.s.sol", "Phase_08_Stage_01_MigrationExecution"],
  ["IUniswapV4DetfMigration.sol", "IUniswapV4DetfMigration"],
  ["IUniswapV4DetfMigration.sol", "IUniswapV4DetfMigrationAllocation"],
  ["IUniswapV4DetfMigrationRecovery.sol", "IUniswapV4DetfMigrationRecovery"],
] as const) {
  const path = join(root, "out", file, `${name}.json`);
  const artifact = artifactSchema.parse(await json(path));
  for (const [source, sourceIdentity] of Object.entries(artifact.metadata.sources)) {
    const path = join(root, source);
    if (keccak256(await readFile(path)) !== sourceIdentity.keccak256) throw new Error(`static compiled source differs ${source}`);
    if (!compiled.has(path)) compiled.set(path, { ...await identify(path), keccak256: sourceIdentity.keccak256 });
  }
  staticArtifacts.push({ ...await identify(path), name, compiler: artifact.metadata.compiler.version });
}
await save("artifact-runtime-bindings.json", {
  artifacts: artifactBindings, staticArtifacts, compiledSources: [...compiled.values()], deployed,
});

const receiptRecord = z.object({
  transactionHash: z.string(), from: z.string(), to: z.string().nullable(), status: z.string(),
  logs: z.array(z.unknown()),
}).passthrough();
const intentRecord = z.object({
  id: z.string(), nonce: z.string(), transactionHash: z.string(), signedTransaction: z.string(),
  transaction: z.object({ from: z.string(), to: z.string(), data: z.string(), value: z.string() }),
}).passthrough();
function signed(raw: string, transactionHash: string, signer: string, nonce: string, to: string, data: string, value: string) {
  const decoded = Transaction.from(raw);
  if (keccak256(raw) !== transactionHash || decoded.hash !== transactionHash || decoded.chainId !== 4663n
    || decoded.from?.toLowerCase() !== signer.toLowerCase() || String(decoded.nonce) !== nonce
    || decoded.to?.toLowerCase() !== to.toLowerCase() || decoded.data !== data || String(decoded.value) !== value) {
    throw new Error(`signed identity differs ${transactionHash}`);
  }
  return { transactionHash, signer, nonce, to, data, value, chainId: "4663" };
}
const completions = new Map<string, z.infer<typeof receiptRecord>>();
const signedCompletions = [];
for (const path of await walk(runtime)) {
  if (!path.endsWith(".intent.json")) continue;
  const intent = intentRecord.parse(await json(path));
  const result = z.object({ receipt: receiptRecord }).passthrough()
    .parse(await json(path.replace(".intent.json", ".receipt.json")));
  const decoded = signed(intent.signedTransaction, intent.transactionHash, intent.transaction.from, intent.nonce,
    intent.transaction.to, intent.transaction.data, intent.transaction.value);
  if (result.receipt.transactionHash !== intent.transactionHash || BigInt(result.receipt.status) !== 1n) throw new Error("journal receipt differs");
  completions.set(intent.id, result.receipt);
  signedCompletions.push({ ...decoded, intentFile: path, receipt: result.receipt });
}
const resumes = [];
for (const name of ["donation", "issuance", "owner-bond"]) {
  const before = z.object({ intent: intentRecord, receipt: receiptRecord, completionPresent: z.literal(false) })
    .passthrough().parse(await json(join(runtime, `${name}-before-resume.json`)));
  const after = completions.get(before.intent.id);
  if (!after || canonical(after) !== canonical(before.receipt)) throw new Error(`complete raw resumed receipt differs ${name}`);
  resumes.push({ name, transactionHash: before.intent.transactionHash, nonce: before.intent.nonce,
    fields: Object.keys(before.receipt), receipt: before.receipt, noPreResumeCompletion: true });
}
const wsSigned = [];
for (const path of (await readdir(runtime)).filter((name) => name.startsWith("ws-signed-"))) {
  const item = z.object({ signer: z.string(), nonce: z.number(), raw: z.string(), transactionHash: z.string(),
    to: z.string(), data: z.string(), receipt: receiptRecord }).parse(await json(join(runtime, path)));
  const decoded = signed(item.raw, item.transactionHash, item.signer, String(item.nonce), item.to, item.data, "0");
  if (item.receipt.transactionHash !== item.transactionHash || item.receipt.from !== item.signer
    || (BigInt(item.receipt.status) === 0n && item.receipt.logs.length !== 0)) throw new Error("WS raw signed receipt differs");
  wsSigned.push({ ...decoded, path: join(runtime, path), receipt: item.receipt });
}
await save("signed-receipt-audit.json", { resumes, signedCompletions, wsSigned,
  fixtureReceipts: z.array(receiptRecord).parse(await json(join(runtime, "fixture-receipts.json"))).length });
await save("summary.json", { changedSources: sources.length, preservedReferences: preserved.length,
  immutableFiles: immutableFiles.length, artifacts: artifactBindings.length, staticArtifacts: staticArtifacts.length,
  compiledSources: compiled.size,
  signedCompletions: signedCompletions.length, wsSigned: wsSigned.length, resumes: resumes.length,
  wsFailed: wsSigned.filter((r) => BigInt(r.receipt.status) === 0n).length, runtime: relative(root, runtime) });
console.log("CANDIDATE_BINDINGS_AND_SIGNED_RECEIPTS_CONFIRMED");
