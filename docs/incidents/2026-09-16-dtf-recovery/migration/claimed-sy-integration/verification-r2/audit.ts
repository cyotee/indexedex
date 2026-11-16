import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "ethers";
import { z } from "zod";
import { bindings } from "../implementation/probe/bindings.js";
import { receipts } from "../implementation/probe/receipts.js";
import { economics } from "../implementation/probe/economics.js";
import { edEconomics } from "../implementation/probe/ed-economics.js";
import { heldEconomics } from "../implementation/probe/held-economics.js";
import { claimedEconomics } from "../implementation/probe/claimed-economics.js";
import { lifecycle } from "../implementation/probe/lifecycle.js";
import { wireAndConstructor } from "../implementation/probe/wire-constructor.js";
import { bind, binding, canonical, files, json, required, sha } from "../implementation/probe/evidence.js";
import { executionManifest } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { rawChecks } from "./raw-checks.js";

// Reexecute the inspected producer algorithms, then add independent canonical
// transport, exact transaction fields and directly observed historical books.
// No producer PASS flag is an input to the verdict.
const here = dirname(fileURLToPath(import.meta.url));
const implementation = resolve(here, "../implementation");
const fresh = required(process.argv[2]);
const seal = z.object({
  sourceAndPreservation: z.array(binding.extend({ mode: z.number().optional() })),
  membership: z.object({ files: z.array(binding.extend({ mode: z.number() })), count: z.number() }).passthrough(),
}).passthrough().parse(await json(resolve(implementation, "seal.json")));
const preserved = [];
for (const entry of seal.sourceAndPreservation) {
  const actual = await bind(entry.path);
  assert.equal(actual.bytes, entry.bytes, entry.path);
  assert.equal(actual.sha256, entry.sha256, entry.path);
  if (entry.mode !== undefined) assert.equal(actual.mode, entry.mode, entry.path);
  preserved.push(actual);
}
const membership = [];
for (const entry of seal.membership.files) {
  const actual = await bind(resolve(implementation, entry.path));
  assert.equal(actual.bytes, entry.bytes, entry.path);
  assert.equal(actual.sha256, entry.sha256, entry.path);
  assert.equal(actual.mode, entry.mode, entry.path);
  membership.push(actual);
}
assert.equal(membership.length, seal.membership.count);
assert.deepEqual((await files(implementation)).filter(p => p !== resolve(implementation, "seal.json")),
  membership.map(e => e.path).sort());
const results = [];
for (const [label, runtime, wirePath] of [
  ["producer", resolve(implementation, "runtime-03/rehearsal-1794496225193"), resolve(implementation, "rpc-03.ndjson")],
  ["independent", fresh, resolve(here, "fresh-wire.ndjson")],
] as const) {
  const originalInputs = [];
  for (const name of ["original-input-bytes.json", "replacement-original-input-bytes.json"]) {
    const capture = z.object({ records: z.array(z.object({
      path: z.string(), bytes: z.string(), sha256: z.string(),
      rawBase64: z.string(), terminalNewline: z.boolean(),
    }).passthrough()) }).parse(await json(resolve(runtime, name)));
    for (const entry of capture.records) {
      const bytes = Buffer.from(entry.rawBase64, "base64");
      assert.equal(bytes.toString("base64"), entry.rawBase64);
      assert.equal(String(bytes.length), entry.bytes);
      assert.equal(sha(bytes), entry.sha256);
      assert.equal(bytes.at(-1) === 10, entry.terminalNewline);
      const current = await bind(entry.path);
      assert.equal(current.sha256, entry.sha256);
      originalInputs.push({ capture: name, ...current, terminalNewline: entry.terminalNewline });
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
  const manifest = executionManifest.parse(await json(resolve(runtime, "post-capture.json")));
  assert(manifest.deployment);
  const packageArtifact = z.object({ abi: z.array(z.unknown()) }).passthrough()
    .parse(await json(resolve("out/IUniswapV4DetfMigrationDFPkg.sol/IUniswapV4DetfMigrationDFPkg.json")));
  const pkg = new Interface(JSON.stringify(packageArtifact.abi));
  const deployment = required(signed.signed.find(s => s.hash === signed.registrationReceipt.transactionHash));
  assert.equal(deployment.data, pkg.encodeFunctionData("deployVault", [manifest.deployment]));
  const independent = label === "independent" ? await rawChecks({
    wire: wirePath, books: resolve(here, "independent-books.ndjson"), signed,
    staking: required(bound.captures.find(c => "role" in c && c.role === "rebasingClaimToken")).address,
    bond: required(bound.captures.find(c => "role" in c && c.role === "bondNftVault")).address,
  }) : null;
  results.push({ label, runtime, originalInputs, bound, signed, er, ed, held, claimed,
    lifecycle: life, ...wire, independent,
    summary: {
      artifacts: bound.artifacts.length, runtimeCaptures: bound.captures.length,
      originalInputReferences: originalInputs.length,
      originalInputUniquePaths: new Set(originalInputs.map(e => e.path)).size,
      preparedInputDrift: bound.producerInputReconstruction.length,
      originalRawSigned: signed.signed.length, reconstructedSigned: signed.reconstructed.length,
      canonicalResumes: signed.resumes.length, canonicalReceipts: wire.wire.receipts,
      httpBodies: wire.wire.responses, claimedOriginals: claimed.originals.length,
      actualRegistrationGas: signed.registrationReceipt.gasUsed,
    },
  });
}
const coverage = [];
for (const [name, count] of [["specs.log", 167], ["forks.log", 142]] as const) {
  const text = await readFile(resolve(here, name), "utf8");
  const tests = text.split("\n").filter(line => line.startsWith("[PASS]"));
  assert.equal(tests.length, count);
  assert(!/^\[FAIL/m.test(text));
  assert(text.includes(`${count} tests passed, 0 failed, 0 skipped`));
  coverage.push({ name, count, tests });
}
const operator = await readFile(resolve(here, "operator-tests.log"), "utf8");
assert(operator.includes("91 pass") && operator.includes("0 fail"));
assert.equal(await readFile(resolve(here, "types.log"), "utf8"), "");
assert((await readFile(resolve(here, "cli.log"), "utf8")).includes('"status":"bounded-rehearsal-complete"'));
assert((await readFile(resolve(here, "stages.log"), "utf8")).includes("Compiler run successful!"));
console.log(JSON.stringify({ status: "independent-claimed-sy-audit-pass",
  producerSeal: await bind(resolve(implementation, "seal.json")), preserved, membership, results, coverage,
  qualifications: [
    "Core evidence algorithms are inspected read-only producer algorithms, not claimed as unrelated implementations.",
    "Independent rawChecks and observe scripts bind actual fresh HTTP headers, transactions, receipts, logs and historical economic books.",
    "Historical originals, zero delivery and semantic alias reconciliation remain owner-reviewed synthetic fixture inputs.",
    "Identical deterministic source transaction hashes are not independence evidence; fresh stopped-node execution and captures are retained.",
    "No operational award, full raw category, full plan, target gas or public acceptance.",
  ],
}, (_, value: unknown) => typeof value === "bigint" ? String(value) : value, 2));
