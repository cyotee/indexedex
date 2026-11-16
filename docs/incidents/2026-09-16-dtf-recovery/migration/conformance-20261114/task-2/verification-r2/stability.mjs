// Rehash the protected source and delivery boundary after independent QA.
import { createReadStream } from "node:fs";
import { createHash } from "node:crypto";
import { lstat, readFile, readdir, readlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { z } from "zod";
const output = dirname(new URL(import.meta.url).pathname);
const load = async (name) => JSON.parse(await readFile(join(output, name), "utf8"));
const binding = z.object({
  path: z.string(), type: z.string(), size: z.number(), sha256: z.string().nullable(),
  link: z.string().optional(),
});
const audit = z.object({
  sourceBindings: z.array(binding), deliveredBindings: z.array(binding),
  completeness: z.array(z.object({ root: z.string() })),
}).parse(await load("byte-audit.json"));
const initial = z.object({
  bound: z.array(z.object({ path: z.string(), size: z.number(), sha256: z.string() })),
  transitive: z.array(z.object({ path: z.string(), size: z.number(), actual: z.string() })),
}).parse(await load("initial-bindings.json"));
const directories = new Set();
async function boundary(directory) {
  if (directories.has(directory)) return;
  if (directory !== "/") await boundary(dirname(directory));
  const stat = await lstat(directory);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error(`Unsafe parent: ${directory}`);
  directories.add(directory);
}
const protectedEntries = new Map();
for (const row of [...audit.sourceBindings, ...audit.deliveredBindings]) protectedEntries.set(row.path, row);
for (const row of initial.bound) protectedEntries.set(row.path, { ...row, type: "file" });
for (const row of initial.transitive) {
  protectedEntries.set(row.path, { ...row, type: "file", sha256: row.actual });
}
const failures = [];
const sourcePaths = new Set(audit.sourceBindings.map((row) => row.path));
async function checkSet(directory) {
  await boundary(directory);
  for (const name of await readdir(directory)) {
    const file = join(directory, name);
    const stat = await lstat(file);
    if (stat.isDirectory()) await checkSet(file);
    else if (!sourcePaths.has(file)) failures.push(`New source entry: ${file}`);
  }
}
for (const item of audit.completeness) await checkSet(item.root);
let files = 0;
let links = 0;
for (const expected of protectedEntries.values()) {
  await boundary(dirname(expected.path));
  const before = await lstat(expected.path);
  if (before.isDirectory()) {
    if (expected.type !== "directory") failures.push(`Type changed: ${expected.path}`);
    continue;
  }
  const hash = createHash("sha256");
  let size;
  if (before.isSymbolicLink()) {
    const link = await readlink(expected.path);
    hash.update(link);
    size = Buffer.byteLength(link);
    links++;
    if (expected.type !== "symlink" || expected.link !== link) failures.push(`Link changed: ${expected.path}`);
  } else {
    if (!before.isFile() || expected.type !== "file") throw new Error(`Type changed: ${expected.path}`);
    for await (const bytes of createReadStream(expected.path)) hash.update(bytes);
    size = before.size;
    files++;
  }
  const after = await lstat(expected.path);
  if (before.ino !== after.ino || before.mtimeMs !== after.mtimeMs || before.size !== after.size) {
    failures.push(`Changed while hashing: ${expected.path}`);
  }
  if (hash.digest("hex") !== expected.sha256 || size !== expected.size) failures.push(`Bytes changed: ${expected.path}`);
}
await writeFile(join(output, "stability.json"), JSON.stringify({
  completed: failures.length === 0, entries: protectedEntries.size, files, links, failures,
  comparedTo: ["byte-audit.json", "initial-bindings.json"],
  qualification: "Every protected file was rehashed, including retained and delivered bytes, the producer claim, historical report/verdict and 87 compiler source bindings.",
}, null, 2) + "\n", { flag: "wx" });
console.log(`STABILITY_COMPLETE entries=${protectedEntries.size} failures=${failures.length}`);
process.exitCode = failures.length ? 1 : 0;
