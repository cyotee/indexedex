import assert from "node:assert/strict";
import { readFile, readdir, lstat, writeFile, readlink } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { keccak256 } from "ethers";
import { z } from "zod";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../../../../..");
const input = z.string().parse(process.argv[2]);
const runtime = resolve(input);
const json = async (path: string): Promise<unknown> => JSON.parse(await readFile(path, "utf8"));
const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string() });
const identify = async (path: string) => {
  const raw = await readFile(path);
  return { path, bytes: raw.byteLength, sha256: createHash("sha256").update(raw).digest("hex"),
    mode: (await lstat(path)).mode & 0o777 };
};
async function walk(path: string): Promise<string[]> {
  const result: string[] = [];
  for (const name of (await readdir(path)).sort()) {
    const next = join(path, name);
    const stat = await lstat(next);
    if (stat.isDirectory()) result.push(...await walk(next));
    else { assert(stat.isFile(), `nonregular evidence ${next}`); result.push(next); }
  }
  return result;
}
const producer = z.object({
  base: z.literal("a96f0fd26c1a1fdba35750cff74d866afa3a9796"),
  finalSources: z.array(binding), tree: z.array(binding),
  cleanup: z.object({ sourceChangesStopped: z.literal(true), noPendingOperation: z.literal(true) }).passthrough(),
}).parse(await json(join(here, "../implementation/seal.json")));
const preserved = [];
for (const expected of [...producer.tree, ...producer.finalSources]) {
  const actual = await identify(expected.path);
  assert.equal(actual.bytes, expected.bytes, expected.path);
  assert.equal(actual.sha256, expected.sha256, expected.path);
  preserved.push(actual);
}
const producerMembers = await walk(join(here, "../implementation"));
assert.deepEqual(producerMembers.sort(), [...producer.tree.map((p) => p.path), join(here, "../implementation/seal.json")].sort());
const qualification = z.object({
  tree: z.array(binding), previousSeal: binding,
  preservation: z.array(z.object({ preserved: binding }).passthrough()),
}).parse(await json(join(here, "../source/qualification-seal.json")));
const admission = z.object({
  verificationFiles: z.array(binding), producerQualifiedSeal: binding, report: binding,
}).parse(await json(join(here, "../source-verification/closure.json")));
const immutable = [...qualification.tree, qualification.previousSeal,
  ...qualification.preservation.map((row) => row.preserved), ...admission.verificationFiles,
  admission.producerQualifiedSeal, admission.report];
for (const expected of immutable) {
  const actual = await identify(expected.path);
  assert.equal(actual.bytes, expected.bytes, expected.path);
  assert.equal(actual.sha256, expected.sha256, expected.path);
}
const immutableMembers = [...await walk(join(here, "../source")), ...await walk(join(here, "../source-verification"))];
assert.deepEqual(immutableMembers.sort(), [...new Set([...qualification.tree.map((p) => p.path),
  join(here, "../source/qualification-seal.json"), ...admission.verificationFiles.map((p) => p.path),
  join(here, "../source-verification/closure.json")])].sort());
for (const [path, expected] of [
  ["../source/contract.md", "8505a56f2b9dec9a34d9fb322d1a9cd78aa7e151678008427143cce9ff782bd6"],
  ["../source-verification/report.md", "b39dd7edeb5f0250ffd257744df2304eb18485c195f121ec64f058eebb077c56"],
] as const) assert.equal((await identify(join(here, path))).sha256, expected);
const sourceSeal = z.object({ inputs: z.array(binding) }).parse(await json(join(here, "../source/seal.json")));
const authorities = [];
for (const expected of sourceSeal.inputs.slice(0, 13)) {
  const actual = await identify(expected.path);
  assert.equal(actual.bytes, expected.bytes);
  assert.equal(actual.sha256, expected.sha256);
  authorities.push(actual);
}
const span = z.object({ start: z.number().int().nonnegative(), length: z.number().int().positive() });
const artifactSchema = z.object({
  metadata: z.object({
    compiler: z.object({ version: z.string() }),
    sources: z.record(z.string(), z.object({ keccak256: z.string() })),
    settings: z.object({ compilationTarget: z.record(z.string(), z.string()) }).passthrough(),
  }),
  deployedBytecode: z.object({
    object: z.string(),
    linkReferences: z.record(z.string(), z.record(z.string(), z.array(span))).default({}),
    immutableReferences: z.record(z.string(), z.array(span)).default({}),
  }),
});
const runtimeEntry = z.object({ address: z.string(), name: z.string(), code: z.string(), codeHash: z.string() });
const components = z.array(z.object({
  role: z.string(), address: z.string(), code: z.string(), codeHash: z.string(), facets: z.array(runtimeEntry),
})).parse(await json(join(runtime, "deployed-runtime-bindings.json")));
const named = new Map(components.flatMap((row) => row.facets.map((facet) => [facet.address, facet] as const)));
const extra = z.array(z.object({ role: z.string(), address: z.string(), code: z.string(), codeHash: z.string() }))
  .parse(await json(join(runtime, "runtime-code.json")));
