import assert from "node:assert/strict";
import { access, appendFile, cp, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { authorityInput, authorityRoles, exportBundle, loadSavedBundle } from "../../../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { bundleManifest, readBundle, verifyBytes, walkReferences } from "../../../../../../../../scripts/recovery/dtf-migration/bundle-files.js";
import { materializeBundle } from "../../../../../../../../scripts/recovery/dtf-migration/bundle-materialize.js";
import { canonical, fingerprint } from "../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { acceptedConfiguration, source } from "../../../../../../../../scripts/recovery/dtf-migration/schema.js";
import { save } from "../../../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const root = dirname(fileURLToPath(import.meta.url));
const native = join(root, "native");
const inputRaw = await readFile(join(native, "authorities-input.json"));
const input = authorityInput.parse(JSON.parse(inputRaw.toString("utf8")));
assert(input.rehearsalFundingEvidence);
const funding = input.rehearsalFundingEvidence;
const expected = await Promise.all([...input.sources, funding].map(async (ref) => {
  const raw = await readFile(join(native, ref.path));
  verifyBytes(raw, ref);
  return { ref, raw };
}));
const exported = join(root, "exported");
const exportBundleFile = await readBundle(join(exported, "bundle.json"));
assert.deepEqual(exportBundleFile.template, inputRaw);
assert.equal(exportBundleFile.manifest.files.length, 23);
await rename(native, `${native}.unavailable`);
await assert.rejects(access(native), { code: "ENOENT" });
const comparisons = [];
for (const name of ["relocated-a", "relocated-b"]) {
  const directory = join(root, name);
  await cp(exported, directory, { recursive: true, errorOnExist: true, force: false });
  const path = join(directory, "bundle.json");
  const loaded = await loadSavedBundle(path);
  const materialized = await materializeBundle(path, join(root, `${name}-materialized`));
  assert.equal(loaded.kind, "authorities");
  assert.equal(materialized.kind, "authorities");
  if (loaded.kind !== "authorities" || materialized.kind !== "authorities") throw new TypeError("expected authorities");
  assert.equal(loaded.sources.length, 22);
  assert.deepEqual(loaded.sources.map((s) => s.id).sort(), [...authorityRoles].sort());
  assert.deepEqual(materialized.sources, loaded.sources);
  assert.deepEqual(materialized.rehearsalFundingEvidence, loaded.rehearsalFundingEvidence);
  assert(loaded.rehearsalFundingEvidence);
  const physical = [...loaded.sources, loaded.rehearsalFundingEvidence];
  const bytes = [];
  for (const original of expected) {
    const found = physical.find((s) => s.id === original.ref.id);
    assert(found);
    assert(found.path.startsWith(`${directory}/data/`));
    const raw = await readFile(found.path);
    assert.deepEqual(raw, original.raw);
    const { path: _originalPath, ...originalIdentity } = original.ref;
    const { path: _physicalPath, ...physicalIdentity } = found;
    assert.deepEqual(physicalIdentity, originalIdentity);
    bytes.push({ id: found.id, path: found.path, sha256: fingerprint(raw), bytes: String(raw.length), identical: true });
  }
  assert(loaded.reads.every((r) => r.path.startsWith(`${directory}/`)));
  comparisons.push({ location: directory, authorityCount: 22, bytes, reads: loaded.reads, bundle: loaded.reference });
}

const negatives: { readonly label: string; readonly name: string; readonly message: string }[] = [];
async function reject(label: string, action: () => Promise<unknown>, expectedError: RegExp) {
  const error: unknown = await action().then(() => null, (error: unknown) => error);
  assert(error instanceof Error, `${label} must reject`);
  assert.match(error.message, expectedError);
  negatives.push({ label, name: error.name, message: error.message });
}
await mkdir(join(root, "negative"));
for (const corruption of ["tamper", "missing-declared", "missing-physical", "extra", "unreferenced",
  "forged-reference", "forged-id", "wrong-purpose", "wrong-size"] as const) {
  const directory = join(root, "negative", corruption);
  await cp(exported, directory, { recursive: true, errorOnExist: true, force: false });
  const path = join(directory, "bundle.json");
  const manifest = bundleManifest.parse(JSON.parse(await readFile(path, "utf8")));
  const item = manifest.files.find((r) => r.originalPath === join(native, funding.path));
  assert(item);
  let expectedError: RegExp;
  switch (corruption) {
    case "tamper":
      await appendFile(join(directory, item.path), "\nchanged");
      expectedError = /bundle raw bytes differ/;
      break;
    case "missing-declared":
      await writeFile(path, canonical({ ...manifest, files: manifest.files.filter((r) => r !== item) }));
      await rm(join(directory, item.path));
      expectedError = /missing declared bundle reference/;
      break;
    case "missing-physical":
      await rm(join(directory, item.path));
      expectedError = /ENOENT/;
      break;
    case "extra":
      await writeFile(join(directory, "data/unreferenced"), "unreferenced raw bytes", { flag: "wx" });
      expectedError = /bundle data membership differs/;
      break;
    case "unreferenced":
      await writeFile(path, canonical({ ...manifest, files: [...manifest.files,
        { ...item, originalPath: join(native, "unreferenced.csv") }] }));
      expectedError = /unreferenced bundle item/;
      break;
    case "forged-reference":
    case "forged-id":
    case "wrong-purpose":
    case "wrong-size": {
      const changes = {
        "forged-reference": { sha256: "f".repeat(64) }, "forged-id": { id: "current-main-plan" },
        "wrong-purpose": { purpose: "operational-review" }, "wrong-size": { bytes: "1" },
      };
      const raw = Buffer.from(canonical({ ...input, rehearsalFundingEvidence: { ...funding, ...changes[corruption] } }));
      const template = { path: `data/${fingerprint(raw)}`, sha256: fingerprint(raw), bytes: String(raw.length) };
      await writeFile(join(directory, template.path), raw, { flag: "wx" });
      await rm(join(directory, manifest.template.path));
      await writeFile(path, canonical({ ...manifest, template }));
      expectedError = corruption === "forged-id" || corruption === "wrong-purpose"
        ? /Invalid literal value/ : /historical FileRef identity differs/;
      break;
    }
    default: {
      const exhaustive: never = corruption;
      throw new TypeError(`unknown corruption ${exhaustive}`);
    }
  }
  const output = join(root, "negative", `${corruption}-output`);
  await reject(corruption, () => materializeBundle(path, output), expectedError);
  await assert.rejects(readdir(output), { code: "ENOENT" });
}
for (const field of ["id", "path", "sha256", "bytes", "provenance", "purpose", "format"]) {
  const malformed: Record<string, unknown> = { ...funding };
  delete malformed[field];
  const result = authorityInput.safeParse({ ...input, rehearsalFundingEvidence: malformed });
  assert.equal(result.success, false);
  if (result.success) throw new TypeError("malformed evidence accepted");
  assert(result.error.issues.some((issue) => issue.path.join(".") === `rehearsalFundingEvidence.${field}`));
  negatives.push({ label: `missing-field-${field}`, name: result.error.name, message: result.error.message });
}
assert.equal(source.safeParse(funding).success, false);
const saved = await loadSavedBundle(join(root, "relocated-a/bundle.json"));
if (saved.kind !== "authorities" || !saved.rehearsalFundingEvidence) throw new TypeError("expected funding source");
const ref = { path: saved.rehearsalFundingEvidence.path, sha256: funding.sha256, bytes: funding.bytes };
const accepted = { manifest: ref, executionManifest: ref, journalDomain: ref,
  configurationId: `0x${"1".repeat(64)}`, intent: ref, completion: null };
acceptedConfiguration.parse(accepted);
await reject("raw-evidence-as-historical-reference", async () => acceptedConfiguration.parse({
  ...accepted, manifest: saved.rehearsalFundingEvidence,
}), /unrecognized_keys/);
await reject("csv-is-not-a-json-manifest", () => walkReferences(ref, async (s) => readFile(s.path)), /JSON|Unexpected/);
const stale = join(root, "negative/stale-binding");
await cp(exported, stale, { recursive: true });
const stalePath = join(stale, "bundle.json");
const before = await readBundle(stalePath);
await appendFile(stalePath, " ");
await reject("stale-bundle-binding", () => loadSavedBundle(stalePath, before.reference), /bundle raw bytes differ/);

const resumeInput = join(root, "resume-input.json");
await save(resumeInput, { version: input.version, sources: saved.sources,
  rehearsalFundingEvidence: saved.rehearsalFundingEvidence });
const cleanup = [];
for (const phase of ["root-created", "data-written"]) {
  const partial = join(root, "negative", `partial-${phase}`);
  await mkdir(partial);
  if (phase === "data-written") await cp(join(exported, "data"), join(partial, "data"), { recursive: true });
  await reject(`interrupted-${phase}-load`, () => loadSavedBundle(join(partial, "bundle.json")), /ENOENT/);
  for (const attempt of [1, 2]) {
    await reject(`interrupted-${phase}-retry-${attempt}`, () => exportBundle(resumeInput, partial), /EEXIST/);
  }
  await rm(partial, { recursive: true });
  cleanup.push({ path: partial, removed: true, ownedPartialExportOnly: true });
}
await rm(resumeInput);
cleanup.push({ path: resumeInput, removed: true, ownedPartialExportOnly: true });
const origins = z.object({ funding: z.object({ originalPath: z.string() }) }).passthrough()
  .parse(JSON.parse(await readFile(join(root, "origins.json"), "utf8")));
const retainedRaw = await readFile(origins.funding.originalPath);
assert.equal(fingerprint(retainedRaw), funding.sha256);
await save(join(root, "transport-results.json"), {
  scope: "offline transport; not current-chain lifecycle", status: "PASS", comparisons, negatives,
  nativeUnavailableDuringEveryLoad: true, selectedDonor: null, financialAwards: 0,
  nonceOperations: 0, signingOperations: 0, transactions: 0,
  operationsQualification: "Only offline export/load/materialize/schema routines were invoked; no RPC or signer was constructed.",
  originalFundingUnchanged: { sha256: fingerprint(retainedRaw), bytes: String(retainedRaw.length) },
  interruptionQualification: "Controlled partial filesystem states, not a process-kill or crash-durability claim.",
});
await save(join(root, "cleanup.json"), { cleanup, liveProcesses: [], ports: [],
  retainedEvidence: ["native.unavailable", "exported", "relocated-a", "relocated-b", "negative"],
  originalArchive: "read only; unchanged", nativeCopies: `${native}.unavailable` });
console.log(JSON.stringify({ status: "PASS", scope: "offline transport", locations: comparisons.length,
  byteComparisons: comparisons.reduce((n, c) => n + c.bytes.length, 0), rejections: negatives.length,
  report: join(root, "transport-results.json") }));
