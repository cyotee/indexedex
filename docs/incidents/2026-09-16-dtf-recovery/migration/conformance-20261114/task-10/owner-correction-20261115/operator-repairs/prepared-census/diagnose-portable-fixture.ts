import assert from "node:assert/strict";
import { join } from "node:path";
import { z } from "zod";
import { mixedFixture } from "../../../../task-12/mixed-fixture.js";
import { assemble, normalize } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.js";
import { loadExecution, compensationEventTopics } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { verifyConfiguration } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { exportBundle } from "../../../../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { materializeBundle } from "../../../../../../../../../scripts/recovery/dtf-migration/bundle-materialize.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { canonical } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { rpcLog } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const f = await mixedFixture();
try {
  const omitted = assemble(normalize({ ...f.finalPrepared.input, weightedSy: [],
    exposures: f.finalPrepared.input.exposures.filter((r) => r.category !== "weighted-sy") }), f.finalPrepared.quoteEvidence);
  const prepared = await f.save("diagnostic-omitted.json", omitted);
  const native = await loadExecution(f.manifestPath);
  const execution = await f.save("diagnostic-execution.json", { ...native.manifest, preparedManifest: prepared.path });
  const bundle = await exportBundle(execution.path, join(f.root, "diagnostic-bundle"));
  const materialized = await materializeBundle(bundle, join(f.root, "diagnostic-materialized"));
  assert.equal(materialized.kind, "execution");
  if (materialized.kind !== "execution") throw new TypeError("execution fixture required");
  const domain = await loadExecution(materialized.manifest);
  const rpc = new Rpc(domain.manifest);
  try {
    const topics = compensationEventTopics(domain.abis.migration, "configuration");
    const query = { address: domain.manifest.proxy, fromBlock: "0x5a", toBlock: "latest", topics: [topics] };
    const key = [...f.changes.logs.keys()].find((candidate) => candidate.startsWith("{"));
    assert.ok(key);
    const originalRows = z.array(rpcLog).parse(f.changes.logs.get(key));
    assert.equal(f.changes.logs.get(canonical(query)), undefined);
    const before = await verifyConfiguration(rpc, domain);
    assert.equal(before.rows.length, 1);
    // Counterfactual transport correction only. Neither the SUT nor fixture source changes.
    assert.ok(originalRows.every((row) => topics.includes(row.topics[0] ?? "")));
    f.changes.logs.set(canonical(query), originalRows);
    await assert.rejects(verifyConfiguration(rpc, domain), /configured original omitted from complete deployment census/);
    console.log(canonical({ status: "diagnosed", unchangedFixtureSource: "task-12/mixed-fixture.ts",
      staleQuery: JSON.parse(key), actualQuery: query, configurationRows: originalRows.length,
      before: "omission incorrectly admitted by empty fixture response",
      after: "same product code rejects omission with the existing configuration rows",
      limit: "Only an in-memory synthetic transport correction; no source file outside this evidence directory was edited" }));
  } finally { rpc.close(); }
} finally { await f.close(); }
