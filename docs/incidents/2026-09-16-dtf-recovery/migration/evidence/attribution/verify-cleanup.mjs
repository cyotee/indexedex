import assert from "node:assert/strict";
import { readFile, writeFile, rm, stat, readdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { createConnection } from "node:net";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const output = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/attribution`;
const runRoot = "/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/attribution.cIEIBO";
assert.equal(process.cwd(), root);
assert.equal(process.env.TMPDIR, runRoot);
const sha = (x) => createHash("sha256").update(x).digest("hex");
const json = async (name) => JSON.parse(await readFile(`${output}/${name}`, "utf8"));
const record = { invocation: `/opt/homebrew/bin/bun ${import.meta.path}`,
  passObservable: "exit 0 and ATTRIBUTION_EVIDENCE_AND_CLEANUP_PASS",
  runRoot, resources: [], inputIntegrity: [], checks: [], files: [] };
console.log(`INVOCATION ${record.invocation}`);
console.log(`PASS_OBSERVABLE ${record.passObservable}`);
const result = await json("witness-r3.results.json");
const audit = await json("witness-r3.producer-audit.json");
assert.equal(result.binaryPass, true);
assert.equal(result.runtime.sourceSha256, sha(await readFile(`${output}/witness.mjs`)));
assert.equal(result.pin.hash, "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733");
assert.equal(result.arithmetic.partitions, 5902);
assert.deepEqual(result.histories.h1.observations, result.histories.h2.observations);
assert.notEqual(result.histories.h1.required.a.c, result.histories.h2.required.a.c);
const receipts = [...result.setupReceipts, ...result.histories.h1.receipts, ...result.histories.h2.receipts];
assert.equal(receipts.length, 6);
for (const receipt of receipts) assert.equal(receipt.status, "0x1");
const publicCalls = result.rpc.filter((row) => row.endpoint !== "owned-local-anvil");
assert.ok(publicCalls.every((row) => ["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(row.method)));
record.checks.push({ name: "six_mined_transfers_distinct_credit_same_balances", pass: true });
record.checks.push({ name: "public_rpc_read_only", pass: true, calls: publicCalls.length });
record.checks.push({ name: "arithmetic_partitions", pass: true, count: 5902 });
for (const input of audit.inputs) {
  const unchanged = sha(await readFile(input.path)) === input.sha256;
  record.inputIntegrity.push({ path: input.path, unchanged });
  assert.equal(unchanged, true, input.path);
}
for (const [label, expected] of [["weighted", [34, 1, 2]], ["earlier", [18, 2, 4]], ["other", [21, 4, 3]]]) {
  const rows = audit.producerChecks[label];
  const counts = ["PASS", "FAIL", "UNPROVEN"].map((verdict) => rows.filter((row) => row.verdict === verdict).length);
  assert.deepEqual(counts, expected);
  record.checks.push({ name: `${label}_producer_verdicts_preserved`, pass: true, counts });
}
async function portClosed(endpoint) {
  return new Promise((resolve, reject) => {
    const socket = createConnection({ host: "127.0.0.1", port: Number(new URL(endpoint).port) });
    socket.once("connect", () => { socket.destroy(); resolve(false); });
    socket.once("error", (error) => {
      if ("code" in error && error.code === "ECONNREFUSED") resolve(true);
      else reject(error);
    });
    socket.setTimeout(1000, () => { socket.destroy(); reject(new Error("TCP readback timed out")); });
  });
}
for (const name of ["witness.results.json", "witness-r2.results.json", "witness-r3.results.json"]) {
  const attempt = await json(name);
  assert.equal(attempt.resources.runRoot, runRoot);
  if (!attempt.resources.anvilPid) {
    record.resources.push({ attempt: name, noChildStarted: true });
    continue;
  }
  let pidGone = false;
  try { process.kill(attempt.resources.anvilPid, 0); }
  catch (error) {
    assert.ok(error instanceof Error && "code" in error && error.code === "ESRCH");
    pidGone = true;
  }
  const closed = await portClosed(attempt.resources.endpoint);
  record.resources.push({ attempt: name, pid: attempt.resources.anvilPid,
    endpoint: attempt.resources.endpoint, pidGone, portClosed: closed });
  assert.equal(pidGone, true);
  assert.equal(closed, true);
}
const spec = await readFile(`${output}/../../attribution-spec.md`, "utf8");
record.reportWords = spec.trim().split(/\s+/).length;
assert.ok(record.reportWords <= 5000);
for (const name of (await readdir(output)).sort()) {
  if (name === "cleanup.json" || name === "cleanup.stdout.log") continue;
  const bytes = await readFile(`${output}/${name}`);
  record.files.push({ path: `${output}/${name}`, bytes: bytes.length, sha256: sha(bytes) });
}
record.runRootBefore = (await stat(runRoot)).isDirectory();
assert.equal(record.runRootBefore, true);
await rm(runRoot, { recursive: true });
try { await stat(runRoot); record.runRootAfter = "present"; }
catch (error) {
  assert.ok(error instanceof Error && "code" in error && error.code === "ENOENT");
  record.runRootAfter = "absent";
}
assert.equal(record.runRootAfter, "absent");
record.pass = true;
await writeFile(`${output}/cleanup.json`, `${JSON.stringify(record, null, 2)}\n`);
console.log("ATTRIBUTION_EVIDENCE_AND_CLEANUP_PASS");
