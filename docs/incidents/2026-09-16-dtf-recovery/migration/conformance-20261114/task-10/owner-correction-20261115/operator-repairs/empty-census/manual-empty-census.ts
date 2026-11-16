import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "ethers";
import { z } from "zod";
import { censusContext, compensationEvents } from "./census-context.js";
import { verifyEmptyCensus } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { preflightOperation } from "../../../../../../../../../scripts/recovery/dtf-migration/execution.js";
import { plan } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-plan.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";

const evidence = await mkdtemp(join(dirname(fileURLToPath(import.meta.url)), "manual-"));
const f = await censusContext();
const outcomes: { readonly name: string; readonly accepted: boolean; readonly error: string | null }[] = [];
try {
  const ownerBond = plan(f.domain, "owner-bond").find((operation) => operation.method === "bond");
  assert.ok(ownerBond);
  const check = async (name: string, expected: RegExp | null) => {
    const failure = await preflightOperation(f.rpc, f.domain, ownerBond, { kind: "simulate" })
      .then(() => undefined, (error: unknown) => {
        if (!(error instanceof Error)) throw error;
        return error;
      });
    outcomes.push({ name, accepted: failure === undefined, error: failure?.message ?? null });
    if (expected) {
      assert.ok(failure, `${name} must reject`);
      assert.match(failure.message, expected);
    } else assert.equal(failure, undefined, name);
  };
  await check("actual saved mandatory initialization / owner-bond census preflight", null);
  await check("repeated unchanged empty initialization preflight", null);
  for (const event of compensationEvents) for (const offset of [0n, 7n]) {
    f.inject(event, offset);
    await check(`synthetic omitted ${event[0]} at deployment offset ${offset}`,
      /nonempty configuration\/issuance census requires exact preparation evidence/);
  }
  f.logs.rows = f.mined.logs;
  f.logs.malformed = true;
  await assert.rejects(verifyEmptyCensus(f.rpc, f.domain), z.ZodError);
  outcomes.push({ name: "malformed census RPC payload", accepted: false, error: "ZodError" });
  f.logs.malformed = false;
  f.changes.blocks.set(f.mined.blockNumber, { ...f.chain.header, hash: h(9999) });
  await check("stale deployment header", /receipt is not canonical or transaction order differs/);
  f.changes.blocks.set(f.mined.blockNumber, f.chain.header);
  const issued = f.domain.abis.migration.getEvent("IndependentAllocationIssued");
  assert.ok(issued);
  const missingEvent = new Interface(f.domain.abis.migration.fragments.filter((fragment) =>
    fragment.type !== "event" || fragment.format("sighash") !== issued.format("sighash")));
  await assert.rejects(verifyEmptyCensus(f.rpc, { ...f.domain, abis: { ...f.domain.abis, migration: missingEvent } }),
    /missing compensation census event ABI: IndependentAllocationIssued/);
  outcomes.push({ name: "missing required issuance event ABI", accepted: false, error: "DOMAIN" });
  await check("restored empty initialization preflight", null);
  const after = await Promise.all(f.bindings.map(async (binding) => {
    const bytes = await readFile(binding.path);
    return { path: binding.path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
  }));
  assert.deepEqual(after, f.bindings);
  assert.equal(f.methods.includes("eth_call"), false);
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  await writeFile(join(evidence, "source-bindings.json"), canonical({ before: f.bindings, after }), { flag: "wx" });
  await writeFile(join(evidence, "rpc-requests.json"), canonical(f.requests), { flag: "wx" });
  await writeFile(join(evidence, "result.json"), canonical({
    status: "PASS",
    scope: "real domain loading and owner-bond census preflight only; no bond execution",
    transport: "synthetic isolated loopback; exact archived deployment transaction/header/receipt; census range is the saved deployment logs plus separately injected synthetic omission events",
    originalDomainHash: fingerprint(canonical(f.domain.domain)),
    deployment: { transactionHash: f.mined.transactionHash, blockHash: f.mined.blockHash,
      blockNumber: f.mined.blockNumber, logCount: f.mined.logs.length, initialization: f.initialization },
    outcomes, preservedOriginalFiles: after.length, nonceRequests: 0, sends: 0, contractCalls: 0,
    sourceBoundPricingEventRetained: true,
    limits: ["Anvil is stopped; no live current census or fresh chain attestation.",
      "No owner-bond success, activation, readiness, shared gate or lifecycle completion claim."],
  }), { flag: "wx" });
} finally {
  await f.close();
  await writeFile(join(evidence, "cleanup.json"), canonical({
    serverClosed: true, fixtureDirectoryRemoved: f.root,
    fixtureEnvironmentRemoved: f.input.domain.rpcEnv, originalRpcAliasRestoredAfterProviderConstruction: true,
  }), { flag: "wx" });
}
console.log(canonical({ status: "PASS", evidence, outcomes: outcomes.length }));
