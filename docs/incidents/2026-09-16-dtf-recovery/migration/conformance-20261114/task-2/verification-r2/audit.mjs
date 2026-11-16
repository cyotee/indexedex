// Independent raw-byte audit; writes generated evidence only beside this file.
import { createReadStream } from "node:fs";
import { createHash } from "node:crypto";
import { lstat, readFile, readdir, readlink, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { z } from "zod";

const output = dirname(new URL(import.meta.url).pathname);
const task = dirname(output);
const destination = resolve(task, "../..");
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
const load = async (file) => JSON.parse(await readFile(file, "utf8"));
const rowSchema = z.object({
  sourcePath: z.string(), sourceRoot: z.string(), path: z.string(),
  destination: z.string(), deliveredPath: z.string(), type: z.enum(["file", "directory", "symlink"]),
  size: z.number(), sha256: z.string().nullable(), sourceRevision: z.string().min(1),
  ownership: z.enum(["migration-task-output", "migration-execution-record", "existing-primary-migration-output"]),
  ownershipEvidence: z.array(z.string().min(1)).min(1), status: z.string(), disposition: z.string().min(1),
  link: z.string().optional(), destinationSha256: z.string().optional(),
});
const manifest = z.object({
  destinationRoot: z.string(), rows: z.array(rowSchema), unresolved: z.array(z.unknown()),
  roots: z.array(z.object({ root: z.string(), head: z.string(), refs: z.array(z.string()) })),
}).parse(await load(join(task, "recovery.json")));
const config = z.object({
  roots: z.array(z.object({ root: z.string(), refs: z.array(z.string()) })),
  primaryMigration: z.string(), executionRoot: z.string(),
}).parse(await load(join(task, "recovery-inputs.json")));
const issues = [];
const checkedDirectories = new Set();
async function boundary(directory) {
  if (checkedDirectories.has(directory)) return;
  if (directory !== "/") await boundary(dirname(directory));
  const stat = await lstat(directory);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error(`Unsafe directory: ${directory}`);
  checkedDirectories.add(directory);
}
async function inspect(file) {
  await boundary(dirname(file));
  const before = await lstat(file);
  if (before.isSymbolicLink()) {
    const link = await readlink(file);
    return { type: "symlink", size: Buffer.byteLength(link), sha256: digest(link), link };
  }
  if (before.isDirectory()) return { type: "directory", size: 0, sha256: null };
  if (!before.isFile()) throw new Error(`Unsupported entry: ${file}`);
  const hash = createHash("sha256");
  for await (const bytes of createReadStream(file)) hash.update(bytes);
  const after = await lstat(file);
  if (before.size !== after.size || before.ino !== after.ino || before.mtimeMs !== after.mtimeMs) {
    throw new Error(`Concurrent mutation: ${file}`);
  }
  return { type: "file", size: before.size, sha256: hash.digest("hex") };
}
const sources = new Map();
const delivered = new Map();
const supersessions = z.array(z.object({
  sourcePath: z.string(), sourceSha256: z.string(), destinationPath: z.string(),
  destinationSha256: z.string(), preservedPath: z.string(), reason: z.string().min(1),
})).parse(await load(join(task, "supersessions.json")));
const counters = {};
const dispositionRows = [];
if (manifest.destinationRoot !== destination || manifest.unresolved.length) issues.push("Wrong root or unresolved ownership");
for (const row of manifest.rows) {
  if (row.sourcePath !== join(row.sourceRoot, row.path)) issues.push(`Wrong source path: ${row.sourcePath}`);
  if (relative(destination, row.deliveredPath).startsWith("..")) issues.push(`Outward delivery: ${row.deliveredPath}`);
  if (sources.has(row.sourcePath)) issues.push(`Duplicate source: ${row.sourcePath}`);
  const actual = await inspect(row.sourcePath);
  sources.set(row.sourcePath, actual);
  if (actual.type !== row.type || actual.size !== row.size || actual.sha256 !== row.sha256) {
    issues.push(`Source mismatch: ${row.sourcePath}`);
  }
  if (!delivered.has(row.deliveredPath)) delivered.set(row.deliveredPath, await inspect(row.deliveredPath));
  const target = delivered.get(row.deliveredPath);
  const update = supersessions.find((s) => s.sourcePath === row.sourcePath && s.sourceSha256 === row.sha256
    && s.destinationPath === row.deliveredPath);
  if (update) {
    const archived = await inspect(update.preservedPath);
    if (target.sha256 !== update.destinationSha256 || archived.sha256 !== row.sha256) {
      issues.push(`Invalid supersession: ${row.sourcePath}`);
    }
  } else if (target.type !== (row.type === "symlink" ? "file" : row.type)
    || target.size !== row.size || target.sha256 !== row.sha256) {
    issues.push(`Delivered mismatch: ${row.deliveredPath}`);
  }
  const root = manifest.roots.find((r) => r.root === row.sourceRoot);
  if (row.ownership === "migration-task-output" && (!root || row.sourceRevision !== root.head
    || row.ownershipEvidence.some((ref) => !root.refs.includes(ref)))) {
    issues.push(`Ownership binding mismatch: ${row.sourcePath}`);
  }
  counters[row.status] = (counters[row.status] ?? 0) + 1;
  if (!["restored", "identical", "source-qualified-execution-record"].includes(row.status)) {
    dispositionRows.push(row);
  }
}
const completeness = [];
async function enumerate(root, directory = root) {
  await boundary(directory);
  const found = [];
  for (const name of (await readdir(directory)).sort()) {
    const file = join(directory, name);
    const stat = await lstat(file);
    found.push(file);
    if (stat.isDirectory()) found.push(...await enumerate(root, file));
  }
  return found;
}
for (const root of [...config.roots.map((r) => r.root), config.primaryMigration, config.executionRoot]) {
  const all = await enumerate(root);
  const omitted = [];
  for (const file of all) {
    const stat = await lstat(file);
    if (root === config.executionRoot && stat.isDirectory()) continue;
    if (!sources.has(file)) omitted.push(file);
  }
  completeness.push({ root, entries: all.length, omitted });
  issues.push(...omitted.map((file) => `Unaccounted source: ${file}`));
}
const evidenceRefs = [...new Set(manifest.roots.flatMap((r) => r.refs))];
const referenceBindings = [];
for (const ref of evidenceRefs) {
  if (ref === "approved task 2 R retained root") continue;
  const actual = await inspect(ref);
  if (actual.type !== "file") issues.push(`Ownership reference is not a file: ${ref}`);
  const copy = manifest.rows.find((r) => r.sourcePath === ref);
  if (!copy || copy.sha256 !== actual.sha256) issues.push(`Ownership reference not preserved: ${ref}`);
  referenceBindings.push({ path: ref, ...actual });
}
const result = {
  completed: issues.length === 0, rowsChecked: manifest.rows.length, statuses: counters, issues,
  completeness, dispositionRows, referenceBindings,
  sourceBindings: [...sources].map(([path, value]) => ({ path, ...value })),
  deliveredBindings: [...delivered].map(([path, value]) => ({ path, ...value })),
  method: "Independent lstat/readlink and streaming SHA-256; no helper imports, no copying and no symlink traversal.",
};
await writeFile(join(output, "byte-audit.json"), JSON.stringify(result, null, 2) + "\n", { flag: "wx" });
console.log(`AUDIT_COMPLETE rows=${manifest.rows.length} issues=${issues.length}`);
process.exitCode = issues.length ? 1 : 0;
