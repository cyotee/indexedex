import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { z } from "zod";
import { bindings } from "./bindings.js";
import { receipts } from "./receipts.js";
import { economics } from "./economics.js";
import { edEconomics } from "./ed-economics.js";
import { heldEconomics } from "./held-economics.js";
import { claimedEconomics } from "./claimed-economics.js";
import { lifecycle } from "./lifecycle.js";
import { wireAndConstructor } from "./wire-constructor.js";
import { bind, binding, json, required, root, sha } from "./evidence.js";

const here = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration/implementation");
const runtime = required(process.argv[2]);
const wirePath = required(process.argv[3]);
const manifest = z.object({
  base: z.literal("4eaa7decab80d24cf37cb3781eff5ffaf9362942"),
  branch: z.literal("work/dtf-migration-phase-23-claimed-sy-integration"),
  source: z.array(binding.extend({ mode: z.number() })),
  immutable: z.array(binding.extend({ mode: z.number().optional() })),
  authority: z.array(binding.extend({ mode: z.number() })),
  sourceModificationsStopped: z.literal(true),
}).passthrough().parse(await json(resolve(here, "source-manifest.json")));
const preserved = [];
for (const entry of [...manifest.source, ...manifest.immutable, ...manifest.authority]) {
  const actual = await bind(entry.path);
  assert.equal(actual.bytes, entry.bytes, entry.path);
  assert.equal(actual.sha256, entry.sha256, entry.path);
  if (entry.mode !== undefined) assert.equal(actual.mode, entry.mode, entry.path);
  preserved.push(actual);
}
assert.equal(manifest.source.length, 28);
assert(manifest.source.every(s => !s.path.includes("/contracts/")));
const originals = [];
for (const name of ["original-input-bytes.json", "replacement-original-input-bytes.json"]) {
  const capture = z.object({ records: z.array(z.object({
    path: z.string(), sha256: z.string(), bytes: z.string(), rawBase64: z.string(),
    terminalNewline: z.boolean(),
  }).passthrough()) }).passthrough().parse(await json(resolve(runtime, name)));
  for (const entry of capture.records) {
    const bytes = Buffer.from(entry.rawBase64, "base64");
    assert.equal(bytes.toString("base64"), entry.rawBase64);
    assert.equal(String(bytes.length), entry.bytes);
    assert.equal(sha(bytes), entry.sha256);
    assert.equal(bytes.at(-1) === 10, entry.terminalNewline);
    const actual = await bind(entry.path);
    assert.equal(actual.sha256, entry.sha256, entry.path);
    assert.equal(String(actual.bytes), entry.bytes, entry.path);
    originals.push({ capture: name, ...actual, terminalNewline: entry.terminalNewline,
      provenance: "lossless raw input bytes captured before preparation; no reconstruction or normalization" });
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
const coverage = [];
for (const [file, expected] of [["specs.log", 167], ["forks-01.log", 142]] as const) {
  const text = await readFile(resolve(here, file), "utf8");
  assert(!/^\[FAIL/m.test(text), file);
  assert(/tests passed, 0 failed, 0 skipped/.test(text), file);
  const tests = text.split("\n").filter(line => line.startsWith("[PASS]"));
  assert.equal(tests.length, expected, file);
  coverage.push({ file, count: tests.length, tests });
}
const operator = await readFile(resolve(here, "operator-tests-final-02.log"), "utf8");
assert(operator.includes("91 pass") && operator.includes("0 fail"));
assert.equal(await readFile(resolve(here, "types-final-02.log"), "utf8"), "");
assert((await readFile(resolve(here, "cli-03.log"), "utf8")).includes('"status":"bounded-rehearsal-complete"'));
const capture = z.object({ status: z.literal("producer-capture-closed"), blocks: z.number() })
  .parse(JSON.parse(required((await readFile(wirePath, "utf8")).trim().split("\n").at(-1))));
const cleanup = await json(resolve(runtime, "cleanup.json"));
console.log(JSON.stringify({
  status: "bounded-claimed-sy-producer-audit-pass", runtime, sourceManifest: manifest,
  preserved, originalInputCaptures: originals, bound, signed, er, ed, held, claimed,
  lifecycle: life, ...wire, coverage, capture, cleanup,
  summary: { sourcePaths: manifest.source.length, productionContractEdits: 0,
    artifacts: bound.artifacts.length, runtimeCaptures: bound.captures.length,
    originalInputReferences: originals.length, originalInputUniquePaths: new Set(originals.map(o => o.path)).size,
    originalRawSigned: signed.signed.length, reconstructedSigned: signed.reconstructed.length,
    canonicalResumes: signed.resumes.length, httpBodies: wire.wire.responses,
    canonicalReceipts: wire.wire.receipts, blocks: capture.blocks, claimedOriginals: claimed.originals.length,
    uniqueEligibleClaims: claimed.uniqueMembers, actualRegistrationGas: signed.registrationReceipt.gasUsed,
    preparedInputDrift: bound.producerInputReconstruction.length },
}, (_, value: unknown) => typeof value === "bigint" ? String(value) : value, 2));
