import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const root = process.cwd();
const directory = dirname(fileURLToPath(import.meta.url));
const migration = resolve("docs/incidents/2026-09-16-dtf-recovery/migration");
const originPath = join(migration, "conformance-20261114/task-2/inventory/inventory.json");
const originBytes = await readFile(originPath);
const origin = JSON.parse(originBytes.toString("utf8"));
const current = JSON.parse(await readFile(join(directory, "discovery/inventory.json"), "utf8"));
const previous = new Map(origin.destination.map((entry: { path: string }) => [entry.path, entry]));
const observed = new Set<string>();
const category = (name: string) => {
  if (/\/(?:checkout|qa-checkout[^/]*)\//.test(name)) return "copied-QA-environment-not-new-authored-work";
  if (/\/(?:node_modules|cache_forge|out)\//.test(name)) return "retained-vendor-or-environment-material";
  if (name.includes("bounded-stop-runtime-01/checkpoints")) return "preserved-runtime-not-new-execution-domain";
  if (name.includes("owner-correction-20261115")) return "renewed-bounded-evidence-not-full-acceptance";
  return "retained-task-document-or-evidence-no-new-behavior-acceptance";
};
const differences = [];
const counts: Record<string, { entries: number; bytes: number }> = {};
for (const entry of current.destination) {
  observed.add(entry.path);
  const kind = category(entry.path);
  const total = counts[kind] ??= { entries: 0, bytes: 0 };
  total.entries++;
  total.bytes += entry.type === "file" ? entry.size : 0;
  const old = previous.get(entry.path);
  if (!old || JSON.stringify(old) !== JSON.stringify(entry)) differences.push({
    path: entry.path, change: old ? "changed" : "added", before: old ?? null, current: entry,
    disposition: kind,
  });
}
for (const entry of origin.destination) if (!observed.has(entry.path)) differences.push({
  path: entry.path, change: "removed-or-unavailable", before: entry, current: null,
  disposition: "Explicit availability gap; no implicit exclusion or restoration.",
});
const save = async (name: string, value: unknown) =>
  writeFile(join(directory, name), JSON.stringify(value) + "\n", { flag: "wx" });
await save("origin-differences.json", {
  origin: { path: originPath, sha256: createHash("sha256").update(originBytes).digest("hex") },
  discoveredAt: new Date().toISOString(), differences,
  note: "Every raw identity difference is retained. Added copied material is not attributed as newly authored product work.",
});
await save("ownership-dispositions.json", {
  counts,
  rules: [
    "Apply the ordered path categories used in this generator to every entry in inventory.json.",
    "All regular files have raw hashes. All links have link-text hashes; none are traversed.",
    "Copied QA/vendor/environment bytes are retained, never silently excluded, and are not new authored work.",
    "Historical and renewed claims are evidence records; the inventory does not convert their assertions into approval.",
    "The companion task-owned-files.json explicitly distinguishes confirmed repairs, ten WIP paths and mixed ownership.",
  ],
  symlinks: current.destination.filter((entry: { type: string }) => entry.type === "symlink"),
  unresolvedRetainedDifferences: current.rows.filter((entry: { status: string }) => entry.status !== "identical"),
});
current.concurrentScope = [];
current.parentInventory = { path: originPath, sha256: createHash("sha256").update(originBytes).digest("hex") };
current.qualification = [
  "BOUNDED PARTIAL DELIVERY ONLY; not task-15 full-conformance acceptance.",
  "Fresh discovery of the actual retained migration root and current destination; old origin remains unchanged.",
  "All files and links remain included, including copied QA/vendor/environment material and failed attempts.",
  "Exterior current source/control raw identities are in boundary/task-owned-files.json and actual control bytes in control-evidence.json.",
  "Task 1 is no longer concurrent; its renewed evidence is not exempt from checking.",
  "Known retained divergences and links remain genuine recorder failures, not successful delivery.",
  "Only generated inventory/receipt self references lack their own recursive raw hashes.",
].join(" ");
current.generatedAuditRecords = [
  join(directory, "current-input.json"),
  join(directory, "inventory.json"),
  join(directory, "delivery/inventory.json"),
  join(directory, "delivery/delivery.json"),
  join(root, ".omo/ulw-execute/dtf-conformance/owner-correction-20261115/partial-boundary-done.json"),
];
await save("current-input.json", current);
console.log(`PARTIAL_INPUT entries=${current.destination.length} differences=${differences.length} links=${current.destination.filter((entry: { type: string }) => entry.type === "symlink").length}`);
