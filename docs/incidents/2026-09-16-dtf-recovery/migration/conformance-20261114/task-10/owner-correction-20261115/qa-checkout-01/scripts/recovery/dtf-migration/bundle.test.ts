import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { appendFile, cp, mkdir, readFile, readdir, realpath, rename, rm, symlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fixture } from "./preparation.fixture.js";
import { canonical, fingerprint, loadInput } from "./provenance.js";
import { authorityInput, authorityRoles, exportBundle, loadSavedBundle } from "./bundle.js";
import { bundleManifest, readBundle, walkReferences } from "./bundle-files.js";
import { materializeBundle } from "./bundle-materialize.js";
import { assemble, normalize, prepareDomain, prepareFile, validateManifest } from "./preparation.js";
import { Journal } from "./journal.js";
import { main } from "./cli.js";
import { replacementFixture, sourceFile } from "./rehearsal-data.js";
import { mixedFixture } from "../../../docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-12/mixed-fixture.js";
import { loadExecution } from "./execution-domain.js";
import { relocateExecution } from "./rehearsal-portable.js";
import { plan } from "./execution-plan.js";
import { Rpc } from "./execution-rpc.js";
import { verifyConfiguration } from "./execution-state.js";
import { z } from "zod";
import { acceptedConfiguration, bundleReference, preparationInput, sha256, source } from "./schema.js";

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

async function fundingFixture() {
  const f = await fixture();
  fixtures.push(f);
  const root = await realpath(f.root);
  const native = join(root, "funding-native");
  await mkdir(native);
  const sources = await Promise.all(authorityRoles.map(async (id) => {
    const path = join(native, `${id}.txt`);
    await writeFile(path, `Distinct original authority bytes: ${id}\r\n`);
    return sourceFile(id, path);
  }));
  const path = join(native, "transfers.csv");
  const raw = Buffer.from("token,from,to,value\r\nDTF,sender,candidate,123\r\n");
  await writeFile(path, raw);
  const rehearsalFundingEvidence = { ...await sourceFile("rehearsal-funding-transfers", path),
    purpose: "synthetic-local" as const, format: "transfer-csv" as const };
  const input = { version: "dtf-operator-authorities-v1" as const, sources, rehearsalFundingEvidence };
  const inputPath = join(native, "input.json");
  await writeFile(inputPath, canonical(input));
  return { ...f, root, native, preparation: f.input, input, inputPath, raw };
}

for (const funding of [false, true]) {
  test(`authority transport retains 22 roles at two fresh locations with funding evidence ${funding}`, async () => {
    const f = await fundingFixture();
    const template = funding ? f.input : { version: f.input.version, sources: f.input.sources };
    await writeFile(f.inputPath, canonical(template));
    const expected = await Promise.all(f.input.sources.map(async (s) => ({ ...s, raw: await readFile(s.path) })));
    await exportBundle(f.inputPath, join(f.root, "authority-export"));
    await rename(f.native, `${f.native}.unavailable`);
    for (const location of ["first", "second"]) {
      const directory = join(f.root, location);
      await cp(join(f.root, "authority-export"), directory, { recursive: true });
      const saved = await loadSavedBundle(join(directory, "bundle.json"));
      const materialized = await materializeBundle(join(directory, "bundle.json"), join(f.root, `${location}-materialized`));
      if (saved.kind !== "authorities" || materialized.kind !== "authorities") throw new TypeError("expected authorities");
      assert.deepEqual(saved.sources.map((s) => s.id), authorityRoles);
      assert.deepEqual(materialized.sources, saved.sources);
      assert.deepEqual(saved.originalTemplate, Buffer.from(canonical(template)));
      for (const original of expected) {
        const mapped: z.infer<typeof source> | undefined = saved.sources.find((s) => s.id === original.id);
        assert.ok(mapped);
        assert(mapped.path.startsWith(`${directory}/data/`));
        assert.deepEqual(await readFile(mapped.path), original.raw);
        assert.deepEqual(mapped.provenance, original.provenance);
      }
      assert.deepEqual(materialized.rehearsalFundingEvidence, saved.rehearsalFundingEvidence);
      if (funding) {
        assert.ok(saved.rehearsalFundingEvidence);
        assert(saved.rehearsalFundingEvidence.path.startsWith(`${directory}/data/`));
        assert.deepEqual(await readFile(saved.rehearsalFundingEvidence.path), f.raw);
        const { path: _path, ...metadata } = saved.rehearsalFundingEvidence;
        const { path: _originalPath, ...originalMetadata } = f.input.rehearsalFundingEvidence;
        assert.deepEqual(metadata, originalMetadata);
      } else assert.equal(saved.rehearsalFundingEvidence, undefined);
    }
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  });
}

