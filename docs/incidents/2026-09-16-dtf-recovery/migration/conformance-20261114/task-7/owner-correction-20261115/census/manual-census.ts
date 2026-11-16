import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { z } from "zod";
import { censusFixture } from "../../../../../../../../scripts/recovery/dtf-migration/execution.fixture.js";
import { loadExecution } from "../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { canonical, fingerprint } from "../../../../../../../../scripts/recovery/dtf-migration/provenance.js";

const evidence = await mkdtemp(join(dirname(fileURLToPath(import.meta.url)), "manual-"));
const f = await censusFixture();
const children: { readonly argv: readonly string[]; readonly exit: number;
  readonly stdout: string; readonly stderr: string }[] = [];
try {
  const protectedFiles = [f.A.preparedPath, f.A.manifestPath, f.A.journalPath, f.A.intentPath,
    f.B.journalPath, f.B.intentPath];
  const before = await Promise.all(protectedFiles.map((path) => readFile(path)));
  const checkpointBefore = await readdir(f.B.checkpoint);
  for (const [i, bytes] of before.entries()) {
    await writeFile(join(evidence, `original-${i}.json`), bytes, { flag: "wx" });
  }
  const invoke = async (args: readonly string[], expectedExit: number) => {
    const argv = [process.execPath, "scripts/recovery/dtf-migration/cli.ts", ...args];
    const child = spawn(process.execPath, argv.slice(1), { env: process.env,
      stdio: ["ignore", "pipe", "pipe"], timeout: 15000, killSignal: "SIGKILL" });
    const done = once(child, "exit", { signal: AbortSignal.timeout(20000) });
    assert.ok(child.stdout && child.stderr);
    const [stdout, stderr, [code]] = await Promise.all([text(child.stdout), text(child.stderr), done]);
    const exit = z.number().parse(code);
    children.push({ argv, exit, stdout, stderr });
    await writeFile(join(evidence, `child-${children.length}.json`),
      canonical({ argv, exit, stdout, stderr, signal: child.signalCode }), { flag: "wx" });
    assert.equal(exit, expectedExit, stderr);
    if (expectedExit === 0) {
      assert.equal(stderr, "");
      return z.object({ mode: z.literal("read-only"), command: z.string() }).passthrough().parse(JSON.parse(stdout));
    }
    assert.equal(stdout, "");
    return z.object({ error: z.literal("PROVENANCE"),
      message: z.string().regex(/previously configured SY origin omitted from complete census/) }).parse(JSON.parse(stderr));
  };
  const beforeY = await invoke(["validate", "--manifest", f.A.preparedPath], 0);
  const beforeB = await loadExecution(f.B.manifestPath);
  assert.equal(beforeB.prepared?.payloadHash, f.B.domain.prepared.payloadHash);
  f.publishY();
  f.changes.quoteDelta = 1n;
  const requestStart = f.requests.length;
  const loaded = await loadExecution(f.B.manifestPath);
  assert.equal(loaded.prepared?.payloadHash, f.B.domain.prepared.payloadHash);
  const complete = await invoke(["validate", "--manifest", f.B.preparedPath], 0);
  const stageArgs = ["--manifest", f.B.manifestPath, "--checkpoint", f.B.checkpoint];
  const verified = await invoke(["verify", ...stageArgs], 0);
  const resumed = [];
  for (let i = 0; i < 2; i++) {
    const result = await invoke(["resume", ...stageArgs], 0);
    const parsed = z.object({ operationIds: z.array(z.string()), fullTask9: z.literal("open") }).passthrough().parse(result);
    assert.deepEqual(parsed.operationIds, [f.B.record.id]);
    resumed.push(parsed);
  }
  const rejections = [];
  for (const ids of [...f.B.domain.prepared.payloads.configure.weightedSy.map((r) => [r.input.originalId]), []]) {
    const incomplete = await f.incomplete(ids);
    rejections.push({ rows: ids, result: await invoke(["validate", "--manifest", incomplete.preparedPath], 1) });
  }
  const after = await Promise.all(protectedFiles.map((path) => readFile(path)));
  assert.deepEqual(after, before);
  assert.deepEqual(await readdir(f.B.checkpoint), checkpointBefore);
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  const preview = f.domain.abis.migration.getFunction("previewOriginalCredit");
  assert.ok(preview);
  const requotes = f.requests.slice(requestStart).filter((r) => r.method === "eth_call"
    && JSON.stringify(r.params).includes(preview.selector));
  assert.equal(requotes.length, 0);
  await writeFile(join(evidence, "B-prepared.json"), canonical(f.B.domain.prepared), { flag: "wx" });
  await writeFile(join(evidence, "rpc-requests.json"), canonical(f.requests), { flag: "wx" });
  await writeFile(join(evidence, "result.json"), canonical({
    status: "PASS", scope: "read-only synthetic RPC authentication; no EVM lifecycle completion",
    beforeY, beforeB: { normalizedHash: beforeB.prepared?.normalizedHash, payloadHash: beforeB.prepared?.payloadHash },
    afterY: { normalizedHash: loaded.prepared?.normalizedHash, payloadHash: loaded.prepared?.payloadHash },
    complete, verified, resumed, rejections, children,
    historicalBytes: before.map((bytes, i) => {
      const afterBytes = after[i];
      assert.ok(afterBytes);
      return { path: protectedFiles[i], captured: `original-${i}.json`,
        before: fingerprint(bytes), after: fingerprint(afterBytes) };
    }),
    domainHashes: { A: f.A.record.domainHash, B: f.B.record.domainHash },
    currentRows: f.B.domain.prepared.payloads.configure.weightedSy.map((r) => ({
      originalId: r.input.originalId, configurationId: r.configurationId, pricing: r.pricing.kind, credit: r.quotedCredit })),
    configured: f.configured, checkpointBefore, checkpointAfter: await readdir(f.B.checkpoint),
    addedNonceRequests: 0, sends: 0, newIntents: 0, requotes: requotes.length,
  }), { flag: "wx" });
} finally {
  await f.close();
  await writeFile(join(evidence, "cleanup.json"), canonical({
    serverClosed: true, removedFixtureDirectory: f.root, rpcEnvironmentRemoved: f.input.domain.rpcEnv,
    retained: "captured evidence only",
  }), { flag: "wx" });
}
console.log(canonical({ status: "PASS", evidence, childExits: children.map((c) => c.exit) }));
