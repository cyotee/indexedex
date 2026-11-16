import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { z } from "zod";
import { fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { bundleManifest, walkReferences } from "../../../../../../scripts/recovery/dtf-migration/bundle-files.js";
import { bundleReference, sha256, uint } from "../../../../../../scripts/recovery/dtf-migration/schema.js";

const directory = fileURLToPath(new URL(".", import.meta.url));
const reportSchema = z.object({
  fixtures: z.object({
    template: z.string(), manifest: bundleManifest,
    files: z.array(z.object({
      path: z.string(), originalPath: z.string(), sha256, bytes: uint, rawBase64: z.string(),
    }).strict()),
  }).strict(),
  comparisons: z.array(z.object({
    freshDomainHash: sha256,
    contexts: z.array(z.object({
      stage: z.enum(["configure", "independent-issue"]), intent: bundleReference,
      originalDomainHash: sha256, signedDomainHash: sha256,
    }).strict()),
    byteComparison: z.array(z.object({ originalPath: z.string(), sha256, bytes: uint, identical: z.literal(true) }).strict()),
  }).strict()).length(2),
  unmet: z.array(z.string()),
}).passthrough();
const reportRaw = await readFile(join(directory, "portable-integrity.json"));
const report = reportSchema.parse(JSON.parse(reportRaw.toString()));
const files = new Map(report.fixtures.files.map((item) => [item.originalPath, item]));
assert.equal(files.size, report.fixtures.files.length);
assert.deepEqual(report.fixtures.files.map(({ rawBase64: _raw, ...item }) => item), report.fixtures.manifest.files);
const template = Buffer.from(report.fixtures.template, "base64");
assert.equal(fingerprint(template), report.fixtures.manifest.template.sha256);
assert.equal(String(template.length), report.fixtures.manifest.template.bytes);
const rawFiles = new Map<string, Buffer>();
for (const item of files.values()) {
  const raw = Buffer.from(item.rawBase64, "base64");
  assert.equal(fingerprint(raw), item.sha256);
  assert.equal(String(raw.length), item.bytes);
  rawFiles.set(item.originalPath, raw);
}
let referenceReads = 0;
const load = async (ref: { readonly path: string }) => {
  const raw = rawFiles.get(ref.path);
  assert.ok(raw, `Missing transitive original: ${ref.path}`);
  referenceReads++;
  return raw;
};
await walkReferences(JSON.parse(template.toString()), load);
for (const raw of rawFiles.values()) await walkReferences(JSON.parse(raw.toString()), load);
const expectedBytes = report.fixtures.files.map(({ originalPath, sha256, bytes }) => ({ originalPath, sha256, bytes, identical: true }));
const first = report.comparisons[0];
const second = report.comparisons[1];
assert.ok(first && second);
assert.notEqual(first.freshDomainHash, second.freshDomainHash);
for (const location of report.comparisons) {
  assert.deepEqual(location.byteComparison, expectedBytes);
  assert.equal(location.contexts.length, 4);
  assert.equal(new Set(location.contexts.map((c) => c.intent.path)).size, 4);
  assert.equal(location.contexts.filter((c) => c.stage === "configure").length, 3);
  assert.equal(location.contexts.filter((c) => c.stage === "independent-issue").length, 1);
  for (const context of location.contexts) assert.equal(context.signedDomainHash, context.originalDomainHash);
}
assert.deepEqual(first.contexts, second.contexts);
assert.deepEqual(report.unmet, ["task 10 real portable mode current-chain proof"]);
const result = z.object({ exit: z.literal(0), sourcesUnchanged: z.literal(true), logSha256: sha256 }).passthrough()
  .parse(JSON.parse(await readFile(join(directory, "final.result.json"), "utf8")));
const log = await readFile(join(directory, "final.log"));
assert.equal(fingerprint(log), result.logSha256);
assert.match(log.toString(), /\n\s*0 fail\b/);
const tamper = await readFile(join(directory, "tamper-rejections.log"), "utf8");
const labels = ["contained-length", "contained-traversal", "contained-duplicate", "contained-missing-reference",
  "contained-extra", "contained-data-link", "a-book", "b-input", "a-issuance-intent", "receipt",
  "original-execution", "original-journal", "historical-domainHash-with-rehashed-FileRefs", "omitted-old-SY-row",
  "cyclic-reference", "copy-active-checkpoint", "move-active-checkpoint", "relocated-network", "relocated-purpose",
  "relocated-facet", "relocated-v1", "missing-historical-executionManifest", "missing-historical-journalDomain"];
for (const label of labels) assert.equal(tamper.split("\n").filter((line) => line.startsWith(label + ":")).length, 1, label);
const audit = { status: "pass", taskComplete: false, rawFiles: files.size, transitiveReferenceReads: referenceReads,
  freshLocations: report.comparisons.length, historicalContextsPerLocation: 4, tamperCases: labels.length,
  reportSha256: fingerprint(reportRaw), finalLogSha256: fingerprint(log), tamperLogSha256: fingerprint(tamper),
  unmet: report.unmet, qualification: "Mechanical integrity of synthetic wire evidence; no task 10 chain proof." };
await writeFile(join(directory, "audit.json"), JSON.stringify(audit, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify(audit));
