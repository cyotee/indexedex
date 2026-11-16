import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { bind, binding, files, json, root, save } from "./evidence.js";

const here = dirname(fileURLToPath(import.meta.url));
const final = z.object({ runtimeBindings: z.object({
  preserved: z.array(binding.extend({ mode: z.number() })),
  artifacts: z.array(binding), stages: z.array(binding), preparedInputs: z.array(binding), producerSeal: binding,
}).passthrough() }).passthrough().parse(await json(resolve(here, "audit-fresh-final.json")));
for (const expected of [...final.runtimeBindings.preserved, ...final.runtimeBindings.artifacts,
  ...final.runtimeBindings.stages, ...final.runtimeBindings.preparedInputs, final.runtimeBindings.producerSeal]) {
  const actual = await bind(expected.path);
  assert.equal(actual.bytes, expected.bytes, expected.path);
  assert.equal(actual.sha256, expected.sha256, expected.path);
  if ("mode" in expected) assert.equal(actual.mode, expected.mode, expected.path);
}
assert(!existsSync(resolve(root, ".omo-runtime/dtf-migration-earlier-receipt")));
const cleanup = await readFile(resolve(here, "cleanup.log"), "utf8");
for (const expected of ["PROCESS_EXIT=1", "LISTENER_EXIT=1", "RUNTIME_PARENT_ABSENT_EXIT=0",
  "WHITESPACE_EXIT=0", "STAGED_QUERY_EXIT=0", "acdbe319f3a20c3af6bea594c62461b6c7988717"]) assert(cleanup.includes(expected));
const evidence = [];
for (const path of await files(here)) {
  assert.notEqual(path, resolve(here, "seal.json"));
  evidence.push(await bind(path));
}
const sealed = { disposition: "confirmed", scope: "bounded ER custody and frozen credit; liquidation blocked",
  base: "acdbe319f3a20c3af6bea594c62461b6c7988717", producerSeal: final.runtimeBindings.producerSeal,
  report: await bind(resolve(here, "report.md")), evidence, selfExclusions: ["seal.json"], noPendingOperation: true };
await save(resolve(here, "seal.json"), sealed);
console.log(JSON.stringify({ status: "verification-sealed", evidence: evidence.length, report: sealed.report,
  seal: await bind(resolve(here, "seal.json")), noPendingOperation: true }));
