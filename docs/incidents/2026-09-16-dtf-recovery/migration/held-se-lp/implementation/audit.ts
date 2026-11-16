import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import { resolve } from "node:path";
import { z } from "zod";
import { bindings } from "./bindings.js";
import { receipts } from "./receipts.js";
import { economics } from "./economics.js";
import { edEconomics } from "./ed-economics.js";
import { heldEconomics } from "./held-economics.js";
import { lifecycle } from "./lifecycle.js";
import { wireAndConstructor } from "./wire-constructor.js";
import { bind, binding, json, root, sha } from "./evidence.js";

const here = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp/implementation");
const capture = z.object({
  runtime: z.string(), records: z.array(binding.extend({ captured: z.string(), terminalNewline: z.boolean() })),
}).passthrough().parse(await json(resolve(here, "captured-inputs.json")));
const runtime = capture.runtime;
const sourceManifest = z.object({
  base: z.literal("3ec0912bafebf9c0aa66770a72f04501e5c11865"),
  branch: z.literal("work/dtf-migration-phase-21-held-se-lp"),
  source: z.array(binding.extend({ mode: z.number() })),
  immutable: z.array(binding.extend({ mode: z.number() })),
  authority: z.array(binding.extend({ mode: z.number() })),
  parentPreserved: z.array(binding.extend({ mode: z.number() })),
  sourceModificationsStopped: z.literal(true),
}).passthrough().parse(await json(resolve(here, "source-manifest.json")));
for (const entry of [...sourceManifest.source, ...sourceManifest.immutable,
  ...sourceManifest.authority, ...sourceManifest.parentPreserved]) {
  const actual = await bind(entry.path);
  assert.equal(actual.sha256, entry.sha256, entry.path);
  assert.equal(actual.bytes, entry.bytes, entry.path);
  assert.equal(actual.mode, entry.mode, entry.path);
}
const originalCaptures = [];
for (const entry of capture.records) {
  const encoded = (await readFile(entry.captured, "utf8")).trim();
  const decoded = Buffer.from(encoded, "base64");
  assert.equal(decoded.toString("base64"), encoded);
  assert.equal(decoded.length, entry.bytes);
  assert.equal(sha(decoded), entry.sha256);
  assert.equal(decoded.at(-1) === 10, entry.terminalNewline);
  originalCaptures.push({ ...entry, encodedFile: await bind(entry.captured),
    qualification: "lossless original-byte base64 capture, not offline artifact reconstruction" });
}
const bound = await bindings(runtime);
const signed = await receipts(runtime);
const er = await economics(runtime, signed);
const ed = await edEconomics(runtime, signed);
const held = await heldEconomics(runtime, signed);
const life = await lifecycle(runtime, signed);
const wire = await wireAndConstructor({ runtime, wirePath: resolve(here, "rpc.ndjson"), bound, signed });
const coverage = [];
for (const [file, expected] of [["specs-02.log", 167], ["forks-01.log", 139]] as const) {
  const text = await readFile(resolve(here, file), "utf8");
  assert(!/^\[FAIL/m.test(text), file);
  assert(/tests passed, 0 failed, 0 skipped/.test(text), file);
  const tests = text.split("\n").filter(line => line.startsWith("[PASS]"));
  assert.equal(tests.length, expected, file);
  coverage.push({ file, count: tests.length, tests });
}
const operator = await readFile(resolve(here, "operator-tests-final-02.log"), "utf8");
assert(operator.includes("88 pass") && operator.includes("0 fail"));
assert((await readFile(resolve(here, "cli-01.log"), "utf8")).includes('"status":"bounded-rehearsal-complete"'));
for (const file of ["types-01.log", "probe-types-01.log"]) assert.equal(await readFile(resolve(here, file), "utf8"), "");
const cleanup = z.object({
  node: z.literal("exited"), runtime: z.literal("removed"), checkpoint: z.string(), pid: z.number(),
}).passthrough().parse(await json(resolve(runtime, "cleanup.json")));
await assert.rejects(stat(cleanup.checkpoint), { code: "ENOENT" });
await assert.rejects(stat(resolve(root, ".omo-runtime/dtf-migration-held-se-lp")), { code: "ENOENT" });
const cleanupLog = await readFile(resolve(here, "cleanup-final.log"), "utf8");
for (const sentinel of ["NO_18571_LISTENER", "NO_OWNED_PID", "CHECKPOINT_ABSENT",
  "OWNED_RUNTIME_PARENT_ABSENT", "WHITESPACE_PASS"]) assert(cleanupLog.includes(sentinel));
const checks = [];
for (const file of ["build-01.log", "specs-01.log", "specs-02.log", "forks-01.log",
  "stages-01.log", "stages-02.log", "types-01.log", "operator-tests-final.log",
  "operator-tests-final-02.log", "probe-types-01.log", "cli-01.log", "cleanup-final.log"]) {
  checks.push(await bind(resolve(here, file)));
}
console.log(JSON.stringify({
  schema: "three-fixed-native18-custody-credit-producer-audit/1", runtime,
  sourceManifest, originalCaptures, bound, signed, er, ed, held, lifecycle: life, ...wire, coverage, checks, cleanup,
  summary: {
    sourcePaths: sourceManifest.source.length, artifacts: bound.artifacts.length, captures: bound.captures.length,
    rawSigned: signed.signed.length, reconstructedSigned: signed.reconstructed.length, resumes: signed.resumes.length,
    registrationGas: signed.registrationReceipt.gasUsed, inputDrift: bound.producerInputReconstruction.length,
    heldSources: held.configuredRows.length, heldBonds: held.configuredRows.reduce((sum, row) => sum + row.rows.length, 0),
    httpBodies: wire.wire.responses, canonicalReceipts: wire.wire.receipts,
  },
  status: "producer-audit-pass",
}, (_, value: unknown) => typeof value === "bigint" ? value.toString() : value, 2));
