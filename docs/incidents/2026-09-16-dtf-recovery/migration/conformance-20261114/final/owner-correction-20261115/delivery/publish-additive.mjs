import { readFile, writeFile, readdir, lstat, readlink } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const directory = dirname(fileURLToPath(import.meta.url));
const digest = bytes => createHash("sha256").update(bytes).digest("hex");
const raw = await readFile(join(directory, "inventory.json"));
const audit = JSON.parse(raw.toString("utf8"));
const receipt = JSON.parse(await readFile(join(directory, "delivery.json"), "utf8"));
const command = JSON.parse(await readFile(join(directory, "command/result.json"), "utf8"));
const comparison = JSON.parse(await readFile(join(directory, "preservation-comparison.json"), "utf8"));
const controls = JSON.parse(await readFile(join(directory, "exterior-control-catalog.json"), "utf8"));
await writeFile(join(directory, "recorder-inventory.json"), raw, { flag: "wx" });
await writeFile(join(directory, "publication.json"), JSON.stringify({
  scope: "Additive inclusion and preservation of truthful bounded partial delivery only",
  recordedAt: new Date().toISOString(),
  publisher: { argv: process.argv, cwd: process.cwd(), completionRecordedByFinalMonitor: true },
  rawInventory: { path: join(directory, "recorder-inventory.json"), sha256: digest(raw) },
  actualRecorderExit: command.exit,
  strictDeliveryCompleted: receipt.completed,
  strictFailureMessages: receipt.failures.length,
  priorEntriesCompared: comparison.priorEntriesCompared,
  priorEntriesMissing: comparison.missingPrior,
  priorEntriesChanged: comparison.changedPrior,
  allFourReportsMatchVerdicts: comparison.finalReports.every(row => row.rawMatchesVerdict && row.inActualRecorderInventory),
  exteriorVerdicts: controls.finalVerdicts,
  updatedControlObservations: controls.updatedControls,
  plan: { confirmed: controls.plan.confirmed, unmet: controls.plan.unmet, open: controls.plan.open },
  full_goal_met: false,
  task15Accepted: false,
  blockedAcceptanceRequeued: false,
  cleanup: "Only finite bookkeeping processes; no runtime resources created or cleanup campaign.",
}, null, 2) + "\n", { flag: "wx" });

const entries = new Map(audit.destination.map(entry => [entry.path, entry]));
const publishedPath = join(directory, "inventory.json");
entries.delete(relative(audit.destinationRoot, publishedPath));
entries.set(relative(audit.destinationRoot, directory), {
  path: relative(audit.destinationRoot, directory), type: "directory", size: 0, sha256: null,
});
async function ownFiles(folder) {
  for (const name of (await readdir(folder)).sort()) {
    const file = join(folder, name);
    if (file === publishedPath) continue;
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
audit.destination = [...entries.values()].sort((a, b) => a.path.localeCompare(b.path));
audit.parentInventory = { path: join(directory, "recorder-inventory.json"), sha256: digest(raw) };
audit.generatedAuditRecords = [
  publishedPath,
  join(process.cwd(), ".omo/ulw-execute/dtf-conformance/owner-correction-20261115/final-closeout-done.json"),
];
audit.qualification += " Final additive bounded closeout: raw recorder result remains failed; actual report/control/bookkeeping additions are included without changing any frozen baseline identity or asserting full conformance.";
await writeFile(publishedPath, JSON.stringify(audit) + "\n", { flag: "w" });
console.log(`FINAL_ADDITIVE_PUBLISHED entries=${audit.destination.length} recorderExit=${command.exit} failures=${receipt.failures.length}`);