const pkg = extra.find((row) => row.role === "package");
assert(pkg);
named.set(pkg.address, { ...pkg, name: "UniswapV4DetfMigrationDFPkg" });
const compiled = new Map<string, Awaited<ReturnType<typeof identify>> & { readonly keccak256: string }>();
const artifacts = [];
for (const row of named.values()) {
  assert.equal(keccak256(row.code), row.codeHash);
  const path = join(root, "out", `${row.name}.sol`, `${row.name}.json`);
  const a = artifactSchema.parse(await json(path));
  const template = a.deployedBytecode.object.replace(/^0x/, "");
  const actual = row.code.slice(2);
  assert.equal(template.length, actual.length, row.name);
  assert(actual.length / 2 <= 24576, row.name);
  const spans = [...Object.values(a.deployedBytecode.immutableReferences).flat(),
    ...Object.values(a.deployedBytecode.linkReferences).flatMap((refs) => Object.values(refs).flat())];
  const mask = new Set<number>();
  for (const s of spans) {
    assert(s.start + s.length <= actual.length / 2);
    for (let i = s.start; i < s.start + s.length; i++) mask.add(i);
  }
  for (let i = 0; i < actual.length / 2; i++) {
    if (!mask.has(i)) assert.equal(actual.slice(i * 2, i * 2 + 2).toLowerCase(),
      template.slice(i * 2, i * 2 + 2).toLowerCase(), `${row.name} byte ${i}`);
  }
  for (const [source, identity] of Object.entries(a.metadata.sources)) {
    const sourcePath = join(root, source);
    const raw = await readFile(sourcePath);
    assert.equal(keccak256(raw), identity.keccak256, source);
    compiled.set(sourcePath, { ...await identify(sourcePath), keccak256: identity.keccak256 });
  }
  artifacts.push({ ...await identify(path), address: row.address, name: row.name,
    runtimeBytes: actual.length / 2, runtimeHash: row.codeHash, compiler: a.metadata.compiler.version,
    target: a.metadata.settings.compilationTarget,
    spans: spans.map((s) => ({ ...s, actual: "0x" + actual.slice(s.start * 2, (s.start + s.length) * 2) })) });
}
const staticArtifacts = [];
for (const [file, name] of [
  ["Phase_08_Stage_00_OperatorEnvironment.s.sol", "Phase_08_Stage_00_OperatorEnvironment"],
  ["Phase_08_Stage_01_MigrationExecution.s.sol", "Phase_08_Stage_01_MigrationExecution"],
  ["IUniswapV4DetfMigration.sol", "IUniswapV4DetfMigration"],
  ["IUniswapV4DetfMigration.sol", "IUniswapV4DetfMigrationAllocation"],
  ["IUniswapV4DetfMigrationRecovery.sol", "IUniswapV4DetfMigrationRecovery"],
] as const) {
  const path = join(root, "out", file, name + ".json");
  const a = artifactSchema.parse(await json(path));
  for (const [source, identity] of Object.entries(a.metadata.sources)) {
    const sourcePath = join(root, source);
    assert.equal(keccak256(await readFile(sourcePath)), identity.keccak256, source);
    compiled.set(sourcePath, { ...await identify(sourcePath), keccak256: identity.keccak256 });
  }
  staticArtifacts.push({ ...await identify(path), target: a.metadata.settings.compilationTarget });
}
for (const row of [...components, ...extra]) assert.equal(keccak256(row.code), row.codeHash);
const evidence = {
  runtime, producerSeal: await identify(join(here, "../implementation/seal.json")), preserved,
  immutableReferences: immutable, immutableMembers: await Promise.all(immutableMembers.map(identify)),
  authorities, artifacts, staticArtifacts, compiled: [...compiled.values()], components,
  dependencies: { crane: await readlink(join(root, "lib/crane")), nodeModules: await readlink(join(root, "node_modules")) },
};
await writeFile(join(here, "bindings.json"), JSON.stringify(evidence, null, 2) + "\n", { flag: "wx" });
console.log(`BINDINGS_CONFIRMED sources=${producer.finalSources.length} immutable=${immutableMembers.length} artifacts=${artifacts.length} compiled=${compiled.size}`);
