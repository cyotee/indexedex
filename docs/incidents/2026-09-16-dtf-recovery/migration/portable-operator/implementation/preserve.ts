import assert from "node:assert/strict";
import { constants } from "node:fs";
import { copyFile, lstat, mkdir, readFile, readdir, readlink, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { createHash } from "node:crypto";
import { z } from "zod";

const root = process.cwd();
const here = dirname(import.meta.filename);
assert.equal(root, "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-26-portable-operator");
const destination = join(here, "originals");
await mkdir(destination, { recursive: false });
const sha = (raw: Uint8Array | string) => createHash("sha256").update(raw).digest("hex");
const rows: { path: string; copy: string | null; bytes: number; sha256: string; mode: number; target?: string }[] = [];
const seen = new Set<string>();
async function capture(path: string) {
  if (seen.has(path)) return;
  seen.add(path);
  const stat = await lstat(path);
  if (stat.isSymbolicLink()) {
    const target = await readlink(path);
    rows.push({ path, copy: null, bytes: Buffer.byteLength(target), sha256: sha(target), mode: stat.mode, target });
  } else if (stat.isDirectory()) {
    for (const name of (await readdir(path)).sort()) await capture(join(path, name));
  } else {
    assert(stat.isFile(), `not a regular input: ${path}`);
    const raw = await readFile(path);
    const digest = sha(raw);
    const copy = join(destination, digest);
    try { await copyFile(path, copy, constants.COPYFILE_EXCL | constants.COPYFILE_FICLONE); }
    catch (error) {
      if (!(error instanceof Error) || !("code" in error) || error.code !== "EEXIST") throw error;
    }
    assert.equal(sha(await readFile(copy)), digest);
    rows.push({ path, copy, bytes: raw.length, sha256: digest, mode: stat.mode });
  }
}
const inventoryPath = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase23-portability-inputs.json";
const inventory = z.object({ inputs: z.array(z.object({
  id: z.string(), path: z.string(), bytes: z.number(), sha256: z.string(),
}).passthrough()) }).passthrough().parse(JSON.parse(await readFile(inventoryPath, "utf8")));
await capture(inventoryPath);
for (const input of inventory.inputs) {
  await capture(input.path);
  const captured = rows.find((row) => row.path === input.path);
  assert.equal(captured?.bytes, input.bytes, input.id);
  assert.equal(captured?.sha256, input.sha256, input.id);
}
const previous = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-23-claimed-sy-integration/docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration";
for (const lane of ["implementation", "verification-r2", "commit"]) {
  for (const name of lane === "commit" ? ["receipt.md", "verification.md", "source-manifest.json"]
    : ["report.md", "seal.json"]) await capture(join(previous, lane, name));
}
const runtime = join(previous, "implementation/runtime-03/rehearsal-1794496225193");
for (const name of ["input.json", "replacement-input.json", "pre-capture.json", "post-capture.json",
  "replacement-execution.json", "prepared/manifest.json", "replacement/manifest.json",
  "original-input-bytes.json", "replacement-original-input-bytes.json"]) await capture(join(runtime, name));
for (const name of ["original-input-bytes.json", "replacement-original-input-bytes.json"]) {
  const originals = z.object({ records: z.array(z.object({ path: z.string(), rawBase64: z.string(),
    sha256: z.string(), bytes: z.string() }).passthrough()) }).passthrough()
    .parse(JSON.parse(await readFile(join(runtime, name), "utf8")));
  for (const entry of originals.records) {
    const raw = Buffer.from(entry.rawBase64, "base64");
    assert.equal(sha(raw), entry.sha256);
    assert.equal(String(raw.length), entry.bytes);
    await capture(entry.path);
    assert.equal(rows.find((r) => r.path === entry.path)?.sha256, entry.sha256);
  }
}
const prior25 = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-25-full-hermetic/docs/incidents/2026-09-16-dtf-recovery/migration/full-hermetic";
for (const name of ["report.md", "seal.json", "commit/receipt.md", "commit/verification.md",
  "commit/source-manifest.json"]) await capture(join(prior25, name));
for (const path of ["scripts/recovery/dtf-migration", "scripts/foundry/recovery/dtf-migration",
  "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md", "out", "cache_forge",
  "lib/crane", "node_modules", ".git"]) await capture(resolve(root, path));
await writeFile(join(here, "preservation-baseline.json"), JSON.stringify({
  base: "137fa0c8749165087c7d1d0156788f58a1dbf1b8",
  limitation: "Current raw versions only. P1's two historical artifact JSON versions remain unrecovered.",
  method: "lstat; no symlink traversal; raw SHA256/length/full mode; exclusive lossless copies before compiler or relocation",
  rows,
}, null, 2) + "\n", { flag: "wx" });
console.log(`PRESERVATION_COMPLETE files=${rows.length}`);
