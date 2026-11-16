// Evidence-only local transport QA. No Anvil, public RPC, or real chain claim.
import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { configurationTransport, requireInterruption } from "./transport.fixture.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { configurationKey } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";

const evidence = await mkdtemp(join(dirname(fileURLToPath(import.meta.url)), "manual-attempt-"));
const save = (name: string, value: unknown) => writeFile(join(evidence, name), canonical(value), { flag: "wx" });
const files = ["execution.ts", "execution.test.ts", "execution-domain.ts", "execution-state.ts",
  "execution-rpc.ts", "execution-plan.ts", "journal.ts", "execution.fixture.ts", "preparation.fixture.ts"];
const sources = await Promise.all(files.map(async (file) => {
  const path = resolve("scripts/recovery/dtf-migration", file);
  const bytes = await readFile(path);
  return { path, sha256: fingerprint(bytes), bytes: bytes.length };
}));
await save("source-fingerprints.json", sources);
const results: unknown[] = [];
try {
  for (const kind of ["independent", "nft-components"] as const) {
    const f = await configurationTransport(kind);
    try {
      const record = await requireInterruption(f);
      const original = await readFile(join(f.checkpoint, `${record.id}.intent.json`));
      const receipt = f.changes.receipts.get(record.transactionHash);
      await save(`${kind}-intent.json`, record);
      await save(`${kind}-canonical-receipt.json`, receipt);
      await save(`${kind}-interrupted-journal.json`, {
        names: await readdir(f.checkpoint), domain: f.domain.domain, counts: f.counts(),
      });
      const counts = f.counts();
      f.staleBook();
      const abi = f.domain.abis.migration;
      const data = abi.encodeFunctionData(f.getter, configurationKey(f.row));
      const old = f.changes.reads.get(data + "@latest");
      assert.ok(old);
      const components = abi.getFunction(f.getter)?.outputs[0]?.components;
      assert.ok(components);
      const configurationIndex = components.findIndex((field) => field.name === "configurationId");
      assert.notEqual(configurationIndex, -1);
      const state: readonly unknown[] = abi.decodeFunctionResult(f.getter, old)[0].toArray();
      const replacement = abi.encodeFunctionResult(f.getter, [state.map((value, i) => i === configurationIndex ? h(999) : value)]);
      f.changes.reads.set(data + "@latest", replacement);
      const completions = [];
      for (let i = 0; i < 2; i++) {
        const resumed = await f.cli(["resume", ...f.localArgs, "--fault-after-mined"]);
        assert.equal(resumed.code, 0, resumed.output);
        assert.equal(resumed.signal, null);
        const result = await f.completed();
        assert.equal(result.receipt.transactionHash, record.transactionHash);
        assert.equal(result.intentHash, fingerprint(canonical(record)));
        assert.deepEqual(result.receipt, receipt);
        assert.deepEqual(f.counts(), counts);
        assert.deepEqual(await readFile(join(f.checkpoint, `${record.id}.intent.json`)), original);
        assert.equal(f.changes.reads.get(data + "@latest"), replacement);
        assert.deepEqual((await readdir(f.checkpoint)).filter((n) => n.endsWith(".receipt.json")), [`${record.id}.receipt.json`]);
        completions.push(result);
      }
      await save(`${kind}-resumed-completions.json`, completions);
      await save(`${kind}-requests.json`, f.requests);
      await save(`${kind}-stale-latest-state.json`, { replacement, countsBeforeResume: counts, countsAfterResume: f.counts() });
      results.push({ kind, state: "pass", originalHash: record.transactionHash, nonce: record.nonce,
        sends: counts.sends, nonceRequests: counts.nonces, repeatedResumes: 2, completionFiles: 1 });
    } finally {
      await save(`${kind}-cli-commands.json`, f.invocations);
      for (const [i, invocation] of f.invocations.entries()) {
        await writeFile(join(evidence, `${kind}-cli-${i + 1}.log`), invocation.output, { flag: "wx" });
      }
      await f.close();
      await save(`${kind}-cleanup.json`, { childProcesses: "exited", transport: "stopped", fixtureRoot: f.root, removed: true });
    }
  }
  for (const mutation of ["wrong-hash", "malformed-receipt", "malformed-intent", "simulation"] as const) {
    const f = await configurationTransport();
    try {
      if (mutation !== "simulation") {
        const record = await requireInterruption(f);
        const receipt = f.changes.receipts.get(record.transactionHash);
        assert.ok(receipt && typeof receipt === "object");
        switch (mutation) {
          case "wrong-hash": f.changes.receipts.set(record.transactionHash, { ...receipt, transactionHash: h(999) }); break;
          case "malformed-receipt": f.changes.receipts.set(record.transactionHash, { ...receipt, status: "success" }); break;
          case "malformed-intent": await writeFile(join(f.checkpoint, `${record.id}.intent.json`), '{"nonce":'); break;
          default: { const unreachable: never = mutation; throw new Error(unreachable); }
        }
      }
      const counts = f.counts();
      const rejected = await f.cli(mutation === "simulation"
        ? ["configure", "--fault-after-mined"] : ["resume", ...f.localArgs, "--fault-after-mined"]);
      assert.equal(rejected.code, 1, rejected.output);
      assert.equal(rejected.signal, null);
      assert.equal(JSON.parse(rejected.output).error, mutation === "wrong-hash" ? "AMBIGUOUS" : mutation === "simulation" ? "DOMAIN" : "INPUT");
      assert.deepEqual(f.counts(), counts);
      const names = mutation === "simulation" ? [] : await readdir(f.checkpoint);
      assert.equal(names.some((n) => n.endsWith(".receipt.json") || n === "terminal.json"), false);
      await save(`${mutation}-commands.json`, f.invocations);
      await save(`${mutation}-requests.json`, f.requests);
      results.push({ mutation, state: "rejected", counts, completionFiles: 0 });
    } finally { await f.close(); }
  }
  await save("result.json", { type: "ConfigureFaultTransportQA", state: "pass", results,
    channel: "production CLI with synthetic local transport facts; not Anvil chain evidence",
    cleanup: "all owned children exited, servers stopped, temporary fixture roots removed" });
  console.log(JSON.stringify({ state: "pass", evidence, results }));
} catch (error) {
  await save("failure.json", { message: error instanceof Error ? error.message : String(error), results });
  throw error;
}
