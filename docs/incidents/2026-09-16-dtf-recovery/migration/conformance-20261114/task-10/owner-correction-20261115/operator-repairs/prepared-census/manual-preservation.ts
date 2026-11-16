import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "ethers";
import { z } from "zod";
import { censusContext, compensationEvents } from "../empty-census/census-context.js";
import { RangeLogs } from "./prepared-context.js";
import { censusFixture } from "../../../../../../../../../scripts/recovery/dtf-migration/execution.fixture.js";
import { verifyEmptyCensus, loadExecution } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { execute } from "../../../../../../../../../scripts/recovery/dtf-migration/execution.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";

const evidence = await mkdtemp(join(dirname(fileURLToPath(import.meta.url)), "manual-preservation-"));
const empty = await censusContext();
try {
  await verifyEmptyCensus(empty.rpc, empty.domain);
  await verifyEmptyCensus(empty.rpc, empty.domain);
  for (const event of compensationEvents) for (const offset of [0n, 7n]) {
    empty.inject(event, offset);
    await assert.rejects(verifyEmptyCensus(empty.rpc, empty.domain),
      /nonempty configuration\/issuance census requires exact preparation evidence/);
  }
  empty.logs.rows = empty.mined.logs;
  empty.logs.malformed = true;
  await assert.rejects(verifyEmptyCensus(empty.rpc, empty.domain), z.ZodError);
  empty.logs.malformed = false;
  empty.changes.blocks.set(empty.mined.blockNumber, { ...empty.chain.header, hash: h(9999) });
  await assert.rejects(verifyEmptyCensus(empty.rpc, empty.domain), /receipt is not canonical or transaction order differs/);
  empty.changes.blocks.set(empty.mined.blockNumber, empty.chain.header);
  const issued = empty.domain.abis.migration.getEvent("IndependentAllocationIssued");
  assert.ok(issued);
  const missing = new Interface(empty.domain.abis.migration.fragments.filter((fragment) =>
    fragment.type !== "event" || fragment.format("sighash") !== issued.format("sighash")));
  await assert.rejects(verifyEmptyCensus(empty.rpc, { ...empty.domain, abis: { ...empty.domain.abis, migration: missing } }),
    /missing compensation census event ABI: IndependentAllocationIssued/);
  await verifyEmptyCensus(empty.rpc, empty.domain);
  const after = await Promise.all(empty.bindings.map(async (binding) => {
    const bytes = await readFile(binding.path);
    return { path: binding.path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
  }));
  assert.deepEqual(after, empty.bindings);
  await writeFile(join(evidence, "empty-census.json"), canonical({ acceptedInitialization: true,
    acceptedEmptyChecks: 3, rejectedSingletons: 22, malformedRejected: true, staleHeaderRejected: true,
    missingIssuanceAbiRejected: true, before: empty.bindings, after, requests: empty.requests }), { flag: "wx" });
} finally {
  await empty.close();
  await writeFile(join(evidence, "empty-cleanup.json"), canonical({ closed: true, removedDirectory: empty.root }), { flag: "wx" });
}
const f = await censusFixture();
try {
  // Adapt only the fixture range transport to the changed query; retain every signed byte.
  const logs = new RangeLogs(f.changes.logs);
  logs.rows = f.configured;
  f.changes.logs = logs;
  const paths = [f.A.preparedPath, f.A.manifestPath, f.A.journalPath, f.A.intentPath, f.B.preparedPath, f.B.journalPath, f.B.intentPath];
  const before = await Promise.all(paths.map((path) => readFile(path)));
  f.publishY();
  f.changes.quoteDelta = 1n;
  const loaded = await loadExecution(f.B.manifestPath);
  assert.equal(loaded.prepared?.payloadHash, f.B.domain.prepared.payloadHash);
  const run = { manifestPath: f.B.manifestPath, checkpoint: f.B.checkpoint,
    mode: { kind: "simulate" }, reverse: false, faultAfterMined: false } as const;
  const verified = await execute({ ...run, command: "verify" });
  assert.equal(verified.mode, "read-only");
  const resumes = [];
  for (let i = 0; i < 2; i++) {
    const resumed = await execute({ ...run, command: "resume" });
    assert.deepEqual(resumed.operationIds, [f.B.record.id]);
    resumes.push(resumed);
  }
  for (const ids of [...f.B.domain.prepared.payloads.configure.weightedSy.map((row) => [row.input.originalId]), []]) {
    const incomplete = await f.incomplete(ids);
    await assert.rejects(loadExecution(incomplete.manifestPath), /previously configured SY origin omitted from complete census/);
  }
  const after = await Promise.all(paths.map((path) => readFile(path)));
  assert.deepEqual(after, before);
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  await writeFile(join(evidence, "historical-current.json"), canonical({
    status: "PASS", transport: "new synthetic fixture only; no original archive was changed",
    verified, resumes, omittedXRejected: true, omittedYRejected: true, emptyRejected: true,
    hashesBefore: before.map(fingerprint), hashesAfter: after.map(fingerprint), paths,
    domainHashes: { A: f.A.record.domainHash, B: f.B.record.domainHash }, requests: f.requests,
  }), { flag: "wx" });
} finally {
  await f.close();
  await writeFile(join(evidence, "history-cleanup.json"), canonical({ closed: true, removedDirectory: f.root }), { flag: "wx" });
}
console.log(canonical({ status: "PASS", evidence, scope: "affected empty and historical/current manual proof replay" }));
