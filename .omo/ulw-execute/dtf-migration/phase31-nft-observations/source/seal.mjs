import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { OUT, identity, intake, json, save, requireFact } from "./evidence.mjs";

const source = await intake();
requireFact(JSON.stringify(source.bindings) === JSON.stringify(await json(join(OUT, "source-manifest.json"))), "source preservation mismatch");
const commands = [];
for (const name of await readdir(OUT)) if (name.endsWith(".command.json")) {
  const command = await json(join(OUT, name));
  requireFact(command.childCloseObserved && command.stoppedAt && command.exitCode === 0, `command did not complete cleanly: ${name}`);
  commands.push({ path: name, pid: command.pid, stoppedAt: command.stoppedAt, exitCode: command.exitCode });
}
requireFact(commands.length === 16, "expected fourteen validation commands, one observer and one raw proof command");
const observed = await json(join(OUT, "observations.json")), proof = await json(join(OUT, "proof.json"));
requireFact(observed.rows.length === 59 && observed.canonical && !observed.blocker && proof.rows.length === 59, "incomplete producer result");
const credentialMatches = [];
const existing = [];
async function walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) await walk(path);
    else {
      requireFact(entry.isFile(), "unexpected symlink or non-file in owned evidence");
      const bytes = await readFile(path);
      for (const secret of [process.env.ALCHEMY_KEY, encodeURIComponent(process.env.ALCHEMY_KEY ?? "")].filter(Boolean)) {
        if (bytes.includes(Buffer.from(secret))) credentialMatches.push(path);
      }
      existing.push(await identity(path));
    }
  }
}
await walk(OUT);
requireFact(Boolean(process.env.ALCHEMY_KEY) && credentialMatches.length === 0, "selected credential scan unavailable or failed");
await save("cleanup.json", { status: "STOPPED-BOUNDED-PRODUCER", capturedAt: new Date().toISOString(), commands,
  pendingOwnedChildOperations: [], rpcRequestsAwaited: true, serversStarted: 0, chainProcessesStarted: 0, subagentsStarted: 0,
  temporaryDirectoriesCreated: 0, signingOrGovernance: false, gitWrites: false, productionEdits: false,
  cleanupDeletions: [], retainedFailures: "exact per-request failures and attempts.md retained",
  inputsReauthenticated: source.input.bindings.length, sourceBindingsReauthenticated: source.bindings.length,
  selectedCredentialScan: { files: existing.length, matches: 0 },
  finalPublisher: { pid: process.pid, action: "seal publication is the last write; this process exits immediately afterward" },
  independentVerifier: "separate downstream workflow node, not launched or claimed by producer" });
const manifest = existing.filter(x => !x.path.endsWith("/seal.json") && !x.path.endsWith("/manifest.json"))
  .map(x => ({ ...x, path: x.path.slice(OUT.length + 1) }));
manifest.push({ ...await identity(join(OUT, "cleanup.json")), path: "cleanup.json" });
manifest.sort((a, b) => a.path.localeCompare(b.path));
await save("manifest.json", manifest);
const bindings = [];
for (const name of ["report.md", "proof.json", "observations.json", "pin.json", "end-canonical.json", "code-routing.json",
  "http-manifest.json", "inputs.json", "source-manifest.json", "originals.json", "cleanup.json", "manifest.json"]) {
  bindings.push({ ...await identity(join(OUT, name)), path: name });
}
await save("seal.json", { version: "phase31-named-nft-producer-seal-v1", status: "COMPLETE-STOPPED-BOUNDED-PRODUCER",
  publishedAt: new Date().toISOString(), sourceCommit: "1694e68a4bd66dd67d3b5e3f145f1da23074ff48",
  pin: { number: observed.pin.number, hash: observed.pin.hash }, rows: observed.rows.length, canonical: observed.canonical,
  bindings, evidenceFiles: manifest.length, pendingOwnedChildren: 0, independentVerification: "not-claimed-separate-node",
  scope: "59 named original purchase observations only; no eligibility, credit or operational/full-plan acceptance",
  publicationCommand: { executable: process.execPath, argv: [join(OUT, "seal.mjs")], cwd: OUT },
  finalPublication: true });
console.log(JSON.stringify({ sealed: true, files: manifest.length, rows: observed.rows.length, pin: observed.pin.number }));