for (const corruption of ["tamper", "missing", "extra", "unreferenced", "identity", "purpose", "size"] as const) {
  test(`authority funding transport rejects ${corruption} before materialization or signing`, async () => {
    const f = await fundingFixture();
    const directory = join(f.root, "authority-export");
    const bundle = await exportBundle(f.inputPath, directory);
    const manifest = bundleManifest.parse(JSON.parse(await readFile(bundle, "utf8")));
    const item = manifest.files.find((s) => s.originalPath === f.input.rehearsalFundingEvidence.path);
    assert.ok(item);
    let expected: RegExp;
    switch (corruption) {
      case "tamper":
        await appendFile(join(directory, item.path), "changed");
        expected = /bundle raw bytes differ/;
        break;
      case "missing":
        await writeFile(bundle, canonical({ ...manifest, files: manifest.files.filter((s) => s !== item) }));
        await rm(join(directory, item.path));
        expected = /missing declared bundle reference/;
        break;
      case "extra":
        await writeFile(join(directory, "data/extra"), "unreferenced");
        expected = /bundle data membership differs/;
        break;
      case "unreferenced":
        await writeFile(bundle, canonical({ ...manifest, files: [...manifest.files,
          { ...item, originalPath: join(f.native, "undeclared.csv") }] }));
        expected = /unreferenced bundle item/;
        break;
      case "identity":
      case "purpose":
      case "size": {
        const evidence = f.input.rehearsalFundingEvidence;
        const changed = corruption === "identity" ? { ...evidence, id: "current-main-plan" }
          : corruption === "purpose" ? { ...evidence, purpose: "operational-review" } : { ...evidence, bytes: "1" };
        const raw = Buffer.from(canonical({ ...f.input, rehearsalFundingEvidence: changed }));
        const template = { path: `data/${fingerprint(raw)}`, sha256: fingerprint(raw), bytes: String(raw.length) };
        await writeFile(join(directory, template.path), raw);
        await rm(join(directory, manifest.template.path));
        await writeFile(bundle, canonical({ ...manifest, template }));
        expected = corruption === "size" ? /historical FileRef identity differs/ : /Invalid literal value/;
        break;
      }
      default: {
        const exhaustive: never = corruption;
        throw new TypeError(`unhandled corruption ${exhaustive}`);
      }
    }
    const output = join(f.root, "rejected");
    await assert.rejects(materializeBundle(bundle, output), expected);
    await assert.rejects(readdir(output), { code: "ENOENT" });
    assert.deepEqual(await readFile(f.input.rehearsalFundingEvidence.path), f.raw);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  });
}

test("authority funding evidence cannot stand in for an authority, financial input or JSON historical FileRef", async () => {
  const f = await fundingFixture();
  const evidence = f.input.rehearsalFundingEvidence;
  assert.equal(authorityInput.safeParse(f.input).success, true);
  assert.equal(authorityInput.safeParse({ ...f.input, sources: [...f.input.sources.slice(1), evidence] }).success, false);
  assert.equal(source.safeParse(evidence).success, false);
  assert.equal(preparationInput.safeParse(f.preparation).success, true);
  assert.equal(preparationInput.safeParse({ ...f.preparation, rehearsalFundingEvidence: evidence }).success, false);
  const ref = { path: evidence.path, sha256: evidence.sha256, bytes: evidence.bytes };
  const accepted = { manifest: ref, executionManifest: ref, journalDomain: ref,
    configurationId: `0x${"1".repeat(64)}`, intent: ref, completion: null };
  assert.equal(acceptedConfiguration.safeParse(accepted).success, true);
  assert.equal(acceptedConfiguration.safeParse({ ...accepted, manifest: evidence }).success, false);
  await assert.rejects(walkReferences(ref, async (s) => readFile(s.path)), SyntaxError);
});

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

