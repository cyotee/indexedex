import { readFile, readdir, writeFile } from "node:fs/promises";
import { join, resolve, relative } from "node:path";
import { intake, json, OUT, INPUT, identity, authenticated, fact, text, sha } from "./common.mjs";

const data = await intake();
const allFiles = [];
async function visit(directory) {
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) await visit(path);
    else { fact(entry.isFile(), `unexpected nonfile: ${path}`); allFiles.push(path); }
  }
}
await visit(OUT);
const key = process.env.ALCHEMY_KEY;
fact(Boolean(key), "selected key required for literal/encoded leak check");
for (const path of allFiles) {
  const content = await readFile(path, "utf8");
  for (const secret of [key, encodeURIComponent(key)]) fact(!content.includes(secret), `credential leak: ${path}`);
}
const commandFiles = allFiles.filter(x => x.endsWith(".command.json"));
const commands = [];
for (const path of commandFiles) {
  const command = await json(path);
  fact(command.finishedAt && command.signal === null, `unfinished command: ${path}`);
  fact(command.exit === 0 || path.endsWith("/observe-01.command.json") && command.exit === 1, `unexpected failed command: ${path}`);
  await authenticated(command.stdout);
  await authenticated(command.stderr);
  let stopped = false;
  try { process.kill(command.pid, 0); }
  catch (error) {
    if (!(error instanceof Error) || !("code" in error) || error.code !== "ESRCH") throw error;
    stopped = true;
  }
  fact(stopped, `recorded child still exists: ${command.pid}`);
  commands.push({ path: relative(OUT, path), ...command });
}
const proof = await json(join(OUT, "prove-01.stdout"));
fact(proof.checks === 4915 && proof.requestCount === 363, "actual full proof required");
const validation = await json(join(OUT, "validate-01.stdout"));
fact(validation.results.length === 8 && validation.results.every(x => x.exit === 0), "all final source syntax checks");
const frozen = [{ path: resolve(INPUT, "manifest.json"), declaration: "manifest-body", ...await identity(resolve(INPUT, "manifest.json")) }];
for (const binding of data.input.bindings) frozen.push({ ...binding, path: resolve(INPUT, binding.path) });
await writeFile(join(OUT, "inputs.json"), text({ recoveredBodiesNotOriginalCaptures: true,
  declarationCount: data.input.bindings.length, uniqueBodiesIncludingManifest: data.input.bytes.size,
  frozen, acceptedEvidenceAndAuthorities: data.bindings }), { flag: "wx" });
const sourceFiles = allFiles.filter(x => x.endsWith(".mjs") || x.endsWith(".mjs.txt"));
await writeFile(join(OUT, "source-manifest.json"), text(await Promise.all(sourceFiles.map(identity))), { flag: "wx" });
const observed = await json(join(OUT, "observe-02.stdout"));
await writeFile(join(OUT, "http-manifest.json"), text(observed.captures.map(capture => ({
  id: capture.id, method: capture.method, params: capture.params, startedAt: capture.startedAt, finishedAt: capture.finishedAt,
  request: { path: `http02/${String(capture.id).padStart(4, "0")}.request.json`, bytes: capture.request.bytes, sha256: capture.request.sha256 },
  response: { path: `http02/${String(capture.id).padStart(4, "0")}.response.raw`, bytes: capture.response.bytes,
    sha256: capture.response.sha256, raw: capture.response.raw, httpStatus: capture.response.httpStatus },
  failure: capture.failure,
}))), { flag: "wx" });
await writeFile(join(OUT, "command-index.json"), text(commands), { flag: "wx" });
await writeFile(join(OUT, "cleanup.json"), text({
  stopped: true, pendingOwnedOperations: 0, allRecordedChildrenAbsent: true,
  commands: commands.map(x => ({ path: x.path, pid: x.pid, exit: x.exit, finishedAt: x.finishedAt })),
  providerRequests: { completeRetainedSecondAttempt: 363, pending: 0, failures: 0,
    firstAttempt: "243 scheduled reads completed before local TypeError; response entities lost from process memory, not usable evidence" },
  credentialScan: { literalAndEncodedSelectedKeyMatches: 0, filesScanned: allFiles.length },
  temporaryRuntimeCreated: false, deletionRequired: false, sharedResourcesModified: false,
  retained: "All original inputs, old evidence, failed source snapshots and command streams retained; no old collector replay.",
  boundary: "Only this source directory written; no Git, signing, traces, range scans, provider change, source changes or phase29 retry.",
}), { flag: "wx" });
allFiles.length = 0;
await visit(OUT);
const manifest = [];
for (const path of allFiles) {
  const binding = await identity(path);
  manifest.push({ ...binding, path: relative(OUT, path) });
}
await writeFile(join(OUT, "manifest.json"), text(manifest), { flag: "wx" });
const bindings = [];
for (const name of ["manifest.json", "report.md", "reconcile-01.stdout", "observe-02.stdout", "prove-01.stdout",
  "source-manifest.json", "inputs.json", "http-manifest.json", "cleanup.json", "command-index.json"]) {
  bindings.push({ ...await identity(join(OUT, name)), path: name });
}
await writeFile(join(OUT, "seal.json"), text({ version: "phase32-stopped-producer-seal-v1",
  status: "complete-bounded-source-handoff-with-precise-gaps", publishedAt: new Date().toISOString(),
  rows: 59, supportedEarlierPurchases: 16, unknownWeightedPurchases: 43, retainedFlags: 19,
  originPairs: 2, proofChecks: proof.checks, independentVerdict: "not-claimed-separate-downstream-role",
  pendingOwnedOperations: 0, bindings,
  limits: "NON-ISSUABLE; proposed purchase token components only, not eligibility, configuration, C0, native-history completeness or financial approval",
  finalPublication: true, publisherExitRequired: true }), { flag: "wx" });
console.log("SEALED phase32 producer; no further writes; pendingOwnedOperations=0");
