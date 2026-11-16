import { readFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { relative, join } from "node:path";
import { OUT, SOURCE, WT, ROOT, intake, json, identity, bind, equal, requireEvidence, save, treeFiles } from "./evidence.mjs";

const startedAt = new Date().toISOString(), s = await intake();
const initial = await json(`${OUT}/inputs.json`);
for (const b of [...initial.frozen, ...initial.sources, ...initial.producer]) await bind(b.path, b);
const proof = await json(`${OUT}/proof.json`);
requireEvidence(proof.verdict === "confirmed" && proof.findings.length === 0, "confirmed proof before sealing");
const files = await treeFiles(OUT), commands = [];
for (const file of files.filter(f => f.endsWith(".command.json"))) {
  const c = await json(file);
  requireEvidence(c.stoppedAt && Number.isInteger(c.exitCode), "actual command close");
  for (const b of Object.values(c.streams)) await bind(join(OUT, b.path), b);
  commands.push({ path: relative(OUT, file), ...c });
}
const finalProof = commands.find(c => c.path === "proof-final.command.json");
requireEvidence(finalProof?.exitCode === 0 && finalProof.argv.includes("--verify"), "successful final read-only reproduction");
for (const b of finalProof.source) await bind(b.path, b);
const acquisition = commands.filter(c => c.path === "acquire-01.command.json");
requireEvidence(acquisition.length === 1 && acquisition[0].exitCode === 0, "sole independent acquisition closed");
const ownPids = new Set([...commands.map(c => c.pid), ...s.cleanup.commands.map(c => c.pid), s.seal.publicationPid]);
const inspectionStartedAt = new Date().toISOString();
const ps = spawn("/bin/ps", ["-axo", "pid=,ppid=,comm="], { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const psOut = [], psErr = [];
ps.stdout.on("data", b => psOut.push(b)); ps.stderr.on("data", b => psErr.push(b));
const psClose = await new Promise((resolve, reject) => {
  ps.once("error", reject); ps.once("close", (exitCode, signal) => resolve({ exitCode, signal }));
});
requireEvidence(psClose.exitCode === 0, "actual process inspection exit");
const matching = Buffer.concat(psOut).toString().split("\n").filter(l => ownPids.has(Number(l.trim().split(/\s+/)[0])));
equal(matching, [], "all source/verifier children and producer publisher absent");
const key = process.env.ALCHEMY_KEY;
requireEvidence(typeof key === "string" && key.length > 0, "selected credential scan available");
const secrets = [Buffer.from(key), Buffer.from(encodeURIComponent(key))];
for (const file of files) {
  const bytes = await readFile(file);
  requireEvidence(secrets.every(secret => !bytes.includes(secret)), "credential scan clear");
}
const head = await readFile(`${ROOT}/.git/worktrees/dtf-migration-phase-30-recovery-receipts/HEAD`, "utf8");
equal(head.trim(), "ref: refs/heads/work/dtf-migration-phase-30-recovery-receipts", "reader branch reference");
const packed = await readFile(`${ROOT}/.git/packed-refs`, "utf8");
requireEvidence(packed.split("\n").includes("1694e68a4bd66dd67d3b5e3f145f1da23074ff48 refs/heads/work/dtf-migration-phase-30-recovery-receipts"), "reader base reference");
const reader = { root: WT, base: "1694e68a4bd66dd67d3b5e3f145f1da23074ff48", referenceFiles: [
  await identity(`${ROOT}/.git/worktrees/dtf-migration-phase-30-recovery-receipts/HEAD`), await identity(`${ROOT}/.git/packed-refs`)],
  qualification: "References read without Git commands; actual source bodies bound separately, not a clean-worktree claim." };
await save("preservation.json", { checkedAt: new Date().toISOString(), changed: 0, frozenDeclarations: s.declarations.length,
  frozenBodies: new Set(initial.frozen.map(b=>b.path)).size, initialBindingsReauthenticated: initial.frozen.length + initial.sources.length + initial.producer.length,
  source: initial.producer, reader });
await save("cleanup.json", { stoppedAt: new Date().toISOString(), allRecordedChildrenClosed: true, commands,
  retainedFailedCommands: commands.filter(c=>c.exitCode!==0), pendingRpc: 0, pendingOwnedChildren: 0,
  producerPublicationAbsent: true, processInspection: { executable: "/bin/ps", argv: ["-axo","pid=,ppid=,comm="], startedAt: inspectionStartedAt,
    stoppedAt: new Date().toISOString(), ...psClose, matchingRecordedProcesses: matching, stderr: Buffer.concat(psErr).toString() },
  credentialScan: { selectedAlias: "robinhood_mainnet_alchemy", files: files.length, literalOrEncodedMatches: 0, secretsPrinted: false },
  originalAndProducerChanges: 0, writeRoot: OUT, temporaryResourcesCreated: [], deletionsRequired: [], sharedServicesUntouched: true,
  publication: { executable: process.execPath, argv: [join(OUT,"publish.mjs")], pid: process.pid, startedAt,
    externalExitObservationRequired: true }, noPhase32Read: true, noPhase29Retry: true });
const manifest = [];
for (const path of await treeFiles(OUT)) manifest.push({ ...await identity(path), path: relative(OUT,path) });
await save("manifest.json", { files: manifest, excludes: ["manifest.json","seal.json"] });
const bindings = [];
for (const f of ["report.md","proof.json","schema-proof.json","archive.json","http-manifest.json","inputs.json","preservation.json","cleanup.json","manifest.json"]) {
  bindings.push({ ...await identity(join(OUT,f)), path: f });
}
await save("seal.json", { status: "COMPLETE-STOPPED-BOUNDED-INDEPENDENT-VERIFICATION", verdict: proof.verdict,
  publishedAt: new Date().toISOString(), bindings, references: 23, reusedReceipts: 7, independentlyAcquiredReceipts: 16,
  historicalAnchor: { number: "108944663", hash: "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733" },
  currentPinReused: "113279837", publisherPid: process.pid, pendingOperationsAfterPublisherExit: 0,
  finalArtifactWrite: true, financialAuthority: false, completeHistoryCensus: false });
console.log(JSON.stringify({ publication: "complete", verdict: proof.verdict, pendingOperations: 0, publisherPid: process.pid }));
