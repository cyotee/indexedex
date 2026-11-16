import assert from "node:assert/strict";
import { lstat, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { createHash } from "node:crypto";
import { z } from "zod";

const here = dirname(import.meta.filename);
const root = process.cwd();
const source = [];
async function bind(path: string) {
  const raw = await readFile(path);
  return { path, bytes: raw.length, sha256: createHash("sha256").update(raw).digest("hex"),
    mode: (await lstat(path)).mode & 0o777 };
}
async function walk(path: string): Promise<string[]> {
  const result = [];
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const p = join(path, entry.name);
    if (entry.isDirectory()) result.push(...await walk(p));
    else if (entry.isFile()) result.push(p);
    else throw new TypeError("source symlink not admitted");
  }
  return result.sort();
}
for (const p of [
  ...await walk(resolve("scripts/recovery/dtf-migration")),
  ...await walk(resolve("scripts/foundry/recovery/dtf-migration")),
  resolve("docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md"),
]) source.push(await bind(p));
const authority = [];
const sources = z.object({ sources: z.array(z.object({
  path: z.string(), sha256: z.string(), bytes: z.string(),
}).passthrough()) }).passthrough().parse(JSON.parse(await readFile(join(here, "authority-template.json"), "utf8")));
for (const s of sources.sources) {
  const actual = await bind(s.path);
  assert.equal(actual.sha256, s.sha256);
  assert.equal(String(actual.bytes), s.bytes);
  authority.push(actual);
}
const gitPointer = (await readFile(resolve(".git"), "utf8")).trim();
assert(gitPointer.startsWith("gitdir: "));
const gitDir = gitPointer.slice(8);
const git = [];
for (const p of ["HEAD", "index", "commondir"]) git.push(await bind(join(gitDir, p)));
const common = resolve(gitDir, (await readFile(join(gitDir, "commondir"), "utf8")).trim());
git.push(await bind(join(common, "refs/heads/work/dtf-migration-phase-26-portable-operator")));
await writeFile(join(here, process.argv[2] ?? "source-manifest.json"), JSON.stringify({
  base: "137fa0c8749165087c7d1d0156788f58a1dbf1b8",
  branch: "work/dtf-migration-phase-26-portable-operator", root,
  sourceModificationsStopped: true, source, authority, immutable: [], git,
  limitation: "Current source only; P1 historical versions remain unrecovered.",
}, null, 2) + "\n", { flag: "wx" });
console.log(`SOURCE_FROZEN files=${source.length}`);
