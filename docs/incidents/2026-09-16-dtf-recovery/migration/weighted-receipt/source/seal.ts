import { readFile, readdir, lstat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { keccak256 } from "ethers";
import { z } from "zod";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../../../../..");
const main = "/Users/cyotee/Projects/indexedex";
const phase11 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources/docs/incidents/2026-09-16-dtf-recovery/migration/same-wallet-sources";
const phase16 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault/docs/incidents/2026-09-16-dtf-recovery/migration/claim-vault";
const bind = async (path: string) => {
  const bytes = await readFile(path);
  return { path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") };
};
const inputPaths = [
  main + "/.omo/ulw-execute/dtf-migration/phase17-weighted-receipt-brief.md",
  main + "/.omo/ulw-execute/dtf-migration/phase13-owner-first-bond-correction.md",
  main + "/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md",
  main + "/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md",
  ...["weighted/contract.md", "verification/report.md", "verification/matrix.md"].map((p) => join(phase11, p)),
  ...["verification-e1/report.md", "format-correction/report.md", "format-verification/report.md",
    "format-verification/f1-closure.md", "format-commit/receipt.md", "format-commit/final-verification.md"]
    .map((p) => join(phase16, p)),
  "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/weighted/probe.sources.json",
  "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/weighted/deployed-source-extracts.json",
  join(root, "deployments/robinhood_main_fee_accrual/composition/phase09_stage02_fee_accrual_frontend_candidate.json"),
  ...["rehearsal-chain.ts", "rehearsal-process.ts", "execution-rpc.ts", "execution-schema.ts",
    "rehearsal-data.ts", "provenance.ts", "schema.ts"].map((p) => join(root, "scripts/recovery/dtf-migration", p)),
  join(root, "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol"),
  join(root, "out/ReceiptBoundaryProbe.sol/ReceiptBoundaryProbe.json"),
];
const inputs = await Promise.all(inputPaths.map(bind));
const archive = z.object({ selected: z.record(z.string(), z.object({
  sources: z.record(z.string(), z.object({ content: z.string() }).passthrough()),
  runtimeBytecode: z.object({ onchainBytecode: z.string() }).passthrough(),
}).passthrough()) }).passthrough().parse(JSON.parse(await readFile(join(here, "retained-source.json"), "utf8")));
const ws = archive.selected["0xb7581fe833a2b2380dd786b345d61ffb734d36eb"];
if (!ws) throw new ExecutionError("STATE", "missing archived WS facet");
const sourceText = [];
for (const filename of ["StakedDETFTarget.sol", "DETFFundedStakingRepo.sol", "DETFFundedStakingMath.sol"]) {
  const match = Object.entries(ws.sources).find(([path]) => path.endsWith("/" + filename));
  if (!match) throw new ExecutionError("STATE", "missing archived source " + filename);
  const [originalPath, value] = match;
  const path = join(here, "archived", filename + ".txt");
  const actual = await readFile(path, "utf8");
  if (actual !== value.content) throw new ExecutionError("STATE", "archived source text differs " + filename);
  sourceText.push({ originalPath, ...await bind(path) });
}
const run = process.argv[2] ?? "run-04";
const identity = z.object({ runtime: z.array(z.object({
  code: z.string(), codeHash: z.string(), facet: z.string(), selector: z.string(),
}).passthrough()) }).passthrough().parse(JSON.parse(await readFile(join(here, run, "identity.json"), "utf8")));
for (const runtime of identity.runtime) {
  if (runtime.code !== ws.runtimeBytecode.onchainBytecode || keccak256(runtime.code) !== runtime.codeHash) {
    throw new ExecutionError("STATE", "actual pinned WS runtime differs from retained archive");
  }
}
const helperArtifact = z.object({ deployedBytecode: z.object({ object: z.string() }) })
  .passthrough().parse(JSON.parse(await readFile(join(root,
    "out/ReceiptBoundaryProbe.sol/ReceiptBoundaryProbe.json"), "utf8")));
const helperRuntime = z.object({ code: z.string(), codeHash: z.string() }).passthrough().parse(
  JSON.parse(await readFile(join(here, run, "helper-runtime.json"), "utf8")));
if (helperRuntime.code !== helperArtifact.deployedBytecode.object
  || keccak256(helperRuntime.code) !== helperRuntime.codeHash) {
  throw new ExecutionError("STATE", "actual helper runtime differs from Solar artifact");
}
const tree: Awaited<ReturnType<typeof bind>>[] = [];
async function walk(path: string): Promise<void> {
  for (const name of (await readdir(path)).sort()) {
    if (path === here && name === "seal.json") continue;
    const entry = join(path, name);
    const stat = await lstat(entry);
    if (stat.isDirectory()) await walk(entry);
    else if (stat.isFile()) tree.push(await bind(entry));
    else throw new ExecutionError("STATE", "unexpected source evidence symlink");
  }
}
await walk(here);
await save(join(here, "seal.json"), { disposition: "not-ready", scope: "weighted WS source-unit contract only",
  base: "a96f0fd26c1a1fdba35750cff74d866afa3a9796", inputs, sourceText,
  archivedRuntimeEqualsActualPinnedRuntime: true, helperArtifactEqualsActualRuntime: true,
  tree, selfExcluded: "seal.json",
  productionImplementation: false });
console.log("SOURCE_SEALED", tree.length, "files");
