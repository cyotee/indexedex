import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { z } from "zod";
import { preparedContext, preparedFaults, probePreparedFault, preparedFaultReasons } from "./prepared-context.js";
import { compensationEvents } from "../empty-census/census-context.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";

const evidence = await mkdtemp(join(dirname(fileURLToPath(import.meta.url)), "manual-prepared-"));
const cleanups: string[] = [];
const results: { readonly name: string; readonly result: unknown }[] = [];
const withContext = async (name: string, run: (f: Awaited<ReturnType<typeof preparedContext>>) => Promise<unknown>) => {
  const f = await preparedContext();
  try { results.push({ name, result: await run(f) }); }
  finally {
    await f.close();
    cleanups.push(f.root);
    await writeFile(join(evidence, `cleanup-${cleanups.length}.json`),
      canonical({ closed: true, removedDirectory: f.root, removedRpcAlias: f.input.domain.rpcEnv }), { flag: "wx" });
  }
};
const rejection = async (run: () => Promise<unknown>, expected: RegExp) => {
  const failure = await run().then(() => undefined, (error: unknown) => {
    if (!(error instanceof Error)) throw error;
    return error;
  });
  assert.ok(failure, "controlled rejection required");
  assert.match(failure.message, expected);
  return { rejected: true, error: failure.name, message: failure.message };
};
await withContext("public CLI initialized prepared verification and activation preflight", async (f) => {
  const protectedPaths = [f.manifestPath, f.preparedPath];
  const before = await Promise.all(protectedPaths.map((path) => readFile(path)));
  const outputs = [];
  for (const command of ["verify", "activate", "verify"]) {
    const argv = [process.execPath, "scripts/recovery/dtf-migration/cli.ts", command,
      "--manifest", f.manifestPath, "--checkpoint", join(f.root, "manual-readonly")];
    const child = spawn(process.execPath, argv.slice(1), { env: process.env, stdio: ["ignore", "pipe", "pipe"],
      timeout: 15000, killSignal: "SIGKILL" });
    const done = once(child, "exit", { signal: AbortSignal.timeout(20000) });
    assert.ok(child.stdout && child.stderr);
    const [stdout, stderr, [exit]] = await Promise.all([text(child.stdout), text(child.stderr), done]);
    await writeFile(join(evidence, `cli-${outputs.length}.json`), canonical({ argv, cwd: process.cwd(), exit, stdout, stderr }), { flag: "wx" });
    assert.equal(exit, 0, stderr);
    assert.equal(stderr, "");
    const result = z.object({ command: z.string(), mode: z.literal("read-only") }).passthrough().parse(JSON.parse(stdout));
    assert.equal(result.command, command);
    outputs.push(result);
  }
  const after = await Promise.all(protectedPaths.map((path) => readFile(path)));
  assert.deepEqual(after, before);
  for (const [index, bytes] of before.entries()) {
    await writeFile(join(evidence, `synthetic-original-${index}.json`), bytes, { flag: "wx" });
  }
  const originalAfter = await Promise.all(f.actual.bindings.map(async (binding) => {
    const bytes = await readFile(binding.path);
    return { path: binding.path, sha256: fingerprint(bytes), bytes: String(bytes.length) };
  }));
  assert.deepEqual(originalAfter, f.actual.bindings);
  await writeFile(join(evidence, "original-evidence-bindings.json"),
    canonical({ before: f.actual.bindings, after: originalAfter }), { flag: "wx" });
  await writeFile(join(evidence, "rpc-requests.json"), canonical(f.requests), { flag: "wx" });
  assert.equal(f.methods.includes("eth_getTransactionCount"), false);
  assert.equal(f.methods.includes("eth_sendRawTransaction"), false);
  return { outputs, originalEvidenceFilesPreserved: originalAfter.length, actualInitialization: f.actual.initialization,
    syntheticInitialization: f.initialization, configured: f.configured,
    syntheticPreparedHash: f.prepared.normalizedHash, syntheticPayloadHash: f.prepared.payloadHash,
    syntheticFiles: protectedPaths.map((path, index) => ({ path, sha256: fingerprint(z.instanceof(Buffer).parse(before[index])) })),
    provenance: "Exact saved initialization topics/data; deployment metadata, new preparation, expected compensation and getter state are synthetic. No retained domain is rebound.",
    nonceRequests: 0, sends: 0 };
});
for (const event of compensationEvents.filter(([name]) => name !== "IndependentAllocationIssued")) for (const offset of [0n, 20n]) {
  await withContext(`omitted ${event[0]} at deployment offset ${offset}`, async (f) => {
    f.omitted(event, offset);
    return rejection(() => f.verify(), /configured original omitted from complete deployment census/);
  });
}
for (const fault of preparedFaults) {
  await withContext(fault, (f) => rejection(() => probePreparedFault(f, fault), preparedFaultReasons[fault]));
}
await writeFile(join(evidence, "result.json"), canonical({
  status: "PASS", results, cleanups, scope: "Prepared verify and read-only activation preflight on explicitly synthetic transport",
  limits: ["No fresh Anvil or public chain state", "No paid owner-bond or lifecycle claim", "Original signed history remains unchanged"],
}), { flag: "wx" });
console.log(canonical({ status: "PASS", evidence, scenarios: results.length, cleanups: cleanups.length }));
