import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { lstat, readFile, readlink, readdir, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const incident = `${root}/docs/incidents/2026-09-16-dtf-recovery`;
const evidence = `${incident}/migration/evidence`;
const verification = `${evidence}/verification`;
assert.equal(process.cwd(), root);
const mode = process.argv[2];
assert.ok(mode === "before" || mode === "after");
async function git(args) {
  const child = spawn("git", args, {
    cwd: root, env: { ...process.env, GIT_MASTER: "1" }, stdio: ["ignore", "pipe", "pipe"],
  });
  let out = "";
  let error = "";
  child.stdout.setEncoding("utf8").on("data", chunk => { out += chunk; });
  child.stderr.setEncoding("utf8").on("data", chunk => { error += chunk; });
  await new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", code => code === 0 ? resolve() : reject(new Error(`git exit ${code}: ${error}`)));
  });
  return out;
}
const tracked = (await git(["ls-files", "-z"])).split("\0").filter(Boolean);
const status = await git(["status", "--porcelain=v1", "--untracked-files=all", "--ignore-submodules=all"]);
const paths = new Set(tracked.map(p => `${root}/${p}`));
async function walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const p = `${dir}/${entry.name}`;
    if (p === verification || p === `${evidence}/phase01-verification.md`) continue;
    if (entry.isDirectory()) await walk(p);
    else paths.add(p);
  }
}
await walk(incident);
await walk(`${root}/scripts/recovery/dtf-migration/phase01`);
const sourceManifest = JSON.parse(await readFile(`${incident}/sources.json`, "utf8"));
for (const entry of sourceManifest.sources ?? []) {
  if (entry.path) paths.add(new URL(entry.path, `file://${incident}/`).pathname);
}
const files = [];
for (const path of [...paths].sort()) {
  if (path.startsWith(`${verification}/`)) continue;
  try {
    const st = await lstat(path);
    if (st.isSymbolicLink()) files.push({ path, kind: "symlink", target: await readlink(path) });
    else if (st.isFile()) {
      const bytes = await readFile(path);
      files.push({ path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") });
    }
  } catch (error) {
    if (!(error instanceof Error) || !("code" in error) || error.code !== "ENOENT") throw error;
    files.push({ path, absent: true });
  }
}
const result = { mode, at: new Date().toISOString(), status, files };
if (mode === "after") {
  const before = JSON.parse(await readFile(`${verification}/workspace-before.json`, "utf8"));
  const now = new Map(files.map(f => [f.path, f]));
  result.changed = before.files.filter(f => JSON.stringify(f) !== JSON.stringify(now.get(f.path)));
  result.addedOutside = files.filter(f => !before.files.some(b => b.path === f.path));
}
await writeFile(`${verification}/workspace-${mode}.json`, `${JSON.stringify(result, null, 2)}\n`);
console.log(`WORKSPACE_AUDIT ${mode} files=${files.length} changed=${result.changed?.length ?? 0}`);
