import assert from "node:assert/strict";
import { readFile, writeFile, lstat, rm } from "node:fs/promises";
import { createConnection } from "node:net";
const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const out = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification`;
assert.equal(process.cwd(), root);
const runtimeRoot = process.env.TMPDIR;
assert.match(runtimeRoot ?? "", /\/tmp\.enuGXu0sUI\/verification-final\.[A-Za-z0-9]+$/);
const receipt = {
  invocation: process.argv, cwd: process.cwd(), started: new Date().toISOString(),
  binaryPassObservable: "All recorded PIDs ESRCH, six TCP endpoints ECONNREFUSED, prior roots ENOENT; final own root removed with ENOENT",
  environment: Object.fromEntries(["TMPDIR", "BUN_INSTALL_CACHE_DIR", "npm_config_cache",
    "XDG_CACHE_HOME", "NODE_COMPILE_CACHE", "BUN_RUNTIME_TRANSPILER_CACHE_PATH"].map(k => [k, process.env[k]])),
  processes: [], ports: [], directories: [], originalRootRemovedByThisRun: false,
};
await writeFile(`${out}/cleanup-readback.command.json`, `${JSON.stringify(receipt, null, 2)}\n`);
const inherited = JSON.parse(await readFile(`${out}/cleanup.json`, "utf8"));
const recovery = JSON.parse(await readFile(`${out}/recovery-cleanup.json`, "utf8"));
for (const pid of new Set([...inherited.processes.map(p => p.pid), ...recovery.extraProcesses.map(p => p.pid)])) {
  let absent = false;
  try { process.kill(pid, 0); }
  catch (error) {
    assert.ok(error instanceof Error && "code" in error && error.code === "ESRCH");
    absent = true;
  }
  receipt.processes.push({ pid, absent });
}
for (const { endpoint } of inherited.ports) {
  const result = await new Promise((resolve, reject) => {
    const socket = createConnection({ host: "127.0.0.1", port: Number(new URL(endpoint).port) });
    socket.once("connect", () => { socket.destroy(); resolve({ endpoint, refused: false }); });
    socket.once("error", error => {
      if ("code" in error && error.code === "ECONNREFUSED") resolve({ endpoint, refused: true, code: error.code });
      else reject(error);
    });
    socket.setTimeout(2000, () => { socket.destroy(); reject(new Error(`TCP readback timeout ${endpoint}`)); });
  });
  receipt.ports.push(result);
}
for (const path of [...inherited.directories.map(d => d.path), recovery.recoveryRoot.path]) {
  let absent = false;
  try { await lstat(path); }
  catch (error) {
    assert.ok(error instanceof Error && "code" in error && error.code === "ENOENT");
    absent = true;
  }
  receipt.directories.push({ path, absent });
}
const ownStat = await lstat(runtimeRoot);
assert.ok(ownStat.isDirectory() && !ownStat.isSymbolicLink());
await rm(runtimeRoot, { recursive: true });
try { await lstat(runtimeRoot); receipt.finalRootAbsent = false; }
catch (error) {
  assert.ok(error instanceof Error && "code" in error && error.code === "ENOENT");
  receipt.finalRootAbsent = true;
}
receipt.pass = receipt.processes.every(p => p.absent) && receipt.ports.every(p => p.refused)
  && receipt.directories.every(p => p.absent) && receipt.finalRootAbsent;
await writeFile(`${out}/cleanup-independent-readback.json`, `${JSON.stringify(receipt, null, 2)}\n`);
console.log(`INDEPENDENT_CLEANUP_READBACK_${receipt.pass ? "PASS" : "FAIL"} pids=${receipt.processes.length} ports=${receipt.ports.length} directories=${receipt.directories.length + 1}`);
process.exitCode = receipt.pass ? 0 : 2;
