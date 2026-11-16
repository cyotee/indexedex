import { createHash } from "node:crypto";
import { readFile, readdir, lstat, readlink, writeFile } from "node:fs/promises";
import { dirname, join, resolve, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { z } from "zod";
import { canonical } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../../../../..");
const runtime = resolve(z.string().parse(process.argv[2]));
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
async function identify(path: string) {
  const stat = await lstat(path);
  if (!stat.isFile()) throw new Error(`seal rejects nonregular file ${path}`);
  const bytes = await readFile(path);
  return { path, bytes: bytes.byteLength, sha256: createHash("sha256").update(bytes).digest("hex"), mode: stat.mode & 0o777 };
}
const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string() }).passthrough();
async function verify(item: z.infer<typeof binding>) {
  const actual = await identify(item.path);
  if (actual.sha256 !== item.sha256 || actual.bytes !== item.bytes) throw new Error(`frozen binding changed ${item.path}`);
  return actual;
}
const sources = z.object({ head: z.string(), sourcePaths: z.array(binding.extend({ snapshot: z.string() })) })
  .passthrough().parse(await json(join(here, "audit-02/source-bindings.json")));
if (sources.head !== "a96f0fd26c1a1fdba35750cff74d866afa3a9796") throw new Error("admitted base changed");
const finalSources = [];
for (const item of sources.sourcePaths) {
  finalSources.push(await verify(item));
  if ((await identify(item.snapshot)).sha256 !== item.sha256) throw new Error("frozen source snapshot differs");
}
const artifacts = z.object({
  artifacts: z.array(binding), staticArtifacts: z.array(binding), compiledSources: z.array(binding),
}).passthrough().parse(await json(join(here, "audit-02/artifact-runtime-bindings.json")));
for (const item of [...artifacts.artifacts, ...artifacts.staticArtifacts, ...artifacts.compiledSources]) await verify(item);
const immutable = z.object({ currentTrees: z.array(binding) }).passthrough()
  .parse(await json(join(here, "audit-02/immutable-preservation.json")));
for (const item of immutable.currentTrees) await verify(item);
const contract = await identify(join(here, "../source/contract.md"));
const report = await identify(join(here, "../source-verification/report.md"));
if (contract.sha256 !== "8505a56f2b9dec9a34d9fb322d1a9cd78aa7e151678008427143cce9ff782bd6"
  || report.sha256 !== "b39dd7edeb5f0250ffd257744df2304eb18485c195f121ec64f058eebb077c56") {
  throw new Error("root-admitted source identities changed");
}
const cleanup = z.object({ pid: z.number(), node: z.literal("exited"), runtime: z.literal("removed"), checkpoint: z.string() })
  .passthrough().parse(await json(join(runtime, "cleanup.json")));
try {
  process.kill(cleanup.pid, 0);
  throw new Error("owned node PID still exists");
} catch (failure) {
  if (!(failure instanceof Error) || !("code" in failure) || failure.code !== "ESRCH") throw failure;
}
try {
  await lstat(cleanup.checkpoint);
  throw new Error("owned checkpoint was not removed");
} catch (failure) {
  if (!(failure instanceof Error) || !("code" in failure) || failure.code !== "ENOENT") throw failure;
}
const listener = spawn("lsof", ["-nP", "-iTCP:18567", "-sTCP:LISTEN"], { stdio: ["ignore", "pipe", "pipe"] });
const closed = once(listener, "close", { signal: AbortSignal.timeout(15000) });
const [listeners, listenerError, listenerExit] = await Promise.all([text(listener.stdout), text(listener.stderr), closed]);
if (listenerExit[0] !== 1 || listeners !== "" || listenerError !== "") throw new Error("fixed18567 listener not proven closed");
const links = {
  crane: await readlink(join(root, "lib/crane")), nodeModules: await readlink(join(root, "node_modules")),
};
if (links.crane !== "/Users/cyotee/Projects/indexedex/lib/crane"
  || links.nodeModules !== "/Users/cyotee/Projects/indexedex/node_modules") throw new Error("dependency links changed");
