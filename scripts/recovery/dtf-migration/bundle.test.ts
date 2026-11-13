import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { cp, readFile, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fixture } from "./preparation.fixture.js";
import { canonical, fingerprint, loadInput } from "./provenance.js";
import { exportBundle, loadSavedBundle } from "./bundle.js";
import { bundleManifest } from "./bundle-files.js";
import { materializeBundle } from "./bundle-materialize.js";
import { prepareDomain, prepareFile, validateManifest } from "./preparation.js";
import { Journal } from "./journal.js";
import { main } from "./cli.js";
import { replacementFixture } from "./rehearsal-data.js";

const fixtures: Awaited<ReturnType<typeof fixture>>[] = [];
async function setup() {
  const f = await fixture();
  fixtures.push(f);
  const root = await realpath(f.root);
  const input = join(root, "input.json");
  await writeFile(input, canonical(f.input));
  const bundle = await exportBundle(input, join(root, "bundle-a"));
  return { ...f, root, bundle };
}
afterEach(async () => { for (const f of fixtures.splice(0)) await f.close(); });

test("relocated real bundle bytes rebuild identical payloads and quotes but a fresh journal domain", async () => {
  const f = await setup();
  await cp(join(f.root, "bundle-a"), join(f.root, "bundle-b"), { recursive: true });
  const a = await materializeBundle(f.bundle, join(f.root, "a"));
  const b = await materializeBundle(join(f.root, "bundle-b/bundle.json"), join(f.root, "b"));
  assert.equal(a.kind, "preparation");
  assert.equal(b.kind, "preparation");
  if (a.kind !== "preparation" || b.kind !== "preparation") throw new TypeError("expected preparation");
  const first = await prepareFile(a.input, join(f.root, "prepared-a"));
  const second = await prepareFile(b.input, join(f.root, "prepared-b"));
  assert.deepEqual(second.payloads, first.payloads);
  assert.deepEqual(second.quoteEvidence, first.quoteEvidence);
  assert.notEqual(second.normalizedHash, first.normalizedHash);
  assert.deepEqual(second.input.sources.map(({ path: _path, ...s }) => s),
    first.input.sources.map(({ path: _path, ...s }) => s));
  for (const s of second.input.sources) {
    assert(s.path.startsWith(join(f.root, "bundle-b/data/")));
    assert.equal(fingerprint(await readFile(s.path)), s.sha256);
  }
  const journalPath = join(f.root, "checkpoint");
  const journal = await Journal.acquire(journalPath, first);
  await journal.close();
  await assert.rejects(Journal.acquire(journalPath, second), /domain changed/);
  assert.deepEqual(await validateManifest(join(f.root, "prepared-a/manifest.json")), first);
});

test("saved prepared envelopes preserve raw originals and reauthenticate rather than trusting payloads", async () => {
  const f = await setup();
  const original = await prepareFile(join(f.root, "input.json"), join(f.root, "original-prepared"));
  const raw = await readFile(join(f.root, "original-prepared/manifest.json"));
  const bundle = await exportBundle(join(f.root, "original-prepared/manifest.json"), join(f.root, "saved"));
  const saved = await loadSavedBundle(bundle);
  assert.deepEqual(saved.originalTemplate, raw);
  const materialized = await materializeBundle(bundle, join(f.root, "fresh"));
  if (materialized.kind !== "preparation") throw new TypeError("expected preparation");
  assert.deepEqual((await prepareDomain(await loadInput(materialized.input))).payloads, original.payloads);
  f.changes.combinedMismatch = true;
  await assert.rejects(prepareDomain(await loadInput(materialized.input)), /component quote mismatch/);
});

test("replacement proofs bind their new document after normalized bundle preparation", async () => {
  const f = await setup();
  const materialized = await materializeBundle(f.bundle, join(f.root, "materialized"));
  if (materialized.kind !== "preparation") throw new TypeError("expected preparation");
  const prepared = await prepareDomain(await loadInput(materialized.input));
  const replacement = await replacementFixture(prepared.input, f.root);
  const result = await prepareDomain(replacement);
  assert.deepEqual(result.payloads.configure.nfts.map((r) => r.input),
    prepared.payloads.configure.nfts.map((r) => r.input));
  assert.equal(result.payloads.configure.weightedSy[0]?.input.originalUnits, "8087");
  assert.notEqual(result.normalizedHash, prepared.normalizedHash);
});

