import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { z } from "zod";
import { bindings } from "../implementation/bindings.js";
import { receipts } from "../implementation/receipts.js";
import { economics } from "../implementation/economics.js";
import { edEconomics } from "../implementation/ed-economics.js";
import { heldEconomics } from "../implementation/held-economics.js";
import { lifecycle } from "../implementation/lifecycle.js";
import { wireAndConstructor } from "../implementation/wire-constructor.js";
import { bind, binding, files, json, required, root, sha } from "../implementation/evidence.js";
import { rawChecks } from "./raw-checks.js";

const here = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp");
const owned = resolve(here, "verification");
const modeBinding = binding.extend({ mode: z.number() });
const source = z.object({
  base: z.literal("3ec0912bafebf9c0aa66770a72f04501e5c11865"),
  branch: z.literal("work/dtf-migration-phase-21-held-se-lp"),
  source: z.array(modeBinding),
  immutable: z.array(modeBinding),
  authority: z.array(modeBinding),
  parentPreserved: z.array(modeBinding),
}).passthrough().parse(await json(resolve(here, "implementation/source-manifest.json")));
const producerSeal = z.object({
  ownedFiles: z.array(modeBinding),
  admissions: z.array(binding.extend({ expected: z.string() })),
}).passthrough().parse(await json(resolve(here, "implementation/seal.json")));
const preservation = [];
for (const entry of [...source.source, ...source.immutable, ...source.authority,
  ...source.parentPreserved, ...producerSeal.ownedFiles]) {
  const actual = await bind(entry.path);
  assert.deepEqual(actual, entry);
  preservation.push(actual);
}
assert.equal(source.source.length, 35);
assert.equal(source.immutable.length, 1237);
assert.equal(source.parentPreserved.length, 1386);
const members = await files(resolve(here, "implementation"));
assert.deepEqual(members, [...producerSeal.ownedFiles.map(row => row.path),
  resolve(here, "implementation/seal.json")].sort());
const admissions = [];
for (const entry of producerSeal.admissions) {
  const actual = await bind(entry.path);
  assert.equal(actual.sha256, entry.expected);
  assert.equal(actual.bytes, entry.bytes);
  admissions.push(actual);
}
const captures = z.object({
  runtime: z.string(),
  records: z.array(binding.extend({ captured: z.string(), terminalNewline: z.boolean() })),
}).passthrough().parse(await json(resolve(here, "implementation/captured-inputs.json")));
const rawCaptures = [];
for (const entry of captures.records) {
  const encoded = (await readFile(entry.captured, "utf8")).trim();
  const bytes = Buffer.from(encoded, "base64");
  assert.equal(bytes.toString("base64"), encoded);
  assert.equal(bytes.length, entry.bytes);
  assert.equal(sha(bytes), entry.sha256);
  assert.equal(bytes.at(-1) === 10, entry.terminalNewline);
  rawCaptures.push({ ...entry, encodedIdentity: await bind(entry.captured) });
}
const fresh = required((await files(resolve(owned, "runtime-01")))
  .find(path => path.endsWith("/cleanup.json"))).replace(/\/cleanup.json$/, "");
const results = [];
for (const [label, runtime, wirePath] of [
  ["producer", captures.runtime, resolve(here, "implementation/rpc.ndjson")],
  ["independent", fresh, resolve(owned, "fresh-wire.ndjson")],
] as const) {
  const bound = await bindings(runtime);
  const signed = await receipts(runtime);
  const er = await economics(runtime, signed);
  const ed = await edEconomics(runtime, signed);
  const held = await heldEconomics(runtime, signed);
  const life = await lifecycle(runtime, signed);
  const wire = await wireAndConstructor({ runtime, wirePath, bound, signed });
  const independent = await rawChecks({ runtime, wirePath, signed, held });
  results.push({ label, runtime, wireFile: await bind(wirePath), bound, signed, er, ed, held,
    lifecycle: life, ...wire, independent });
}
const checks = [];
for (const [name, count] of [["specs", 167], ["forks", 139]] as const) {
  const path = resolve(owned, `${name}.log`);
  const text = await readFile(path, "utf8");
  const tests = text.split("\n").filter(line => line.startsWith("[PASS]"));
  assert.equal(tests.length, count);
  assert(!text.includes("[FAIL"));
  assert(text.includes(`${count} tests passed, 0 failed, 0 skipped`));
  checks.push({ name, tests, identity: await bind(path) });
}
const operatorPath = resolve(owned, "operator-tests.log");
const operator = await readFile(operatorPath, "utf8");
assert(operator.includes("88 pass") && operator.includes("0 fail") && operator.includes("across 10 files"));
assert.equal(await readFile(resolve(owned, "types.log"), "utf8"), "");
assert((await readFile(resolve(owned, "cli.log"), "utf8")).includes('"status":"bounded-rehearsal-complete"'));
for (const name of ["build", "stages", "types", "operator-tests", "cli"]) {
  checks.push({ name, tests: [], identity: await bind(resolve(owned, `${name}.log`)) });
}
console.log(JSON.stringify({
  schema: "independent-three-source-stopped-candidate-verification/1",
  preservation, admissions, producerSeal: await bind(resolve(here, "implementation/seal.json")),
  sourceManifest: await bind(resolve(here, "implementation/source-manifest.json")),
  rawCaptures, results, checks,
  reuse: "Inspected read-only producer reconcilers reexecuted for both runs; raw-checks.ts independently checks transport IDs, block/log identity, donor canonical fields/storage deltas, all raw resume fields, native Q/C and allowance events, and actual instance deployment arguments.",
  summary: results.map(result => ({
    label: result.label, artifacts: result.bound.artifacts.length, runtimeCaptures: result.bound.captures.length,
    sourceHashes: result.bound.compilerSources.length, originalRawSigned: result.signed.signed.length,
    reconstructedSigned: result.signed.reconstructed.length, resumes: result.signed.resumes.length,
    rawResponses: result.independent.responses, blocks: result.independent.blocks,
    canonicalTransactions: result.independent.transactions, canonicalReceipts: result.independent.receipts,
    authenticatedWire: result.wire.fieldProof.filter(row => row.signer !== null).length,
    syntheticWire: result.wire.fieldProof.filter(row => row.signer === null).length,
    currentInputDrift: result.bound.producerInputReconstruction.length,
    registrationGas: result.signed.registrationReceipt.gasUsed,
    held: result.independent.recurrences.map(row => ({ source: row.source, delivered: row.delivered,
      hashes: row.rows.map(step => step.hash) })),
  })),
  status: "independent-audit-pass",
}, (_key, value: unknown) => typeof value === "bigint" ? value.toString() : value, 2));
