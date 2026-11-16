import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { resolve, basename } from "node:path";
import { z } from "zod";
import { bindings } from "./bindings.js";
import { receipts } from "./receipts.js";
import { economics } from "./economics.js";
import { edEconomics } from "./ed-economics.js";
import { lifecycle } from "./lifecycle.js";
import { bind, binding, files, json, required, root, save } from "./evidence.js";

const here = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation");
const capture = z.object({ runtime: z.string() }).passthrough().parse(await json(resolve(here, "captured-inputs.json")));
const runtime = capture.runtime;
const runtimeBindings = await bindings(runtime);
const signedReceipts = await receipts(runtime);
const er = await economics(runtime, signedReceipts);
const ed = await edEconomics(runtime, signedReceipts);
const life = await lifecycle(runtime, signedReceipts);
const parent = z.object({ parentPreserved: z.array(binding) }).passthrough()
  .parse(await json(resolve(here, "source-manifest.json")));
for (const original of parent.parentPreserved) {
  const actual = await bind(original.path);
  assert.equal(actual.sha256, original.sha256, original.path); assert.equal(actual.bytes, original.bytes, original.path);
}
const checks = [];
const coverage = [];
for (const [file, expected] of [["specs-01.log", 146], ["forks-final.log", 109]] as const) {
  const name = required(file);
  const text = await readFile(resolve(here, name), "utf8");
  assert(!/^\[FAIL/m.test(text), name);
  assert(/tests passed, 0 failed, 0 skipped/.test(text), name);
  const tests = text.split("\n").filter(line => line.startsWith("[PASS]"));
  assert.equal(tests.length, expected, name);
  coverage.push({ path: name, count: tests.length, tests });
}
const operator = await readFile(resolve(here, "operator-tests-final.log"), "utf8");
assert(operator.includes("76 pass") && operator.includes("0 fail"));
assert((await readFile(resolve(here, "cli-01.log"), "utf8")).includes('"status":"bounded-rehearsal-complete"'));
for (const name of ["build-01.log", "specs-01.log", "forks-01.log", "forks-final.log",
  "stages-01.log", "types-01.log", "types-final.log", "operator-tests-final.log", "cli-01.log",
  "contracts-check.sh", "operator-check.sh"]) checks.push(await bind(resolve(here, name)));
const cleanup = z.object({ node: z.literal("exited"), runtime: z.literal("removed"),
  checkpoint: z.string(), pid: z.number() }).passthrough().parse(await json(resolve(runtime, "cleanup.json")));
await assert.rejects(stat(cleanup.checkpoint), { code: "ENOENT" });
await assert.rejects(stat(resolve(root, ".omo-runtime/dtf-migration-earlier-liquid")), { code: "ENOENT" });
const exec = promisify(execFile);
await assert.rejects(exec("lsof", ["-nP", "-iTCP:18569", "-sTCP:LISTEN"]), { code: 1 });
await assert.rejects(exec("ps", ["-p", String(cleanup.pid), "-o", "pid="]), { code: 1 });
const result = { schema: "ed-bounded-implementation-audit/1", runtime, checks, coverage,
  runtimeBindings, signedReceipts, er, ed, lifecycle: life, parentEvidencePreserved: parent.parentPreserved.length, cleanup };
const sealing = process.argv.includes("--seal");
if (sealing) {
  const previous = z.object({ runtimeBindings: z.object({ preserved: z.array(binding) }).passthrough() })
    .passthrough().parse(await json(resolve(here, "audit.json")));
  const current = runtimeBindings.preserved.map(row => ({ path: row.path, bytes: row.bytes, sha256: row.sha256 }));
  assert.deepEqual(current, previous.runtimeBindings.preserved);
  const evidence = [];
  for (const path of await files(here)) {
    if (basename(path) === "seal.json" || basename(path) === "seal.log") continue;
    evidence.push(await bind(path));
  }
  await save(resolve(here, "seal.json"), {
    ...result, evidence, report: await bind(resolve(here, "report.md")),
    sourceModificationsStopped: true, noPendingOperation: true, stopped: true,
    disposition: "validated stopped bounded ED custody-and-credit candidate; conversion blocked",
    selfExclusions: ["seal.json", "seal.log"],
  });
} else await save(resolve(here, process.argv.includes("--final") ? "audit-final.json" : "audit.json"), result);
console.log(JSON.stringify({ status: "producer-audit-pass", seal: sealing, source: 32,
  artifacts: runtimeBindings.artifacts.length, captures: runtimeBindings.captures.length,
  rawSigned: signedReceipts.signed.length, reconstructedSigned: signedReceipts.reconstructed.length,
  resumes: signedReceipts.resumes.length, edBonds: ed.rows.length,
  registrationGas: signedReceipts.registrationReceipt.gasUsed,
  inputDrift: runtimeBindings.producerInputReconstruction.length,
  migrationArtifacts: runtimeBindings.artifacts.filter(row => row.name.includes("Migration"))
    .map(row => ({ name: row.name, runtimeBytes: row.bytesRuntime })),
  coverage: coverage.map(({ path, count }) => ({ path, count })) }));
