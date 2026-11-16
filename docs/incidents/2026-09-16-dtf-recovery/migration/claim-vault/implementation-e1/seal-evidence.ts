import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { keccak256 } from "ethers";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault";
const evidence = dirname(fileURLToPath(import.meta.url));
const completedRun = resolve(process.argv[2] ?? "");
if (process.cwd() !== root) throw new Error("wrong bounded worktree");
if (!completedRun.startsWith(join(evidence, "cli-run") + "/")) throw new Error("completed CLI evidence required");
const git = async (...args: readonly string[]) =>
  (await promisify(execFile)("git", [...args], { cwd: root, env: { ...process.env, GIT_MASTER: "1" } })).stdout.trim();
const sha = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
async function publish(path: string, bytes: Uint8Array) {
  try { await writeFile(path, bytes, { flag: "wx" }); }
  catch (error) {
    if (!(error instanceof Error) || !("code" in error) || error.code !== "EEXIST") throw error;
    if (!Buffer.from(bytes).equals(await readFile(path))) throw new Error(`immutable binding differs: ${path}`);
  }
}
const put = async (name: string, value: unknown) =>
  publish(join(evidence, `final-${name}`), Buffer.from(`${JSON.stringify(value, null, 2)}\n`));
const sourcePrefixes = [
  "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/",
  "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/",
  "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/",
  "scripts/recovery/dtf-migration/",
  "scripts/foundry/recovery/dtf-migration/",
];
const runbook = "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md";
const head = await git("rev-parse", "HEAD");
if (head !== "4a53299b490343ed904d70c92ecbc7360fcb7659") throw new Error("base moved");
const allNames = [...new Set([
  ...(await git("diff", "--name-only", "--ignore-submodules=all")).split("\n"),
  ...(await git("ls-files", "--others", "--exclude-standard")).split("\n"),
])].filter(Boolean).sort();
const sourceNames = allNames.filter((name) => name === runbook || sourcePrefixes.some((prefix) => name.startsWith(prefix)));
const outside = allNames.filter((name) => !sourceNames.includes(name)
  && !name.startsWith(relative(root, evidence) + "/")
  && !name.startsWith("docs/incidents/2026-09-16-dtf-recovery/migration/claim-vault/implementation/")
  && !name.startsWith("docs/incidents/2026-09-16-dtf-recovery/migration/claim-vault/verification/"));
if (outside.length) throw new Error(`outside bounded scope: ${outside.join(",")}`);
const sources = [];
for (const name of sourceNames) {
  const bytes = await readFile(join(root, name));
  const target = join(evidence, "final-source-snapshot", name);
  await mkdir(dirname(target), { recursive: true });
  await publish(target, bytes);
  sources.push({ path: name, size: bytes.length, sha256: sha(bytes) });
}
await put("source-bindings.json", { head, branch: await git("branch", "--show-current"), sources, outside });
const inputs = [];
for (const path of [
  "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase16-claim-vault-brief.md",
  "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase13-owner-first-bond-correction.md",
  "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md",
  "/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md",
]) {
  const bytes = await readFile(path);
  inputs.push({ path, size: bytes.length, sha256: sha(bytes) });
}
await put("input-bindings.json", { inputs });
const artifacts = [];
for (const name of [
  "UniswapV4DetfMigrationFacet", "UniswapV4DetfMigrationAllocationFacet",
  "UniswapV4DetfMigrationClaimVaultAllocationFacet", "UniswapV4DetfMigrationRecoveryFacet",
  "UniswapV4DetfMigrationDFPkg", "Phase_08_Stage_00_OperatorEnvironment", "Phase_08_Stage_01_MigrationExecution",
]) {
  const path = join(root, "out", `${name}${name.startsWith("Phase_") ? ".s.sol" : ".sol"}`, `${name}.json`);
  const bytes = await readFile(path);
  const artifact = JSON.parse(bytes.toString());
  const creation: string = artifact.bytecode.object;
  const runtime: string = artifact.deployedBytecode.object;
  artifacts.push({ path: relative(root, path), sha256: sha(bytes),
    creationTemplateSha256: sha(Buffer.from(creation)), runtimeTemplateSha256: sha(Buffer.from(runtime)),
    creationHash: /^0x[0-9a-fA-F]*$/.test(creation) ? keccak256(creation) : null,
    runtimeHash: /^0x[0-9a-fA-F]*$/.test(runtime) ? keccak256(runtime) : null,
    linkReferences: artifact.bytecode.linkReferences,
    runtimeLinkReferences: artifact.deployedBytecode.linkReferences,
    note: "Null bytecode hashes denote unlinked templates; actual linked deployment hashes are in CLI execution-manifest bindings.",
    runtimeBytes: (artifact.deployedBytecode.object.length - 2) / 2 });
}
await put("artifact-bindings.json", { artifacts });
const files: { path: string; size: number; sha256: string }[] = [];
async function collect(directory: string) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) await collect(path);
    else if (entry.isFile()) {
      const bytes = await readFile(path);
      files.push({ path: relative(root, path), size: bytes.length, sha256: sha(bytes) });
    }
  }
}
for (const name of ["implementation", "verification"]) {
  await collect(join(dirname(evidence), name));
}
await put("sealed-preservation.json", { note: "Read-only preserved predecessor directories; no files in these directories were edited by this increment.", files });
const cleanup = JSON.parse(await readFile(join(completedRun, "cleanup.json"), "utf8"));
if (cleanup.node !== "exited" || cleanup.runtime !== "removed") throw new Error("CLI runtime cleanup missing");
const runtime = [];
for (const name of ["claim-vault-stage1.json", "claim-vault-partial.json", "claim-vault-final.json",
  "claim-vault-acquisition.json", "owner-bond-observation.json", "donation-before-resume.json",
  "donation-resumed.json", "issuance-before-resume.json", "issuance-resumed.json",
  "owner-bond-before-resume.json", "owner-bond-resumed.json", "cleanup.json"]) {
  const path = join(completedRun, name);
  const bytes = await readFile(path);
  runtime.push({ path: relative(root, path), size: bytes.length, sha256: sha(bytes) });
}
await put("runtime-bindings.json", { completedRun, fullTask9: "open", runtime });
console.log(JSON.stringify({ boundSources: sources.length, boundArtifacts: artifacts.length,
  sealedFiles: files.length, completedRun }));
