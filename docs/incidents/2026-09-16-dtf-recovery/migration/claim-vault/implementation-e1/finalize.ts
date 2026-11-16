import { createHash } from "node:crypto";
import { chmod, lstat, readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const files: { path: string; bytes: number; sha256: string }[] = [];
const directories: string[] = [];
async function collect(directory: string) {
  directories.push(directory);
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    const path = join(directory, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`unexpected evidence link: ${path}`);
    if (entry.isDirectory()) await collect(path);
    else if (entry.isFile()) {
      if (entry.name === "final-tree.json") throw new Error("evidence is already sealed");
      const bytes = await readFile(path);
      files.push({ path: relative(root, path), bytes: bytes.length,
        sha256: createHash("sha256").update(bytes).digest("hex") });
    }
  }
}
await collect(root);
const manifest = `${JSON.stringify({ version: 1, excludedSelf: "final-tree.json", files }, null, 2)}\n`;
const manifestPath = join(root, "final-tree.json");
await writeFile(manifestPath, manifest, { flag: "wx" });
for (const file of [...files.map((row) => join(root, row.path)), manifestPath]) {
  await chmod(file, (await lstat(file)).mode & ~0o222);
}
for (const directory of directories.reverse()) await chmod(directory, (await lstat(directory)).mode & ~0o222);
console.log(JSON.stringify({ files: files.length, manifest: manifestPath,
  manifestSha256: createHash("sha256").update(manifest).digest("hex"), readonly: true }));