const roots = [
  "interfaces/IUniswapV4DetfMigration.sol", "UniswapV4DetfMigrationRepo.sol",
  "UniswapV4DetfMigrationAllocationTarget.sol", "UniswapV4DetfMigrationClaimVaultAllocationTarget.sol",
  "UniswapV4DetfMigrationClaimVaultAllocationFacet.sol", "UniswapV4DetfMigrationRecoveryTarget.sol",
  "UniswapV4DetfMigrationRecoveryFacet.sol", "legacy/IMigrationLegacyRecovery.sol", "legacy/MigrationLegacyRecoveryLib.sol",
].map((path) => `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/${path}`);
const types = "bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts";
const operatorFiles = ["preparation", "execution", "weighted-liquid", "weighted-sy", "dtf-custody-se", "claim-vault", "weighted-receipt"]
  .map((name) => `./scripts/recovery/dtf-migration/${name}.test.ts`);
const checks = [
  { name: "complete current specs", log: "specs-02.log", exitCode: 0, passed: 134, failed: 0,
    command: `python3 scripts/forge-artifacts.py test ${roots.join(" ")} --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/ --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol -- -vv` },
  { name: "complete current pinned forks", log: "forks-03.log", exitCode: 0, passed: 92, failed: 0,
    command: `FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test ${roots.join(" ")} --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/ -- -vv` },
  { name: "both operator stages", log: "stages-01.log", exitCode: 0,
    command: "forge build --use solar scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol" },
  { name: "final strict operator types", log: "types-final-03.log", exitCode: 0, command: types },
  { name: "one final operator test invocation after source freeze", log: "operator-final-03.log",
    exitCode: 0, passed: 68, failed: 0, command: `bun test --timeout 15000 ${operatorFiles.join(" ")}` },
  { name: "actual pinned18567 CLI with three mined-before-checkpoint resumes", log: "cli-02.log", exitCode: 0,
    command: "bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18567 --checkpoint .omo-runtime/dtf-migration-weighted-receipt/checkpoints --evidence docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/implementation/runtime-02" },
  { name: "raw source artifact runtime and signature reconciliation", log: "audit-02.log", exitCode: 0,
    command: `bun docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/implementation/audit.ts ${runtime} audit-02` },
  { name: "raw custody credit cliff and residual reconciliation", log: "audit-observations-03.log", exitCode: 0,
    command: `bun docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/implementation/audit-observations.ts ${runtime} ${join(here, "audit-02")}` },
];
const checkBindings = await Promise.all(checks.map(async (check) => ({ ...check, rawLog: await identify(join(here, check.log)) })));
const allFiles: Awaited<ReturnType<typeof identify>>[] = [];
async function walk(path: string) {
  for (const name of (await readdir(path)).sort()) {
    const full = join(path, name);
    if (full === join(here, "seal.json")) continue;
    const stat = await lstat(full);
    if (stat.isDirectory()) await walk(full);
    else allFiles.push(await identify(full));
  }
}
await walk(here);
const payload = {
  date: "2026-11-12", disposition: "validated bounded producer candidate; independent runtime verification remains separate",
  base: sources.head, runtime, approvedBootstrap: "/bin/zsh -lc; existing archive alias; no credential recorded",
  bun: "/opt/homebrew/Cellar/bun/1.4.2/bin/bun", solar: "0.8.38+commit.e7a91fc7.solar.0.3.0-dev",
  finalSources, immutableSource: contract, immutableVerification: report, immutableFiles: immutable.currentTrees.length,
  checks: checkBindings, artifactCount: artifacts.artifacts.length, staticArtifactCount: artifacts.staticArtifacts.length,
  compiledSourceCount: artifacts.compiledSources.length, cleanup: { ...cleanup, pidIndependentlyAbsent: true,
    port18567IndependentlyClosed: true, checkpointIndependentlyAbsent: true, dependencyLinks: links,
    sourceChangesStopped: true, noCommitOrMerge: true, noPendingOperation: true },
  tree: allFiles.map((file) => ({ ...file, relative: relative(here, file.path) })), selfExcluded: "seal.json",
};
const raw = `${canonical(payload)}\n`;
await writeFile(join(here, "seal.json"), raw, { flag: "wx" });
const finalSeal = await identify(join(here, "seal.json"));
console.log("FINAL_CANDIDATE_SEALED", canonical({ ...finalSeal, files: allFiles.length, sources: finalSources.length }));
