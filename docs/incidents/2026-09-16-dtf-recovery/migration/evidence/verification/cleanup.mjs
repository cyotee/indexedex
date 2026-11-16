import assert from "node:assert/strict";
import { readFile, writeFile, readdir, lstat, rm } from "node:fs/promises";
import { createConnection } from "node:net";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const out = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification`;
const runRoot = "/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/verification.30kbMI";
assert.equal(process.cwd(), root);
const pids = new Set();
const endpoints = new Set();
const roots = new Set([runRoot]);
function collect(value, key = "") {
  if (Array.isArray(value)) {
    for (const child of value) collect(child);
  } else if (value && typeof value === "object") {
    for (const [field, child] of Object.entries(value)) collect(child, field);
  } else if (typeof value === "number" && ["pid", "childPid", "anvilPid"].includes(key)) {
    pids.add(value);
  } else if (typeof value === "string" && ["endpoint", "local", "localUrl"].includes(key)
    && value.startsWith("http://127.0.0.1:")) {
    endpoints.add(value);
  } else if (typeof value === "string" && key === "runRoot") {
    assert.ok(value === runRoot || value.startsWith(`${runRoot}/`));
    roots.add(value);
  }
}
for (const filename of await readdir(out)) {
  if (filename.endsWith(".command.json") || filename.endsWith(".exit.json")
    || ["weighted-replay.results.json", "cp-replay.json", "other-replay.json",
      "other-metered.json", "native-replay.json", "witness.results.json",
      "witness-r4.results.json", "tokenstaking-caller.json"].includes(filename)) {
    const document = JSON.parse(await readFile(`${out}/${filename}`, "utf8"));
    // Restrict collection to resource/runtime metadata, never historic producer audits.
    collect(document.resources);
    if (document.runRoot) collect(document.runRoot, "runRoot");
    if (document.childPid) collect(document.childPid, "childPid");
    if (document.runtime?.pid) collect(document.runtime.pid, "pid");
  }
}
const processes = [];
for (const pid of pids) {
  assert.notEqual(pid, process.pid);
  let absent = false;
  try { process.kill(pid, 0); }
  catch (error) {
    assert.ok(error instanceof Error && "code" in error && error.code === "ESRCH");
    absent = true;
  }
  processes.push({ pid, absent });
}
const ports = [];
for (const endpoint of endpoints) {
  const url = new URL(endpoint);
  const result = await new Promise((resolve, reject) => {
    const socket = createConnection({ host: "127.0.0.1", port: Number(url.port) });
    socket.once("connect", () => { socket.destroy(); resolve({ endpoint, refused: false }); });
    socket.once("error", error => {
      if ("code" in error && error.code === "ECONNREFUSED") resolve({ endpoint, refused: true, code: error.code });
      else reject(error);
    });
    socket.setTimeout(2000, () => { socket.destroy(); reject(new Error(`TCP read-back timeout: ${endpoint}`)); });
  });
  ports.push(result);
}
const receipt = { runRoot, processes, ports, directories: [], deleted: false };
let scannedFiles = 0;
async function checkSecrets(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) await checkSecrets(path);
    else if (entry.isFile()) {
      const text = await readFile(path, "utf8");
      assert.ok(!process.env.ALCHEMY_KEY || !text.includes(process.env.ALCHEMY_KEY),
        `Credential unexpectedly persisted in ${entry.name}`);
      scannedFiles++;
    }
  }
}
await checkSecrets(out);
receipt.secretScan = { scannedFiles, credentialPresentForCheck: Boolean(process.env.ALCHEMY_KEY), pass: true };
await writeFile(`${out}/cleanup.json`, `${JSON.stringify(receipt, null, 2)}\n`);
assert.ok(processes.every(p => p.absent), "Owned PID remains; do not delete active runtime");
assert.ok(ports.every(p => p.refused), "Owned endpoint remains; do not delete active runtime");
const parentStat = await lstat(runRoot);
assert.ok(parentStat.isDirectory() && !parentStat.isSymbolicLink());
await rm(runRoot, { recursive: true });
receipt.deleted = true;
for (const path of roots) {
  let absent = false;
  try { await lstat(path); }
  catch (error) {
    assert.ok(error instanceof Error && "code" in error && error.code === "ENOENT");
    absent = true;
  }
  receipt.directories.push({ path, absent });
}
receipt.pass = receipt.directories.every(d => d.absent);
await writeFile(`${out}/cleanup.json`, `${JSON.stringify(receipt, null, 2)}\n`);
assert.ok(receipt.pass);
console.log(`VERIFICATION_CLEANUP_PASS pids=${processes.length} ports=${ports.length} directories=${roots.size}`);
