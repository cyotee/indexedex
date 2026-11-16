import { execFile } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { OUT, intake, json, identity, save, check } from "./inputs.mjs";

const startedAt = new Date().toISOString(), s = await intake();
const archive = await json(join(OUT, "archive.json")), proof = await json(join(OUT, "proof.json"));
const review = await json(join(OUT, "reconciliation.json"));
check(archive.pendingRequests === 0 && !archive.blocker && archive.endCanonical.matches, "collector stopped cleanly");
check(proof.refs === 23 && proof.new === 16 && proof.reused === 7 && proof.allNewRequestsAccounted, "complete raw proof");
check(review.confirmed === 23 && review.originals.length === 43, "all dispositions");
const files = [];
async function visit(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    check(!entry.isSymbolicLink(), "owned output symlink");
    if (entry.isDirectory()) await visit(path);
    else { check(entry.isFile(), "regular output file"); files.push(path); }
  }
}
await visit(OUT);
const commands = [];
for (const path of files.filter(p => p.endsWith(".command.json"))) {
  const c = await json(path);
  check(c.childCloseObserved && c.stoppedAt && Number.isInteger(c.exitCode), `unstopped command ${path}`);
  for (const stream of Object.values(c.streams)) {
    const actual = await identity(stream.path);
    check(actual.bytes === stream.bytes && actual.sha256 === stream.sha256 && stream.raw, "command streams");
  }
  commands.push({ path, executable: c.executable, argv: c.argv, pid: c.pid,
    startedAt: c.startedAt, stoppedAt: c.stoppedAt, exitCode: c.exitCode, signal: c.signal });
}
check(commands.some(c => c.path.endsWith("prove-final-01.command.json") && c.exitCode === 0), "final proof actually stopped");
check(commands.filter(c => c.path.includes("/validate-final-")).length === 9
  && commands.filter(c => c.path.includes("/validate-final-")).every(c => c.exitCode === 0), "final syntax/intake checks");
const processStart = new Date().toISOString();
const ps = await new Promise((resolve, reject) => {
  execFile("/bin/ps", ["-axo", "pid=,ppid=,command="], { maxBuffer: 16 * 1024 * 1024 }, (error, stdout, stderr) => {
    if (error) reject(error);
    else resolve({ stdout, stderr, stoppedAt: new Date().toISOString(), exitCode: 0 });
  });
});
const processes = ps.stdout.split("\n").map(line => {
  const m = line.match(/^\s*(\d+)\s+(\d+)\s+(.*)$/);
  return m ? { pid: Number(m[1]), parent: Number(m[2]), command: m[3] } : null;
}).filter(Boolean);
const ancestors = new Set([process.pid]);
let cursor = process.pid;
while (cursor > 1) {
  const p = processes.find(p => p.pid === cursor);
  if (!p) break;
  cursor = p.parent; ancestors.add(cursor);
}
const related = processes.filter(p => p.command.includes(OUT) && /\.mjs(?:\s|$)/.test(p.command));
const pending = related.filter(p => !ancestors.has(p.pid));
check(pending.length === 0, "owned process remains");
const key = process.env.ALCHEMY_KEY;
check(Boolean(key), "selected credential needed for final private scan");
let scanned = 0;
for (const path of files) {
  const bytes = await readFile(path);
  for (const secret of [key, encodeURIComponent(key)]) check(!bytes.includes(Buffer.from(secret)), "credential found in owned evidence");
  scanned++;
}
await save("cleanup.json", { stoppedAt: new Date().toISOString(), allRecordedChildrenClosed: true,
  commands: commands.sort((a, b) => a.path.localeCompare(b.path)), retainedFailedCommands: commands.filter(c => c.exitCode !== 0),
  pendingRpc: 0, pendingOwnedChildren: 0, sharedServicesUntouched: true,
  processInspection: { executable: "/bin/ps", argv: ["-axo", "pid=,ppid=,command="], startedAt: processStart,
    stoppedAt: ps.stoppedAt, exitCode: ps.exitCode, retainedOutput: "only owned source-script matches; unrelated process arguments discarded",
    matchingOwnedProcesses: related, pending, publicationProcessExcludedUntilObservedExit: process.pid },
  credentialScan: { selectedAlias: "robinhood_mainnet_alchemy", files: scanned, literalOrEncodedMatches: 0, secretsPrinted: false },
  inputReauthentication: { declarations: s.originals.declarations.length, bodies: s.originals.identities.length, bindings: s.bindings.length, changed: 0 },
  temporaryResourcesCreated: [], deletionsRequired: [], ownedWriteRoot: OUT,
  publication: { executable: process.execPath, argv: [join(OUT, "seal.mjs")], pid: process.pid, startedAt,
    monitorMustObserveExitBeforeHandoff: true } });
files.push(join(OUT, "cleanup.json"));
const manifest = await Promise.all(files.sort().map(async path => {
  const b = await identity(path);
  return { ...b, path: path.slice(OUT.length + 1) };
}));
await save("manifest.json", { status: "STOPPED-BOUNDED-PRODUCER", files: manifest, excludes: ["manifest.json", "seal.json"] });
const names = ["report.md", "proof.json", "reconciliation.json", "archive.json", "schema-bindings.json",
  "inputs.json", "source-manifest.json", "http-manifest.json", "references.json", "cleanup.json", "manifest.json"];
const bindings = await Promise.all(names.map(async name => ({ ...await identity(join(OUT, name)), path: name })));
await save("seal.json", { version: "phase33-named-claims-producer-v1", publishedAt: new Date().toISOString(),
  status: "COMPLETE-STOPPED-BOUNDED-PRODUCER", bindings, references: 23, reusedReceipts: 7, newReceipts: 16,
  pendingOperationsAfterPublisherExit: 0, independentLiveVerification: "separate-role-not-claimed",
  finalArtifactWrite: true, publicationPid: process.pid, scope: "named evidence only; no census, source or financial authority" });
console.log(JSON.stringify({ sealed: true, files: manifest.length, commandRecords: commands.length, pendingOperationsAfterExit: 0 }));
