import { constants, createReadStream } from "node:fs";
import { copyFile, lstat, mkdir, readFile, readdir, readlink, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, relative, resolve } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { z } from "zod";

// This one-shot recovery copies evidence; the delivered verifier never copies it.
const run = promisify(execFile);
const worktree = "/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1";
const migration = "docs/incidents/2026-09-16-dtf-recovery/migration";
const destination = join(worktree, migration);
const evidence = join(destination, "conformance-20261114/task-2");
const configuration = z.object({
  roots: z.array(z.object({ root: z.string(), refs: z.array(z.string()) })),
  executionRoot: z.string(),
  primaryMigration: z.string(),
  qualification: z.string(),
}).parse(JSON.parse(await readFile(join(evidence, "recovery-inputs.json"), "utf8")));
if (process.cwd() !== worktree) throw new Error("Recovery must run in its assigned worktree");
const sha256 = async (file: string) => {
  const hash = createHash("sha256");
  for await (const bytes of createReadStream(file)) hash.update(bytes);
  return hash.digest("hex");
};
const digest = (bytes: string) => createHash("sha256").update(bytes).digest("hex");
const existing = async (file: string) => {
  try { return await lstat(file); }
  catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") return null;
    throw error;
  }
};
async function boundary(file: string) {
  const absolute = resolve(file);
  let current = "/";
  for (const part of absolute.split("/").filter(Boolean)) {
    current = join(current, part);
    const stat = await existing(current);
    if (stat?.isSymbolicLink()) throw new Error(`Symlink boundary: ${current}`);
  }
}
const rows: object[] = [];
const revisions: object[] = [];
const differences: object[] = [];
const initialDestination: object[] = [];
async function walk(root: string, visit: (file: string, path: string) => Promise<void>, dir = root) {
  for (const name of (await readdir(dir)).sort()) {
    const file = join(dir, name);
    const stat = await lstat(file);
    await visit(file, relative(root, file));
    if (stat.isDirectory()) await walk(root, visit, file);
  }
}
await boundary(destination);
await walk(destination, async (file, path) => {
  // Other executors own the other conformance task directories.
  if (path.startsWith("conformance-20261114/") && !path.startsWith("conformance-20261114/task-2/")) return;
  const stat = await lstat(file);
  if (stat.isFile()) initialDestination.push({ path, size: stat.size, sha256: await sha256(file) });
});
const roots = configuration.roots;
for (const source of roots) {
  await boundary(source.root);
  const checkout = source.root.includes(`/${migration}`) ? resolve(source.root, "../../../..") : source.root;
  const revision = await run("git", ["-C", checkout, "rev-parse", "HEAD"], {
    env: { ...process.env, GIT_MASTER: "1" },
  });
  revisions.push({ root: source.root, head: revision.stdout.trim(), refs: source.refs,
    qualification: "HEAD is provenance only; raw hashes bind uncommitted source bytes. No clean-tree claim." });
  await walk(source.root, async (file, path) => {
    const stat = await lstat(file);
    const target = join(destination, path);
    await boundary(dirname(target));
    const current = await existing(target);
    const base = { sourcePath: file, sourceRoot: source.root, path, destination: target,
      sourceRevision: revision.stdout.trim(), ownership: "migration-task-output", ownershipEvidence: source.refs };
    if (stat.isDirectory()) {
      if (current && !current.isDirectory()) throw new Error(`Directory conflict: ${target}`);
      if (!current) await mkdir(target);
      rows.push({ ...base, type: "directory", size: 0, sha256: null, status: current ? "identical" : "restored",
        deliveredPath: target, disposition: "same-relative-path directory" });
      return;
    }
    if (stat.isSymbolicLink()) {
      const link = await readlink(file);
      const archive = join(evidence, "retained-originals", "symlinks", digest(source.root).slice(0, 16), `${path}.link-text`);
      await mkdir(dirname(archive), { recursive: true });
      await writeFile(archive, link, { flag: "wx" });
      rows.push({ ...base, type: "symlink", size: Buffer.byteLength(link), sha256: digest(link), link,
        status: "source-qualified-link-record", deliveredPath: archive,
        disposition: "Preserve exact link text as inert bytes; do not recreate an absolute link into a reference worktree or traverse it." });
      differences.push({ source: file, path, status: "symlink-preserved-without-traversal", archive });
      return;
    }
    if (!stat.isFile()) throw new Error(`Unsupported recovery entry: ${file}`);
    const hash = await sha256(file);
    if (!current) {
      await copyFile(file, target, constants.COPYFILE_EXCL);
      rows.push({ ...base, type: "file", size: stat.size, sha256: hash, status: "restored",
        deliveredPath: target, disposition: "same-relative-path byte copy" });
      return;
    }
    if (!current.isFile()) throw new Error(`File conflict: ${target}`);
    const currentHash = await sha256(target);
    if (hash === currentHash) {
      rows.push({ ...base, type: "file", size: stat.size, sha256: hash, status: "identical",
        deliveredPath: target, disposition: "existing identical bytes retained" });
      return;
    }
    const original = await readFile(file);
    const delivered = await readFile(target);
    const withoutEof = (bytes: Buffer) => {
      let end = bytes.length;
      while (end > 0 && (bytes[end - 1] === 10 || bytes[end - 1] === 13)) end--;
      return bytes.subarray(0, end);
    };
    const difference = withoutEof(original).equals(withoutEof(delivered)) ? "EOF-only" : "semantic";
    const archive = join(evidence, "retained-originals", digest(source.root).slice(0, 16), path);
    await mkdir(dirname(archive), { recursive: true });
    await copyFile(file, archive, constants.COPYFILE_EXCL);
    const disposition = "Preserve existing destination; retain divergent historical source losslessly at the source-qualified archive. Historical text does not supersede current source or owner decisions.";
    rows.push({ ...base, type: "file", size: stat.size, sha256: hash, status: difference,
      deliveredPath: archive, destinationSha256: currentHash, disposition });
    differences.push({ source: file, path, difference, sha256: hash, destinationSha256: currentHash, archive, disposition });
  });
  console.log(`RECOVERED_ROOT ${source.root}`);
}
// Retain primary execution records, including command sidecars, failures and reviewer outputs.
await boundary(configuration.executionRoot);
await walk(configuration.executionRoot, async (file, path) => {
  const stat = await lstat(file);
  const target = join(evidence, "retained-originals/execution-records", path);
  if (stat.isDirectory()) { await mkdir(target, { recursive: true }); return; }
  if (!stat.isFile()) throw new Error(`Unexpected execution-record entry: ${file}`);
  await mkdir(dirname(target), { recursive: true });
  await copyFile(file, target, constants.COPYFILE_EXCL);
  rows.push({ sourcePath: file, sourceRoot: configuration.executionRoot, path, destination: target,
    deliveredPath: target, type: "file", size: stat.size, sha256: await sha256(file),
    sourceRevision: "primary execution record; raw-content binding", ownership: "migration-execution-record",
    ownershipEvidence: ["existing .omo/ulw-execute/dtf-migration execution record"],
    status: "source-qualified-execution-record", disposition: "lossless archive; do not replay historical commands" });
});
await walk(configuration.primaryMigration, async (file, path) => {
  const stat = await lstat(file);
  if (!stat.isFile()) throw new Error(`Unexpected primary migration entry: ${file}`);
  const hash = await sha256(file);
  if (hash !== await sha256(join(destination, path))) throw new Error(`Primary conflict: ${path}`);
  rows.push({ sourcePath: file, sourceRoot: configuration.primaryMigration, path,
    destination: join(destination, path), deliveredPath: join(destination, path),
    type: "file", size: stat.size, sha256: hash, sourceRevision: "primary; raw-content binding",
    ownership: "existing-primary-migration-output", ownershipEvidence: ["existing migration evidence; identical retained counterpart"],
    status: "identical", disposition: "existing identical current bytes retained" });
});
await writeFile(join(evidence, "recovery.json"), `${JSON.stringify({
  version: 1, destinationRoot: destination, qualification: configuration.qualification,
  roots: revisions, initialDestination, rows, differences, unresolved: [],
  auditException: "The recovery manifest and its generated verifier receipts are recorded separately to avoid recursive self-hashing.",
}, null, 2)}\n`, { flag: "wx" });
await writeFile(join(evidence, "recovery-differences.json"), `${JSON.stringify(differences, null, 2)}\n`, { flag: "wx" });
console.log(`RECOVERY_COMPLETE rows=${rows.length} differences=${differences.length}`);
