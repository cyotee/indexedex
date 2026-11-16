import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { OUT, SOURCE, intake, identity, json, save, check } from "./intake.mjs";

const intakeResult = await intake(), proof = await json(join(OUT, "proof.json"));
check(proof.verdict === "confirmed" && proof.rows.length === 59 && proof.pendingOperations.length === 0, "incomplete proof");
const commands = [];
for (const name of await readdir(OUT)) if (name.endsWith(".command.json")) {
  const c = await json(join(OUT, name));
  check(c.childCloseObserved && c.exitCode === 0 && c.stoppedAt && c.signal === null, "unstopped or failing owned command");
  commands.push({ path: name, pid: c.pid, exitCode: c.exitCode, stoppedAt: c.stoppedAt });
}
check(commands.length === 12, "expected ten syntax checks, one observer, one proof");
const scan = [], matches = [];
async function walk(dir) {
  for (const item of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, item.name);
    if (item.isDirectory()) await walk(path);
    else {
      check(item.isFile(), "unexpected output symlink");
      const bytes = await readFile(path);
      for (const secret of [process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")].filter(Boolean)) {
        if (bytes.includes(Buffer.from(secret))) matches.push(path);
      }
      scan.push(await identity(path));
    }
  }
}
await walk(OUT);
check(Boolean(process.env.ALCHEMY_KEY) && matches.length === 0, "credential scan unavailable or failed");
const dead = [];
for (const pid of [...commands.map(x => x.pid), ...intakeResult.cleanup.commands.map(x => x.pid), intakeResult.cleanup.finalPublisher.pid]) {
  try { process.kill(pid, 0); }
  catch (error) {
    if (!(error instanceof Error) || !("code" in error) || error.code !== "ESRCH") throw error;
    dead.push(pid); continue;
  }
  check(false, `recorded child PID still exists: ${pid}`);
}
await save("cleanup.json", { status: "STOPPED-BOUNDED-INDEPENDENT-VERIFICATION", capturedAt: new Date().toISOString(),
  commands, confirmedAbsentRecordedPids: dead, producerSeal: await identity(join(SOURCE, "seal.json")),
  inputsReauthenticated: intakeResult.declarations.length, sourceBindingsReauthenticated: intakeResult.sourceBindings.length,
  pendingOwnedOperations: [], rpcRequestsAwaited: true, noSigningOrLiveWrites: true,
  serversStarted: 0, localChainsStarted: 0, subagentsStarted: 0, installsOrForgeOrFullSuites: false,
  cleanupDeletions: [], temporaryRuntimesCreated: 0, writesOnlyInsideVerification: true,
  credentialScan: { files: scan.length, matches: 0 }, finalPublisher: { pid: process.pid,
    meaning: "seal is last write; require external monitored exit before claiming stopped publication" } });
const manifest = [...scan, await identity(join(OUT, "cleanup.json"))].map(x => ({ ...x, path: x.path.slice(OUT.length + 1) }))
  .sort((a, b) => a.path.localeCompare(b.path));
await save("manifest.json", manifest);
const bindings = [];
for (const name of ["report.md", "proof.json", "pin.json", "end-canonical.json", "observations.json", "inputs.json",
  "http-manifest.json", "cleanup.json", "manifest.json"]) bindings.push({ ...await identity(join(OUT, name)), path: name });
await save("seal.json", { version: "phase31-independent-nft-verification-v1", verdict: "confirmed",
  publishedAt: new Date().toISOString(), rows: 59, pin: proof.pin, canonical: true, bindings,
  producerSeal: await identity(join(SOURCE, "seal.json")), pendingOperations: 0, finalPublication: true,
  command: { executable: process.execPath, argv: [join(OUT, "finalize.mjs")], cwd: OUT },
  limits: "bounded named observations only; no eligibility, E0/D0/credit, full-source, full-plan or operational approval" });
console.log(JSON.stringify({ sealed: true, verdict: "confirmed", rows: 59, files: manifest.length }));
