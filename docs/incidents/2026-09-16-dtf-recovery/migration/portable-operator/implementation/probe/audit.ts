import assert from "node:assert/strict";
import { lstat, readFile, readlink, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { z } from "zod";
import { bindings } from "./bindings.js";
import { receipts } from "./receipts.js";
import { economics } from "./economics.js";
import { edEconomics } from "./ed-economics.js";
import { heldEconomics } from "./held-economics.js";
import { claimedEconomics } from "./claimed-economics.js";
import { lifecycle } from "./lifecycle.js";
import { wireAndConstructor } from "./wire-constructor.js";
import { bind, binding, canonical, files, json, required, root, sha } from "./evidence.js";

const here = dirname(dirname(import.meta.filename));
const runtime = required(process.argv[2]);
const wirePath = required(process.argv[3]);
const frozen = z.object({ source: z.array(binding.extend({ mode: z.number() })),
  authority: z.array(binding.extend({ mode: z.number() })), git: z.array(binding.extend({ mode: z.number() })),
  sourceModificationsStopped: z.literal(true) }).passthrough().parse(await json(join(here, "source-manifest-stopped.json")));
for (const entry of [...frozen.source, ...frozen.authority, ...frozen.git]) {
  const actual = await bind(entry.path);
  assert.equal(actual.sha256, entry.sha256, entry.path);
  assert.equal(actual.bytes, entry.bytes, entry.path);
  assert.equal(actual.mode, entry.mode, entry.path);
}
const baseline = z.object({ rows: z.array(binding.extend({
  mode: z.number(), copy: z.string().nullable(), target: z.string().optional(),
})) }).passthrough().parse(await json(join(here, "preservation-baseline.json")));
const copies = new Set<string>();
const preserved = [];
const changedOwned = [];
for (const entry of baseline.rows) {
  if (entry.copy && !copies.has(entry.copy)) {
    const raw = await readFile(entry.copy);
    assert.equal(sha(raw), entry.sha256, entry.copy);
    assert.equal(raw.length, entry.bytes, entry.copy);
    copies.add(entry.copy);
  }
  const compilerOutput = ["out", "cache_forge"].some(p => entry.path.startsWith(resolve(root, p) + "/"));
  const stat = await lstat(entry.path).catch((error: unknown) => {
    if (error instanceof Error && "code" in error && error.code === "ENOENT" && compilerOutput) return undefined;
    throw error;
  });
  if (!stat) {
    assert(entry.copy, "removed compiler output must have its original lossless capture");
    changedOwned.push({ original: entry, actual: null, reason: "owned compiler output removed; original raw bytes preserved" });
    continue;
  }
  const raw = stat.isSymbolicLink() ? Buffer.from(await readlink(entry.path)) : await readFile(entry.path);
  const actual = { path: entry.path, sha256: sha(raw), bytes: raw.length, mode: stat.mode };
  const changed = actual.sha256 !== entry.sha256 || actual.bytes !== entry.bytes || actual.mode !== entry.mode;
  const ownedMutable = ["out/", "cache_forge/", "scripts/recovery/dtf-migration/",
    "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md"]
    .some(p => entry.path.startsWith(resolve(root, p) + (p.endsWith("/") ? "/" : "")));
  if (changed) {
    assert(ownedMutable, `foreign original changed: ${entry.path}`);
    changedOwned.push({ original: entry, actual });
  } else preserved.push(actual);
}
const originalInputs = [];
for (const name of ["original-input-bytes.json", "replacement-original-input-bytes.json"]) {
  const capture = z.object({ records: z.array(z.object({
    path: z.string(), rawBase64: z.string(), sha256: z.string(), bytes: z.string(), terminalNewline: z.boolean(),
  }).passthrough()) }).passthrough().parse(await json(join(runtime, name)));
  for (const entry of capture.records) {
    const raw = Buffer.from(entry.rawBase64, "base64");
    assert.equal(raw.toString("base64"), entry.rawBase64);
    assert.equal(String(raw.length), entry.bytes);
    assert.equal(sha(raw), entry.sha256);
    assert.equal(raw.at(-1) === 10, entry.terminalNewline);
    assert.equal((await bind(entry.path)).sha256, entry.sha256);
    originalInputs.push({ capture: name, ...entry, rawBase64: undefined });
  }
}
const bound = await bindings(runtime);
const signed = await receipts(runtime);
const er = await economics(runtime, signed);
const ed = await edEconomics(runtime, signed);
const held = await heldEconomics(runtime, signed);
const claimed = await claimedEconomics(runtime, signed);
const life = await lifecycle(runtime, signed);
const wire = await wireAndConstructor({ runtime, wirePath, bound, signed });
const relocations = [];
for (const label of ["funding", "configuration", "replacement"]) {
  const location = join(runtime, `relocation-${label}`);
  const comparison = z.object({
    first: z.string(), second: z.string(), actualOperations: z.array(z.unknown()),
    firstNormalizedHash: z.string().nullable(), secondNormalizedHash: z.string().nullable(),
  }).passthrough().parse(await json(join(location, "comparison.json")));
  if (label !== "funding") assert.notEqual(comparison.firstNormalizedHash, comparison.secondNormalizedHash);
  const executionShape = z.object({ sources: z.array(z.object({ path: z.string() }).passthrough()),
    preparedManifest: z.string().nullable() }).passthrough();
  const a = executionShape.parse(await json(comparison.first));
  const b = executionShape.parse(await json(comparison.second));
  assert.deepEqual(a.sources.map(({ path: _path, ...s }) => s), b.sources.map(({ path: _path, ...s }) => s));
  if (a.preparedManifest && b.preparedManifest) {
    const shape = z.object({ payloads: z.unknown(), payloadHash: z.string(), quoteEvidence: z.unknown(),
      normalizedHash: z.string() }).passthrough();
    const first = shape.parse(await json(a.preparedManifest));
    const second = shape.parse(await json(b.preparedManifest));
    const original = shape.parse(await json(join(runtime, label === "configuration" ? "prepared/manifest.json" : "replacement/manifest.json")));
    assert.deepEqual(first.payloads, second.payloads);
    assert.deepEqual(first.payloads, original.payloads);
    assert.equal(first.payloadHash, second.payloadHash);
    assert.equal(first.payloadHash, original.payloadHash);
    assert.deepEqual(first.quoteEvidence, second.quoteEvidence);
    assert.deepEqual(first.quoteEvidence, original.quoteEvidence);
    assert.equal(first.normalizedHash, comparison.firstNormalizedHash);
    assert.equal(second.normalizedHash, comparison.secondNormalizedHash);
  }
  const operation = z.object({ id: z.string(), method: z.string(),
    transaction: z.object({ from: z.string(), to: z.string(), data: z.string(), value: z.string() }).strict(),
  }).passthrough();
  const expected = comparison.actualOperations.map((value) => operation.parse(value))
    .map(({ id, method, transaction }) => ({ id, method, transaction })).sort((x, y) => x.id.localeCompare(y.id));
  const journal = label === "funding" ? "journal-fund" : label === "configuration" ? "journal-configure" : "journal-replacement";
  const actual = signed.completions.filter(c => dirname(c.path) === join(runtime, journal))
    .map(c => operation.parse(c.intent)).map(({ id, method, transaction }) => ({ id, method, transaction }))
    .sort((x, y) => x.id.localeCompare(y.id));
  assert.deepEqual(actual, expected, `actual mined ${label} payloads differ from both preparations`);
  const accesses = [];
  for (const side of ["a", "b"]) {
    const access = z.object({ reads: z.array(z.object({ path: z.string(), sha256: z.string(), bytes: z.string() })) })
      .passthrough().parse(await json(join(location, `materialized-${side}/bundle-access.json`)));
    for (const entry of access.reads) {
      assert(entry.path.startsWith(join(location, `location-${side}/`)));
      assert(!(await lstat(entry.path)).isSymbolicLink());
      const actual = await bind(entry.path);
      assert.equal(actual.sha256, entry.sha256);
      assert.equal(String(actual.bytes), entry.bytes);
    }
    accesses.push(access);
  }
  relocations.push({ label, comparison, accesses });
}
const negatives = [];
for (const path of (await files(runtime)).filter(p => p.endsWith("-rejection.json"))) {
  const result = z.object({ nonceBefore: z.string(), nonceAfter: z.string(), error: z.string() }).parse(await json(path));
  assert.equal(result.nonceBefore, result.nonceAfter);
  negatives.push({ path, ...result });
}
for (const corruption of ["missing", "tamper", "symlink"]) {
  const negative = join(runtime, `negative-materialized-${corruption}`);
  assert((await files(negative)).includes(join(negative, "negative.json")));
  await assert.rejects(lstat(join(negative, "must-not-send")), { code: "ENOENT" });
}
const capture = z.object({ status: z.literal("producer-capture-closed"), blocks: z.number() }).parse(
  JSON.parse(required((await readFile(wirePath, "utf8")).trim().split("\n").at(-1))));
const cleanup = z.object({ node: z.literal("exited"), runtime: z.literal("removed"), checkpoint: z.string() })
  .passthrough().parse(await json(join(runtime, "cleanup.json")));
await assert.rejects(lstat(cleanup.checkpoint), { code: "ENOENT" });
const result = {
  status: "portable-producer-audit-pass", runtime, sourceManifest: await bind(join(here, "source-manifest-stopped.json")),
  originals: { preserved, changedOwned, losslessCopies: copies.size, originalInputs,
    limitation: "Current lossless baselines only; P1's two historical raw JSON versions remain unrecovered." },
  bound, signed, er, ed, held, claimed, lifecycle: life, ...wire, relocations, negatives, capture, cleanup,
  summary: { sourcePaths: frozen.source.length, productionContractEdits: 0, artifacts: bound.artifacts.length,
    runtimeCaptures: bound.captures.length, compilerSources: bound.compilerSources.length,
    originalInputReferences: originalInputs.length, originalRawSigned: signed.signed.length,
    reconstructedSigned: signed.reconstructed.length, canonicalResumes: signed.resumes.length,
    httpBodies: wire.wire.responses, canonicalReceipts: wire.wire.receipts, blocks: capture.blocks,
    removedSelectors: life.removed.length, originalRegistrationGas: signed.registrationReceipt.gasUsed },
};
await writeFile(join(here, "audit.json"), JSON.stringify(result,
  (_, value: unknown) => typeof value === "bigint" ? String(value) : value, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify(result.summary));
console.log("PORTABLE_PRODUCER_AUDIT_COMPLETE");