test("saved bundles reject a noncanonical prepared envelope just as native validation does", async () => {
  const f = await setup();
  const original = await prepareFile(join(f.root, "input.json"), join(f.root, "prepared"));
  const path = join(f.root, "noncanonical-manifest.json");
  await writeFile(path, canonical({ ...original,
    input: { ...original.input, sources: [...original.input.sources].reverse() } }));
  await assert.rejects(validateManifest(path), /binding differs/);
  const bundle = await exportBundle(path, join(f.root, "noncanonical-bundle"));
  const materialized = await materializeBundle(bundle, join(f.root, "noncanonical-materialized"));
  if (materialized.kind !== "preparation") throw new TypeError("expected preparation");
  await assert.rejects(prepareDomain(await loadInput(materialized.input)), /saved preparation/);
});

for (const corruption of ["missing", "tamper", "symlink"] as const) {
  test(`bundle rejects ${corruption} despite intact original inputs`, async () => {
    const f = await setup();
    const manifest = bundleManifest.parse(JSON.parse(await readFile(f.bundle, "utf8")));
    const item = manifest.files.find((r) => r.originalPath === f.evidencePath);
    assert.ok(item);
    const path = join(f.root, "bundle-a", item.path);
    if (corruption === "missing") await rm(path);
    if (corruption === "tamper") await writeFile(path, "{}");
    if (corruption === "symlink") {
      await rm(path);
      await symlink(f.evidencePath, path);
    }
    assert.equal(fingerprint(await readFile(f.evidencePath)), item.sha256);
    await assert.rejects(materializeBundle(f.bundle, join(f.root, "materialized")),
      corruption === "missing" ? { code: "ENOENT" } : /bundle raw bytes differ|not a regular file/);
  });
}
for (const corruption of ["length", "traversal", "duplicate", "missing-reference", "extra", "data-link"] as const) {
  test(`bundle rejects ${corruption} at its contained-file boundary`, async () => {
    const f = await setup();
    const manifest = bundleManifest.parse(JSON.parse(await readFile(f.bundle, "utf8")));
    const first = manifest.files[0];
    assert.ok(first);
    if (corruption === "extra") await writeFile(join(f.root, "bundle-a/data/unreferenced"), "unrelated");
    else if (corruption === "data-link") {
      await cp(join(f.root, "bundle-a/data"), join(f.root, "external-data"), { recursive: true });
      await rm(join(f.root, "bundle-a/data"), { recursive: true });
      await symlink(join(f.root, "external-data"), join(f.root, "bundle-a/data"));
    } else {
      const files = corruption === "duplicate" ? [...manifest.files, first]
        : corruption === "missing-reference" ? manifest.files.slice(1)
        : manifest.files.map((s, i) => i !== 0 ? s : corruption === "length" ? { ...s, bytes: "1" }
          : { ...s, path: `../${s.path}` });
      await writeFile(f.bundle, canonical({ ...manifest, files }));
    }
    await assert.rejects(loadSavedBundle(f.bundle));
  });
}

test("materialized inputs reject template changes and bundle-manifest tampering", async () => {
  const f = await setup();
  const materialized = await materializeBundle(f.bundle, join(f.root, "materialized"));
  if (materialized.kind !== "preparation") throw new TypeError("expected preparation");
  const input = await loadInput(materialized.input);
  await assert.rejects(prepareDomain({ ...input, harvest: { ...input.harvest, deadline: "123" } }),
    /differs from saved template/);
  await writeFile(f.bundle, (await readFile(f.bundle, "utf8")) + " ");
  await assert.rejects(prepareDomain(input), /bundle raw bytes differ/);
});

test("export rejects duplicate source roles instead of choosing a binding", async () => {
  const f = await setup();
  const source = f.input.sources[0];
  assert.ok(source);
  await writeFile(join(f.root, "duplicate.json"), canonical({ ...f.input, sources: [...f.input.sources, source] }));
  await assert.rejects(exportBundle(join(f.root, "duplicate.json"), join(f.root, "duplicate-bundle")), /duplicate source/);
});

for (const args of [
  ["bundle-export", "--input", "a", "--input", "b", "--output", "c"],
  ["bundle-materialize", "--input", "a", "--output", "b", "--execute-local"],
  ["rehearse", "--rpc-alias", "robinhood_mainnet_alchemy", "--fork-block", "108944663",
    "--port", "18575", "--checkpoint", ".omo-runtime/dtf-migration-portable/checkpoints", "--evidence", "unused"],
]) test(`bundle CLI rejects ambiguous authority: ${args.join(" ")}`, async () => { await assert.rejects(main(args)); });
