import { readFile } from "node:fs/promises";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { keccak256 } from "ethers";
import { z } from "zod";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { fingerprint as sha } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = process.cwd();
const producer = join(dirname(here), "implementation-e1");
const run = z.string().parse(process.argv[2]);
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
function requireProof(value: boolean, message: string): asserts value {
  if (!value) throw new ExecutionError("STATE", message);
}
const entry = z.object({ path: z.string(), sha256: z.string() }).passthrough();
const sources = z.object({ sources: z.array(entry) }).parse(await json(join(producer, "final-source-bindings.json")));
const tree = z.object({ files: z.array(entry) }).parse(await json(join(producer, "final-tree.json")));
const prior = z.object({ files: z.array(entry) }).parse(await json(join(producer, "final-sealed-preservation.json")));
const inputs = z.object({ inputs: z.array(entry) }).parse(await json(join(producer, "final-input-bindings.json")));
const checked = [];
for (const group of [
  { name: "sources", base: root, entries: sources.sources },
  { name: "producer-seal", base: producer, entries: tree.files },
  { name: "preserved-predecessors", base: root, entries: prior.files },
  { name: "authority", base: root, entries: inputs.inputs },
]) {
  for (const item of group.entries) {
    const bytes = await readFile(resolve(group.base, item.path));
    const actual = sha(bytes);
    requireProof(actual === item.sha256, `changed ${group.name}: ${item.path}`);
    checked.push({ group: group.name, path: item.path, bytes: bytes.length, sha256: actual });
  }
}
const artifacts = z.object({ artifacts: z.array(entry) }).parse(await json(join(producer, "final-artifact-bindings.json")));
const runtimeSchema = z.object({ address: z.string(), code: z.string(), codeHash: z.string() }).passthrough();
const runtimes = z.array(runtimeSchema).parse(await json(join(run, "runtime-code.json")));
for (const runtime of runtimes) requireProof(keccak256(runtime.code) === runtime.codeHash, "runtime code hash mismatch");
const span = z.object({ start: z.number().int(), length: z.number().int() });
const spans = z.array(span);
const bytecode = z.object({
  object: z.string(),
  linkReferences: z.record(z.string(), z.record(z.string(), spans)).default({}),
  immutableReferences: z.record(z.string(), spans).default({}),
}).passthrough();
const metadata = z.object({
  compiler: z.object({ version: z.string() }).passthrough(),
  sources: z.record(z.string(), z.object({ keccak256: z.string() }).passthrough()),
  settings: z.object({ compilationTarget: z.record(z.string(), z.string()) }).passthrough(),
}).passthrough();
const artifactSchema = z.object({
  deployedBytecode: bytecode, metadata, rawMetadata: z.string().optional(),
}).passthrough();
const sourceHashes = new Map<string, string>();
const artifactResults = [];
const extra = [
  "out/MigrationClaimVault.t.sol/MigrationClaimVaultTest.json",
  "out/MigrationRecoveryClaimVault.t.sol/MigrationRecoveryClaimVaultTest.json",
  "out/MigrationClaimVaultConfiguration.t.sol/MigrationClaimVaultConfigurationTest.json",
];
for (const path of [...artifacts.artifacts.map((item) => item.path), ...extra]) {
  const bytes = await readFile(join(root, path));
  const artifact = artifactSchema.parse(JSON.parse(bytes.toString()));
  const original = artifacts.artifacts.find((item) => item.path === path);
  const currentHash = sha(bytes);
  if (original) requireProof(original.sha256 === currentHash, `raw artifact differs: ${path}`);
  const metadatas = [artifact.metadata];
  if (artifact.rawMetadata) metadatas.push(metadata.parse(JSON.parse(artifact.rawMetadata)));
  let sourceEntries = 0;
  for (const info of metadatas) {
    for (const [source, expected] of Object.entries(info.sources)) {
      let actual = sourceHashes.get(source);
      if (!actual) {
        const sourcePath = source.startsWith("@crane/") ? source.replace("@crane/", "lib/crane/") : source;
        actual = keccak256(await readFile(join(root, sourcePath)));
        sourceHashes.set(source, actual);
      }
      requireProof(actual === expected.keccak256, `${path}: compiled source mismatch ${source}`);
      sourceEntries++;
    }
  }
  const declared = [
    ...Object.values(artifact.deployedBytecode.linkReferences).flatMap((libraries) => Object.values(libraries).flat()),
    ...Object.values(artifact.deployedBytecode.immutableReferences).flat(),
  ];
  const mask = (code: string) => {
    let masked = code.toLowerCase();
    for (const item of declared) {
      const start = 2 + item.start * 2;
      masked = masked.slice(0, start) + "0".repeat(item.length * 2) + masked.slice(start + item.length * 2);
    }
    return masked;
  };
  const template = artifact.deployedBytecode.object;
  const matched = runtimes.filter((item) => mask(item.code) === mask(template));
  if (path.includes("Migration") && !path.includes("Stage_") && !path.includes(".t.sol")) {
    requireProof(matched.length === 1, `missing unique deployed runtime: ${path}`);
    requireProof((template.length - 2) / 2 <= 24576, `EIP170 excess: ${path}`);
  }
  artifactResults.push({ path, sha256: currentHash, producerRawEqual: original !== undefined,
    compiler: artifact.metadata.compiler, target: artifact.metadata.settings.compilationTarget,
    sourceEntries, runtimeBytes: (template.length - 2) / 2,
    actual: matched.map((item) => ({ address: item.address, codeHash: item.codeHash,
      spans: declared.map((part) => ({ ...part, actual: item.code.slice(2 + part.start * 2, 2 + (part.start + part.length) * 2) })) })),
  });
}
const manifest = z.object({ sources: z.array(z.object({
  id: z.string(), path: z.string(), sha256: z.string(),
}).passthrough()) }).passthrough().parse(await json(join(run, "pre-capture.json")));
const dependencies = [];
for (const input of manifest.sources) {
  const bytes = await readFile(input.path);
  requireProof(sha(bytes) === input.sha256, `CLI input changed: ${input.path}`);
  dependencies.push({ ...input, independentlyMatched: true });
}
await save(join(here, "binding-audit.json"), { run, checked, artifacts: artifactResults,
  distinctMetadataSources: sourceHashes.size, sourceHashes: Object.fromEntries(sourceHashes),
  runtimeCount: runtimes.length, runtimeHashesVerified: true, dependencies,
  limitation: "Bounded host/worktree-local rehearsal; preserve the phase15 archive input. No portable/full-F3 acceptance.",
});
console.log(JSON.stringify({ sources: sources.sources.length, producerSeal: tree.files.length,
  preserved: prior.files.length, artifacts: artifactResults.length,
  metadataSources: sourceHashes.size, runtimes: runtimes.length, status: "bindings-audit-complete" }));
