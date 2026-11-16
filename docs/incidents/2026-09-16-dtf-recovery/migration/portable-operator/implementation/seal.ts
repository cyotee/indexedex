import assert from "node:assert/strict";
import { lstat, open, readFile, readdir, readlink, rename } from "node:fs/promises";
import { dirname, join, relative } from "node:path";
import { createHash } from "node:crypto";

const root = dirname(import.meta.filename);
const sha = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
const rows: { path: string; kind: "file" | "symlink"; bytes: number; sha256: string; mode: number; target?: string }[] = [];
const directories: { path: string; mode: number }[] = [];
async function walk(directory: string) {
  for (const name of (await readdir(directory)).sort()) {
    const path = join(directory, name);
    if (path === join(root, "seal.json")) continue;
    const stat = await lstat(path);
    const short = relative(root, path);
    if (stat.isDirectory()) {
      directories.push({ path: short, mode: stat.mode });
      await walk(path);
    } else if (stat.isSymbolicLink()) {
      const target = await readlink(path);
      const raw = Buffer.from(target);
      rows.push({ path: short, kind: "symlink", bytes: raw.length, sha256: sha(raw), mode: stat.mode, target });
    } else {
      assert(stat.isFile(), path);
      const raw = await readFile(path);
      rows.push({ path: short, kind: "file", bytes: raw.length, sha256: sha(raw), mode: stat.mode });
    }
  }
}
assert((await lstat(join(root, "report.md"))).isFile());
assert((await lstat(join(root, "cleanup-final.json"))).isFile());
await assert.rejects(lstat(join(root, "seal.json")), { code: "ENOENT" });
await assert.rejects(lstat(join(root, ".seal.json.pending")), { code: "ENOENT" });
await walk(root);
const raw = Buffer.from(JSON.stringify({
  version: "portable-operator-implementation-seal-v1",
  base: "137fa0c8749165087c7d1d0156788f58a1dbf1b8",
  exclusions: ["seal.json"], membership: "All owned regular files and symlinks, exact raw lengths/SHA256/full modes.",
  sourceManifest: "source-manifest-stopped.json", report: "report.md", directories, files: rows,
}, null, 2) + "\n");
const pending = join(root, ".seal.json.pending");
const file = await open(pending, "wx", 0o644);
try { await file.writeFile(raw); await file.sync(); } finally { await file.close(); }
// The root's create watcher sees only the complete seal, never a partial write.
await rename(pending, join(root, "seal.json"));
console.log(JSON.stringify({ files: rows.length, directories: directories.length,
  sealBytes: raw.length, sealSha256: sha(raw), sourceStopped: true }));