test("saved prepared envelopes preserve raw originals and quotes while reauthenticating their book", async () => {
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
  const rehydrated = await prepareDomain(await loadInput(materialized.input));
  assert.deepEqual(rehydrated.payloads, original.payloads);
  assert.deepEqual(rehydrated.quoteEvidence, original.quoteEvidence);
  f.changes.book = "0x";
  await assert.rejects(prepareDomain(await loadInput(materialized.input)), { code: "QUOTE" });
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
    await rejectsTamper(`contained-${corruption}`, () => loadSavedBundle(f.bundle), /./s);
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

async function mixed() {
  const f = await mixedFixture();
  fixtures.push(f);
  return f;
}

async function rejectsTamper(label: string, action: () => Promise<unknown>, expected: RegExp) {
  let observed = "";
  await assert.rejects(action, (error: unknown) => {
    assert.ok(error instanceof Error);
    assert.match(error.message, expected);
    observed = `${error.name}: ${error.message}`;
    return true;
  });
  const evidence = process.env["TASK12_EVIDENCE"];
  if (evidence) await appendFile(join(evidence, "tamper-rejections.log"), `${label}: ${observed}\n`);
}

test("complete mixed A-SY/B-configuration and immutable A-issuance relocate twice without native fallback or new prices", async () => {
  const f = await mixed();
  const bundle = await exportBundle(f.manifestPath, join(f.root, "snapshot-bundle"));
  const saved = await readBundle(bundle);
  const rawFiles = await Promise.all(saved.manifest.files.map(async (item) => ({
    ...item, rawBase64: (await readFile(item.originalPath)).toString("base64"),
  })));
  const cli = async (args: readonly string[]) => {
    await main(args);
    if (args[0] === "bundle-export") {
      // Remove the native fallback between actual export and materialization.
      // Only owned fixture files move; reviewed repo artifacts stay untouched.
      for (const item of rawFiles) if ((await realpath(item.originalPath)).startsWith(f.root + "/")) {
        await rename(item.originalPath, item.originalPath + ".unavailable");
      }
    }
  };
  const relocated = await relocateExecution({ manifestPath: f.manifestPath, evidence: f.root, label: "mixed", cli });
  const report = z.object({ historicalDomains: z.array(z.array(z.object({
    stage: z.enum(["configure", "independent-issue"]), intent: bundleReference,
    originalDomainHash: sha256, signedDomainHash: sha256,
  }).strict())) }).passthrough().parse(JSON.parse(await readFile(join(f.root, "relocation-mixed/comparison.json"), "utf8")));
  const comparisons = [];
  for (const [index, current] of [relocated.first, relocated].entries()) {
    assert.ok(current.domain.prepared);
    const prepared = current.domain.prepared;
    assert.deepEqual(prepared.payloads, f.finalPrepared.payloads);
    assert.deepEqual(prepared.input.books, f.finalPrepared.input.books);
    assert.deepEqual(prepared.input.issuedHistory, f.finalPrepared.input.issuedHistory);
    assert.deepEqual(plan(current.domain, "configure"), []);
    assert.throws(() => plan(current.domain, "independent-issue"), /no independent issuance selected/);
    const b = prepared.input.bundle;
    assert.ok(b);
    const physical = await readBundle(b.path, b);
    const byteComparison = rawFiles.map((item) => {
      const raw = physical.bytesOf(item.originalPath);
      assert.deepEqual(raw, Buffer.from(item.rawBase64, "base64"));
      return { originalPath: item.originalPath, sha256: fingerprint(raw), bytes: String(raw.length), identical: true };
    });
    const contexts = report.historicalDomains[index];
    assert.ok(contexts);
    const expected = new Map([
      [f.acceptedA.intent.path, f.configureA.record.domainHash],
      [f.acceptedB.intent.path, f.configureB.record.domainHash],
      [f.acceptedSy.intent.path, f.configureA.record.domainHash],
      [f.issuedA.intent.path, f.issueA.record.domainHash],
    ]);
    assert.equal(contexts.length, expected.size);
    for (const context of contexts) {
      assert.equal(context.originalDomainHash, expected.get(context.intent.path));
      assert.equal(context.signedDomainHash, context.originalDomainHash);
    }
    comparisons.push({ freshDomainHash: fingerprint(canonical(current.domain.domain)), contexts, byteComparison });
  }
  assert.notEqual(comparisons[0]?.freshDomainHash, comparisons[1]?.freshDomainHash);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  const evidence = process.env["TASK12_EVIDENCE"];
  if (evidence) {
    await writeFile(join(evidence, "portable-integrity.json"), JSON.stringify({
      scope: "Synthetic task 7 wire fixture only; no task 10 current-chain proof",
      fixtures: { template: saved.template.toString("base64"), manifest: saved.manifest, files: rawFiles },
      acceptedFacts: { payloads: f.finalPrepared.payloads, books: f.finalPrepared.input.books,
        issuanceHistory: f.finalPrepared.input.issuedHistory }, comparisons,
      deterministicFacts: {
        books: f.finalPrepared.input.books,
        configurations: Object.values(f.finalPrepared.payloads.configure).flat().map((r) => ({
          configurationId: r.configurationId, bookId: r.pricing.bookId, input: r.input, quotedCredit: r.quotedCredit,
        })),
        issuance: { recipient: f.finalPrepared.input.independent[0]?.recipient, transactionHash: f.issueA.record.transactionHash,
          configurationId: f.acceptedA.configurationId },
      },
      runtimeMetadata: "Exact raw paths, RPC environment names and their historical hashes vary with isolated temporary roots and ports; they are preserved, never normalized or rebound.",
      met: ["two fresh domains", "byte-identical complete transitive closure", "original historical domains",
        "B configuration with A issuance", "retained A SY", "read-only validate and verify without price reacquisition"],
      unmet: ["task 10 real portable mode current-chain proof"],
    }, null, 2) + "\n", { flag: "wx" });
  }
});

for (const command of ["validate", "verify"] as const) {
  test(`default ${command} on a relocated retained-A preparation stays read-only without current pricing`, async () => {
    const f = await mixed();
    const bundle = await exportBundle(f.manifestPath, join(f.root, "readonly-bundle"));
    const materialized = await materializeBundle(bundle, join(f.root, "readonly-materialized"));
    if (materialized.kind !== "execution") throw new TypeError("Expected execution");
    const domain = await loadExecution(materialized.manifest);
    const before = (await readdir(f.root)).sort();
    const prepared = domain.manifest.preparedManifest;
    assert.ok(prepared);
    await main(command === "validate" ? ["validate", "--manifest", prepared]
      : ["verify", "--manifest", materialized.manifest, "--checkpoint", join(f.root, "must-not-create")]);
    assert.deepEqual((await readdir(f.root)).sort(), before);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  });
}

for (const target of ["a-book", "b-input", "a-issuance-intent", "receipt", "original-execution", "original-journal"] as const) {
  test(`mixed bundle rejects independent ${target} corruption without replacing accepted originals`, async () => {
    const f = await mixed();
    const bundle = await exportBundle(f.manifestPath, join(f.root, "tamper-bundle"));
    const manifest = bundleManifest.parse(JSON.parse(await readFile(bundle, "utf8")));
    const paths = { "a-book": f.books[0]?.path, "b-input": f.books[3]?.path,
      "a-issuance-intent": f.issuedA.intent.path, receipt: f.acceptedB.completion.path,
      "original-execution": f.executionARef.path, "original-journal": f.journalARef.path };
    const path = paths[target];
    assert.ok(path);
    const item = manifest.files.find((item) => item.originalPath === path);
    assert.ok(item);
    const accepted = await readFile(path);
    const physical = join(f.root, "tamper-bundle", item.path);
    if (target === "original-execution" || target === "original-journal") {
      await writeFile(bundle, canonical({ ...manifest, files: manifest.files.filter((r) => r !== item) }));
      // Remove the matching content only if no other original shares those bytes.
      if (!manifest.files.some((r) => r !== item && r.path === item.path) && manifest.template.path !== item.path) await rm(physical);
    } else {
      const raw = Buffer.from(await readFile(physical));
      raw[0] = (raw[0] ?? 0) ^ 1;
      await writeFile(physical, raw);
    }
    await rejectsTamper(target, () => materializeBundle(bundle, join(f.root, "rejected")),
      /bundle raw bytes differ|missing declared bundle reference/);
    await assert.rejects(readFile(join(f.root, "rejected/execution.json")), { code: "ENOENT" });
    assert.deepEqual(await readFile(path), accepted);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  });
}

test("relocated historical domainHash forgery rejects even after all surrounding FileRefs are recomputed", async () => {
  const f = await mixed();
  const acceptedBytes = await readFile(f.acceptedB.intent.path);
  const record: unknown = JSON.parse(acceptedBytes.toString());
  const { intent } = await import("./execution-schema.js");
  const forgedIntent = await f.save("forged-intent.json", { ...intent.parse(record), domainHash: "f".repeat(64) });
  const originalCompletion = await readFile(f.acceptedB.completion.path);
  const { completion } = await import("./execution-schema.js");
  const forgedRecord = intent.parse(JSON.parse((await readFile(forgedIntent.path)).toString()));
  const forgedCompletion = await f.save("forged-receipt.json", {
    ...completion.parse(JSON.parse(originalCompletion.toString())), intentHash: fingerprint(canonical(forgedRecord)),
  });
  const independent = f.finalPrepared.input.independent[0];
  assert.ok(independent);
  const forged = assemble(normalize({ ...f.finalPrepared.input, independent: [{ ...independent,
    pricing: { kind: "retain", bookId: independent.pricing.bookId,
      accepted: { ...f.acceptedB, intent: forgedIntent, completion: forgedCompletion } },
  }] }), f.finalPrepared.quoteEvidence);
  const prepared = await f.save("forged-prepared.json", forged);
  const native = await loadExecution(f.manifestPath);
  const execution = await f.save("forged-execution.json", { ...native.manifest, preparedManifest: prepared.path });
  const bundle = await exportBundle(execution.path, join(f.root, "forged-bundle"));
  await rejectsTamper("historical-domainHash-with-rehashed-FileRefs",
    () => materializeBundle(bundle, join(f.root, "forged-materialized")), /original execution\/preparation\/journal domain/);
  assert.deepEqual(await readFile(f.acceptedB.intent.path), acceptedBytes);
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
});

test("omitting old configured SY from a relocated complete preparation rejects the census", async () => {
  const f = await mixed();
  const omitted = assemble(normalize({ ...f.finalPrepared.input, weightedSy: [],
    exposures: f.finalPrepared.input.exposures.filter((r) => r.category !== "weighted-sy") }), f.finalPrepared.quoteEvidence);
  const prepared = await f.save("omitted-sy-prepared.json", omitted);
  const native = await loadExecution(f.manifestPath);
  const execution = await f.save("omitted-sy-execution.json", { ...native.manifest, preparedManifest: prepared.path });
  const bundle = await exportBundle(execution.path, join(f.root, "omitted-sy-bundle"));
  const materialized = await materializeBundle(bundle, join(f.root, "omitted-sy-materialized"));
  assert.equal(materialized.kind, "execution");
  if (materialized.kind !== "execution") throw new TypeError("Expected execution");
  const domain = await loadExecution(materialized.manifest);
  const rpc = new Rpc(domain.manifest);
  try {
    await rejectsTamper("omitted-old-SY-row", () => verifyConfiguration(rpc, domain), /configured original omitted/);
  } finally { rpc.close(); }
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
});

test("cyclic historical FileRefs reject before recursive bytes can be silently dropped", async () => {
  const path = "/synthetic-cycle.json";
  // A cryptographic self-reference has no constructible finite hash preimage.
  // Exercise the walker's active-path check with an exact valid first edge;
  // the second edge revisits the same path before loading or trusting its hash.
  const raw = Buffer.from(canonical({ path, sha256: "f".repeat(64), bytes: "1" }));
  let reads = 0;
  await rejectsTamper("cyclic-reference", () => walkReferences({ path, sha256: fingerprint(raw), bytes: String(raw.length) },
    async () => { reads++; return raw; }), /cyclic historical file reference/);
  assert.equal(reads, 1);
});

for (const action of ["copy", "move"] as const) {
  test(`${action} of an active signed checkpoint retains its original location reservation`, async () => {
    const f = await mixed();
    const original = join(f.root, "active-original");
    const relocated = join(f.root, "active-relocated");
    const domain: unknown = JSON.parse((await readFile(f.journalARef.path)).toString());
    const journal = await Journal.acquire(original, domain);
    await journal.persistIntent(f.configureA.record);
    await journal.close();
    if (action === "copy") await cp(original, relocated, { recursive: true });
    else await rename(original, relocated);
    const raw = await readFile(join(relocated, "domain.json"));
    const signedBytes = await readFile(join(relocated, `${f.configureA.record.id}.intent.json`));
    await rejectsTamper(`${action}-active-checkpoint`, () => Journal.acquire(relocated, domain), /second active execution/);
    assert.deepEqual(await readFile(join(relocated, "domain.json")), raw);
    assert.deepEqual(await readFile(join(relocated, `${f.configureA.record.id}.intent.json`)), signedBytes);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  });
}

for (const mismatch of ["network", "purpose", "facet", "v1"] as const) {
  test(`relocated v2 execution rejects ${mismatch} mismatch before nonce allocation`, async () => {
    const f = await mixed();
    const bundle = await exportBundle(f.manifestPath, join(f.root, "identity-bundle"));
    const materialized = await materializeBundle(bundle, join(f.root, "identity-materialized"));
    if (materialized.kind !== "execution") throw new TypeError("Expected execution");
    const domain = await loadExecution(materialized.manifest);
    const acceptedBytes = await readFile(f.manifestPath);
    if (mismatch === "facet") {
      const { loupeAbi } = await import("./execution-domain.js");
      const { a } = await import("./preparation.fixture.js");
      f.read(loupeAbi, "facets", [], [[[a(99), []]]]);
    } else {
      const changed = { ...domain.manifest,
        ...(mismatch === "network" ? { chainId: "1" } : {}),
        ...(mismatch === "purpose" ? { purpose: "operational-review" } : {}),
        ...(mismatch === "v1" ? { version: "dtf-operator-execution-v1" } : {}),
      };
      await writeFile(materialized.manifest, canonical(changed));
    }
    await rejectsTamper(`relocated-${mismatch}`, () => main(["verify", "--manifest", materialized.manifest,
      "--checkpoint", join(f.root, "forbidden-checkpoint")]),
    mismatch === "facet" ? /installed facet not in reviewed bindings/
      : mismatch === "v1" ? /Invalid literal value/ : /materialized execution differs/);
    assert.deepEqual(await readFile(f.manifestPath), acceptedBytes);
    await assert.rejects(readFile(join(f.root, "forbidden-checkpoint/domain.json")), { code: "ENOENT" });
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  });
}

for (const field of ["executionManifest", "journalDomain"] as const) {
  test(`historical ${field} cannot be omitted from a v2 portable record`, async () => {
    const f = await mixed();
    const independent = f.finalPrepared.input.independent[0];
    assert.ok(independent);
    const accepted: Record<string, unknown> = { ...f.acceptedB };
    delete accepted[field];
    const original = await readFile(f.manifestPath);
    const invalid = await f.save(`missing-${field}.json`, {
      ...f.finalPrepared, input: { ...f.finalPrepared.input, independent: [{ ...independent,
        pricing: { kind: "retain", bookId: independent.pricing.bookId, accepted },
      }] },
    });
    await rejectsTamper(`missing-historical-${field}`,
      () => exportBundle(invalid.path, join(f.root, "forbidden-export")), new RegExp(field));
    assert.deepEqual(await readFile(f.manifestPath), original);
    assert.equal(f.methods.includes("eth_getTransactionCount"), false);
    assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  });
}
