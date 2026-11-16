import { readFile, writeFile, readdir, lstat, readlink } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const directory = dirname(fileURLToPath(import.meta.url));
const root = process.cwd();
const corrected = process.argv[2] === "corrected";
const deliveryDirectory = join(directory, corrected ? "delivery-corrected" : "delivery");
const digest = (raw: Uint8Array | string) => createHash("sha256").update(raw).digest("hex");
const deliveryBytes = await readFile(join(deliveryDirectory, "inventory.json"));
const audit = JSON.parse(deliveryBytes.toString("utf8"));
const receipt = JSON.parse(await readFile(join(deliveryDirectory, "delivery.json"), "utf8"));
const command = JSON.parse(await readFile(join(directory, corrected ? "commands/delivery-corrected/result.json" : "commands/delivery/result.json"), "utf8"));
const catalog = JSON.parse(await readFile(join(directory, "task-owned-files.json"), "utf8"));
const changes = [];
for (const entry of catalog.entries) {
  if (entry.kind !== "file" && entry.kind !== "symlink") continue;
  const file = join(root, entry.path);
  const bytes = entry.kind === "symlink" ? await readlink(file) : await readFile(file);
  if (digest(bytes) !== entry.rawSha256) changes.push({
    path: entry.path, observed: entry.rawSha256, current: digest(bytes),
    disposition: entry.path.startsWith(".omo/") ? "live-control-observation-changed" : "current-source-identity-gap",
  });
}
const pendingReports = ["F1-compliance.md", "F2-quality.md", "F3-real-qa.md", "F4-fidelity.md"];
const result = {
  scope: "Bounded partial inventory bookkeeping; no full-conformance acceptance",
  recordedAt: new Date().toISOString(),
  publisher: { cwd: root, argv: process.argv, completionRecordedByFinalMonitor: true },
  currentDelivery: {
    completed: receipt.completed, actualExit: command.exit,
    failures: receipt.failures, sourceEntries: receipt.sourceEntries,
    destinationEntries: receipt.destinationEntries,
    receipt: join(deliveryDirectory, "delivery.json"),
    rawStdout: join(directory, corrected ? "commands/delivery-corrected/stdout.log" : "commands/delivery/stdout.log"),
    rawStderr: join(directory, corrected ? "commands/delivery-corrected/stderr.log" : "commands/delivery/stderr.log"),
  },
  currentSourceCatalog: { entries: catalog.entries.length, changedSinceCapture: changes },
  fullGoalMet: false, task15Accepted: false, requeueAuthorized: false,
  knownUnmet: [10, 12, 13, 14, 15], confirmedRows: catalog.verifiedRows,
  expectedPendingReports: pendingReports.map(name => join(directory, "..", name)),
  laterAdditiveCloseoutExecuted: false,
  originalControlSnapshotLimit: "Actual dated observations; not historical frozen source preimages.",
  deliveryScopeLimit: "The recorder hashes the migration tree; exterior source/control identities are explicit companion data.",
  symlinkScopeLimit: "Link text is inventoried without traversal; strict recorder rejection remains in the genuine failure receipt.",
  readiness: "Ready for independent review of the truthful bounded package only.",
  cleanup: "No temporary runtime resources or product processes created. File-bookkeeping command completion is recorded by monitors.",
};
await writeFile(join(directory, corrected ? "boundary-result-corrected.json" : "boundary-result.json"), JSON.stringify(result, null, 2) + "\n", { flag: "wx" });
if (corrected) {
  await writeFile(join(directory, "inventory-before-input-correction.json"),
    await readFile(join(directory, "inventory.json")), { flag: "wx" });
}

type Entry = { path: string; type: string; size: number; sha256: string | null; link?: string };
const entries = new Map<string, Entry>(audit.destination.map((entry: Entry) => [entry.path, entry]));
entries.delete(relative(audit.destinationRoot, join(directory, "inventory.json")));
async function ownFiles(folder: string): Promise<void> {
  for (const name of (await readdir(folder)).sort()) {
    const file = join(folder, name);
    if (file === join(directory, "inventory.json")) continue;
    const stat = await lstat(file);
    const path = relative(audit.destinationRoot, file);
    if (stat.isDirectory()) {
      entries.set(path, { path, type: "directory", size: 0, sha256: null });
      await ownFiles(file);
    } else if (stat.isSymbolicLink()) {
      const link = await readlink(file);
      entries.set(path, { path, type: "symlink", size: Buffer.byteLength(link), sha256: digest(link), link });
    } else if (stat.isFile()) {
      const bytes = await readFile(file);
      entries.set(path, { path, type: "file", size: bytes.length, sha256: digest(bytes) });
    } else {
      entries.set(path, { path, type: "unsupported", size: stat.size, sha256: null });
    }
  }
}
await ownFiles(directory);
audit.destination = [...entries.values()].sort((left, right) => left.path.localeCompare(right.path));
audit.parentInventory = { path: join(deliveryDirectory, "inventory.json"), sha256: digest(deliveryBytes) };
audit.generatedAuditRecords = [
  join(directory, "inventory.json"),
  join(root, ".omo/ulw-execute/dtf-conformance/owner-correction-20261115/partial-boundary-done.json"),
];
audit.qualification += " Published baseline adds actual immutable bookkeeping outputs after the recorder scan; its parent binds the unchanged real recorder inventory. Strict delivery failure remains outstanding.";
await writeFile(join(directory, "inventory.json"), JSON.stringify(audit) + "\n", { flag: corrected ? "w" : "wx" });
console.log(`BOUNDARY_PUBLISHED entries=${audit.destination.length} recorderExit=${command.exit} failures=${receipt.failures.length} sourceChanges=${changes.length}`);
