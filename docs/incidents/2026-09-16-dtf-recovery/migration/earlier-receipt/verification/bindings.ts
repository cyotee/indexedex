import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { keccak256 } from "ethers";
import { z } from "zod";
import { address, bind, binding, files, hash, hex, json, root, sha } from "./evidence.js";

const code = z.object({ address, code: hex, codeHash: hash });
const namedCode = code.extend({ name: z.string(), source: z.string().optional() });
const ranges = z.array(z.object({ start: z.number().int().nonnegative(), length: z.number().int().positive() }));
const artifactSchema = z.object({
  deployedBytecode: z.object({
    object: z.string(), immutableReferences: z.record(z.string(), ranges).default({}),
    linkReferences: z.record(z.string(), z.record(z.string(), ranges)).default({}),
  }),
  metadata: z.object({
    compiler: z.object({ version: z.string() }), sources: z.record(z.string(), z.object({ keccak256: hash })),
    settings: z.object({ optimizer: z.object({ enabled: z.literal(true), runs: z.literal(1) }), viaIR: z.boolean().optional() }).passthrough(),
  }).passthrough(),
}).passthrough();

export async function bindings(runtime: string) {
  const here = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt");
  const historicalHeader = z.object({
    hash: z.literal("0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733"),
    number: z.literal("0x67e5d17"),
  }).passthrough().parse(await json(resolve(runtime, "historical-header.json")));
  const seal = z.object({
    source: z.array(binding), immutable: z.array(binding), authority: z.array(binding), evidence: z.array(binding),
    report: binding, stopped: z.literal(true), noPendingOperation: z.literal(true),
  }).passthrough().parse(await json(resolve(here, "implementation/seal.json")));
  const preserved = [];
  for (const entry of [...seal.source, ...seal.immutable, ...seal.authority, ...seal.evidence, seal.report]) {
    const observed = await bind(entry.path);
    assert.equal(observed.bytes, entry.bytes, entry.path);
    assert.equal(observed.sha256, entry.sha256, entry.path);
    preserved.push(observed);
  }
  assert.equal((await bind(resolve(here, "source/contract.md"))).sha256,
    "173bc343faf90a1d01ada52f16f86b0d707f6d87687bc438d9e209654bcbdc91");
  assert.equal((await bind(resolve(here, "source-verification/report.md"))).sha256,
    "86d0c1a22ffd398b528f9008c658a8fc51c39f273cdd50275faabd64668fbf35");
  const actualImmutable = [...await files(resolve(here, "source")), ...await files(resolve(here, "source-verification"))].sort();
  assert.deepEqual(actualImmutable, seal.immutable.map(e => e.path).sort());
  const runtimes = z.array(code.extend({ role: z.string() })).parse(await json(resolve(runtime, "runtime-code.json")));
  const children = z.array(code.extend({ role: z.string(), facets: z.array(namedCode) }))
    .parse(await json(resolve(runtime, "deployed-runtime-bindings.json")));
  const libraries = z.array(namedCode).parse(await json(resolve(runtime, "linked-library-runtime.json")));
  const captures = [...runtimes, ...children, ...children.flatMap(c => c.facets), ...libraries];
  for (const capture of captures) {
    assert.equal(keccak256(capture.code), capture.codeHash);
    assert(capture.code.length > 2 && (capture.code.length - 2) / 2 <= 24576);
  }
  const sources = new Map<string, string>();
  const artifacts = [];
  for (const deployed of [...children.flatMap(c => c.facets), ...libraries,
    ...children.map(c => ({ ...c, name: "MinimalDiamondCallBackProxy", source: undefined })),
    ...runtimes.filter(c => c.role === "registry").map(c => ({ ...c, name: "MinimalDiamondCallBackProxy", source: undefined })),
    ...runtimes.filter(c => c.role === "package").map(c => ({ ...c, name: "UniswapV4DetfMigrationDFPkg", source: undefined }))]) {
    const path = resolve(root, "out", basename(deployed.source ?? `${deployed.name}.sol`), `${deployed.name}.json`);
    const artifact = artifactSchema.parse(await json(path));
    assert.equal(artifact.metadata.compiler.version, "0.8.38+commit.e7a91fc7.solar.0.3.0-dev");
    assert.notEqual(artifact.metadata.settings.viaIR, true);
    const expected = artifact.deployedBytecode.object.replace(/^0x/, "").toLowerCase().split("");
    const observed = deployed.code.slice(2).toLowerCase().split("");
    assert.equal(expected.length, observed.length, deployed.name);
    const spans = [];
    for (const [source, names] of Object.entries(artifact.deployedBytecode.linkReferences)) {
      for (const [name, locations] of Object.entries(names)) for (const location of locations) {
        assert.equal(location.length, 20);
        const target = `0x${observed.slice(location.start * 2, (location.start + location.length) * 2).join("")}`;
        assert(libraries.some(l => l.address.toLowerCase() === target && l.name === name && l.source === source));
        spans.push({ ...location, kind: "linked-library", source, name, actual: target });
      }
    }
    for (const [id, locations] of Object.entries(artifact.deployedBytecode.immutableReferences)) {
      for (const location of locations) spans.push({ ...location, kind: "immutable", source: id, name: "",
        actual: `0x${observed.slice(location.start * 2, (location.start + location.length) * 2).join("")}` });
    }
    if (deployed.source && expected.slice(0, 42).join("") === `73${"0".repeat(40)}`) {
      const actual = `0x${observed.slice(2, 42).join("")}`;
      assert.equal(actual, deployed.address.toLowerCase());
      spans.push({ start: 1, length: 20, kind: "compiler-library-self-address", source: deployed.source, name: deployed.name, actual });
    }
    for (const span of spans) {
      assert(span.start + span.length <= observed.length / 2);
      for (let i = span.start * 2; i < (span.start + span.length) * 2; i++) expected[i] = observed[i] = "0";
    }
    assert.equal(expected.join(""), observed.join(""), deployed.name);
    for (const [file, input] of Object.entries(artifact.metadata.sources)) {
      assert.equal(keccak256(await readFile(resolve(root, file))), input.keccak256, file);
      const previous = sources.get(file);
      if (previous) assert.equal(previous, input.keccak256, file);
      sources.set(file, input.keccak256);
    }
    artifacts.push({ ...await bind(path), address: deployed.address, name: deployed.name, spans,
      actualCode: deployed.code, codeHash: deployed.codeHash, bytesRuntime: observed.length / 2,
      compiler: artifact.metadata.compiler, compilerSettings: artifact.metadata.settings });
  }
  for (const entry of seal.source.filter(e => e.path.includes("/contracts/"))) {
    assert(sources.has(entry.path.slice(root.length + 1)), entry.path);
  }
  const stages = [];
  for (const name of ["Phase_08_Stage_00_OperatorEnvironment", "Phase_08_Stage_01_MigrationExecution"]) {
    const path = resolve(root, "out", `${name}.s.sol`, `${name}.json`);
    const artifact = artifactSchema.parse(await json(path));
    assert.equal(artifact.metadata.compiler.version, "0.8.38+commit.e7a91fc7.solar.0.3.0-dev");
    assert.notEqual(artifact.metadata.settings.viaIR, true);
    for (const [file, input] of Object.entries(artifact.metadata.sources)) {
      assert.equal(keccak256(await readFile(resolve(root, file))), input.keccak256, file);
    }
    stages.push({ ...await bind(path), compiler: artifact.metadata.compiler,
      sources: artifact.metadata.sources, settings: artifact.metadata.settings });
  }
  const preparedInputs = new Map<string, Awaited<ReturnType<typeof bind>>>();
  const producerInputReconstruction = [];
  const manifestSchema = z.object({ input: z.object({ sources: z.array(z.object({
    path: z.string(), bytes: z.string(), sha256: z.string(),
  }).passthrough()) }).passthrough() }).passthrough();
  for (const name of (await files(runtime)).filter(p => basename(p) === "manifest.json")) {
    for (const input of manifestSchema.parse(await json(name)).input.sources) {
      const actual = await bind(resolve(root, input.path));
      if (actual.sha256 !== input.sha256) {
        // Required independent compilation changes the top-level Solar artifact
        // source-unit ID. Recover original raw bytes only by exact sealed hash.
        // No original evidence or artifact is rewritten, and fresh inputs get no exception.
        assert(runtime.startsWith(resolve(here, "implementation/runtime-03")));
        assert(actual.path.startsWith(resolve(root, "out") + "/"));
        const raw = await readFile(actual.path, "utf8");
        assert(/"id":[0-9]+\}$/.test(raw));
        let recovered: { readonly raw: string; readonly id: number } | undefined;
        for (let id = 0; id < 10000; id++) {
          const candidate = raw.replace(/"id":[0-9]+\}$/, `"id":${id}}`);
          if (Buffer.byteLength(candidate) === Number(input.bytes) && sha(candidate) === input.sha256) {
            assert.equal(recovered, undefined);
            recovered = { raw: candidate, id };
          }
        }
        assert(recovered, `Not an exactly recoverable compiler-ID-only drift: ${input.path}`);
        producerInputReconstruction.push({ path: actual.path, originalId: recovered.id,
          currentId: z.object({ id: z.number() }).passthrough().parse(JSON.parse(raw)).id,
          originalBytes: Number(input.bytes), originalSha256: input.sha256, recoveredRaw: recovered.raw,
          current: actual, qualification: "exact original hash recovered offline; not an original captured file" });
      } else assert.equal(String(actual.bytes), input.bytes);
      preparedInputs.set(actual.path, actual);
    }
  }
  return { producerSeal: await bind(resolve(here, "implementation/seal.json")), preserved, captures, historicalHeader, stages,
    artifacts, compilerSources: [...sources].map(([path, keccak256]) => ({ path, keccak256 })),
    preparedInputs: [...preparedInputs.values()], producerInputReconstruction };
}
