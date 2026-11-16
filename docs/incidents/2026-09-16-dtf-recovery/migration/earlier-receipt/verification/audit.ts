import assert from "node:assert/strict";
import { resolve } from "node:path";
import { readFile } from "node:fs/promises";
import { bindings } from "./bindings.js";
import { receipts } from "./receipts.js";
import { economics } from "./economics.js";
import { lifecycle } from "./lifecycle.js";
import { bind, required, root, save } from "./evidence.js";

const runtime = resolve(required(process.argv[2]));
const output = resolve(required(process.argv[3]));
const runtimeBindings = await bindings(runtime);
const signedReceipts = await receipts(runtime);
const economic = await economics(runtime, signedReceipts);
const life = await lifecycle(runtime, signedReceipts);
const checks = [];
const directory = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/verification");
for (const name of ["execute.sh", "execution.log", "build.log", "specs.log", "forks.log",
  "stages.log", "types.log", "operator-tests.log", "cli.log"]) {
  checks.push(await bind(resolve(directory, name)));
}
const transcript = await readFile(resolve(directory, "execution.log"), "utf8");
for (const gate of ["build", "specs", "forks", "stages", "types", "operator-tests", "cli", "empty-runtime-parent-cleanup"]) {
  assert(transcript.split("\n").includes(`PASS ${gate}`), gate);
}
const coverage = [];
for (const name of ["specs", "forks"]) {
  const text = await readFile(resolve(directory, `${name}.log`), "utf8");
  assert(!/^\[FAIL/m.test(text));
  assert(/tests passed, 0 failed, 0 skipped/.test(text));
  const tests = text.split("\n").filter(l => l.startsWith("[PASS]"));
  coverage.push({ gate: name, tests, count: tests.length });
}
await save(output, { runtime, checks, coverage, runtimeBindings, signedReceipts, economic, lifecycle: life });
console.log(JSON.stringify({ status: "independent-audit-pass", runtime, output,
  preserved: runtimeBindings.preserved.length, artifacts: runtimeBindings.artifacts.length,
  compilerSources: runtimeBindings.compilerSources.length, rawSigned: signedReceipts.signed.length,
  reconstructedSigned: signedReceipts.reconstructed.length, resumes: signedReceipts.resumes.length,
  coverage: coverage.map(c => ({ gate: c.gate, count: c.count })) }));
