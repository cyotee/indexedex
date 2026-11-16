import { strict as assert } from "node:assert";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { mkdir, readFile, readdir, readlink, lstat, symlink, unlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";

// Real CLI integration checks. Input bytes, not a copied production file list,
// provide the independent integrity oracle. No test-only production seam.
const execute = promisify(execFile);
const cwd = process.cwd();
const D = join(cwd, "docs/incidents/2026-09-16-dtf-recovery/migration");
const E = join(D, "conformance-20261114/task-2");
const helper = join(D, "resumed-integration/record-verification.ts");
const runner = join(E, "run-command.ts");
const attempt = process.argv[2] ?? "";
if (!/^(?:-r[1-9][0-9]*)?$/.test(attempt)) throw new Error("Expected optional -rN attempt suffix");
const base = join(E, `inventory-negative${attempt}`);
await mkdir(base, { recursive: false });
const source = join(base, "source");
const destination = join(base, "destination");
await mkdir(source);
await mkdir(destination);
const sha256 = (bytes: Buffer | string) => createHash("sha256").update(bytes).digest("hex");
const commands: object[] = [];
async function command(label: string, arguments_: readonly string[], expected: number) {
  const log = join(base, `${label}.log`);
  let code = 0;
  try { await execute("bun", [runner, log, "bun", helper, ...arguments_], { cwd, env: process.env }); }
  catch (error) {
    if (error instanceof Error && "code" in error && typeof error.code === "number") code = error.code;
    else throw error;
  }
  const output = await readFile(log, "utf8");
  commands.push({ label, command: ["bun", helper, ...arguments_], code, expected, log });
  assert.equal(code, expected, `${label}: ${output}`);
  return output;
}
async function snapshot(root: string): Promise<readonly object[]> {
  const records: object[] = [];
  for (const name of (await readdir(root)).sort()) {
    const path = join(root, name);
    const stat = await lstat(path);
    assert.ok(!stat.isDirectory(), "fixtures intentionally contain only flat files and links");
    records.push({ path, inode: stat.ino, mtime: stat.mtimeMs, size: stat.size,
      sha256: stat.isSymbolicLink() ? sha256(await readlink(path)) : sha256(await readFile(path)) });
  }
  return records;
}
// Source-only, byte-tampered, and outward-link failures must all be reported
// by one real delivery invocation, without touching either fixture tree.
await writeFile(join(source, "missing.bin"), Buffer.from([0, 13, 10, 255, 42]), { flag: "wx" });
await writeFile(join(source, "different.bin"), "original\n", { flag: "wx" });
await writeFile(join(destination, "different.bin"), "tampered\n", { flag: "wx" });
await writeFile(join(base, "outside.txt"), "outside source tree; never dereference\n", { flag: "wx" });
await symlink(join(base, "outside.txt"), join(source, "outward-link"));
const before = { source: await snapshot(source), destination: await snapshot(destination) };
const negativeInventory = join(base, "inventory");
await command("negative-inventory", ["inventory", negativeInventory, source, destination], 0);
const rejected = await command("negative-delivery", ["delivery", join(negativeInventory, "inventory.json"), join(base, "delivery")], 1);
for (const name of ["missing.bin", "different.bin", "outward-link"]) assert.ok(rejected.includes(name), `missing failure: ${name}`);
const after = { source: await snapshot(source), destination: await snapshot(destination) };
assert.deepEqual(after, before);
const negativeReceipt = JSON.parse(await readFile(join(base, "delivery/delivery.json"), "utf8"));
assert.equal(negativeReceipt.completed, false);
assert.equal(negativeReceipt.failures.length, 3);

// Malformed manifests and root symlinks must reject before creating output.
await writeFile(join(base, "malformed.json"), '{"version":1,"sourceRoot":"../escape"}\n', { flag: "wx" });
await command("malformed-input", ["delivery", join(base, "malformed.json"), join(base, "malformed-output")], 1);
assert.equal(await lstat(join(base, "malformed-output")).then(() => true).catch((error: unknown) => {
  if (error instanceof Error && "code" in error && error.code === "ENOENT") return false;
  throw error;
}), false);
await command("symlink-root", ["inventory", join(base, "symlink-output"), join(source, "outward-link"), destination], 1);
assert.equal(await lstat(join(base, "symlink-output")).then(() => true).catch((error: unknown) => {
  if (error instanceof Error && "code" in error && error.code === "ENOENT") return false;
  throw error;
}), false);

// Separate successful fixture verifies raw hashes, EOF classification,
// newly generated artifact inclusion, and stale snapshots without a copy list.
const happy = join(E, `inventory-fixture${attempt}`);
await mkdir(happy);
const from = join(happy, "source");
const to = join(happy, "destination");
await mkdir(from);
await mkdir(to);
const raw = Buffer.from([10, 13, 0, 255, 3, 10]);
await writeFile(join(from, "bytes.bin"), raw, { flag: "wx" });
await writeFile(join(to, "bytes.bin"), raw, { flag: "wx" });
await command("fixture-inventory", ["inventory", join(happy, "inventory"), from, to], 0);
await writeFile(join(to, "new-generated.json"), '{"fresh":true}\n', { flag: "wx" });
await command("fixture-delivery", ["delivery", join(happy, "inventory/inventory.json"), join(happy, "delivery")], 0);
const delivered = JSON.parse(await readFile(join(happy, "delivery/inventory.json"), "utf8"));
assert.equal(delivered.destination.find((entry: { path: string }) => entry.path === "bytes.bin")?.sha256, sha256(raw));
assert.equal(delivered.destination.find((entry: { path: string }) => entry.path === "new-generated.json")?.sha256, sha256('{"fresh":true}\n'));
await writeFile(join(from, "bytes.bin"), "changed after inventory\n");
const stale = await command("stale-source", ["delivery", join(happy, "inventory/inventory.json"), join(happy, "stale-delivery")], 1);
assert.ok(stale.includes("stale source inventory"));
await writeFile(join(from, "bytes.bin"), raw);
await writeFile(join(from, "eof.txt"), "same\n", { flag: "wx" });
await writeFile(join(to, "eof.txt"), "same\n\n", { flag: "wx" });
await command("eof-inventory", ["inventory", join(happy, "eof-inventory"), from, to], 0);
const eof = JSON.parse(await readFile(join(happy, "eof-inventory/inventory.json"), "utf8"));
assert.equal(eof.rows.find((entry: { path: string }) => entry.path === "eof.txt")?.status, "EOF-only");
const eofFailure = await command("eof-delivery", ["delivery", join(happy, "eof-inventory/inventory.json"), join(happy, "eof-delivery")], 1);
assert.ok(eofFailure.includes("eof.txt"));

await writeFile(join(base, "outward-link.link-text"), await readlink(join(source, "outward-link")), { flag: "wx" });
await unlink(join(source, "outward-link"));
await writeFile(join(base, "results.json"), `${JSON.stringify({
  completed: true, checks: 7, commands, before, after,
  negativeFailures: negativeReceipt.failures,
  fixtureDisposition: "Task-owned fixture bytes retained for review. The outward link was never dereferenced; its exact text is retained at outward-link.link-text.",
  cleanup: "Both fixture trees were unchanged across verification, as before/after snapshots prove. After checks, the owned outward symlink was archived as link text and unlinked. Disposable command caches are removed separately.",
}, null, 2)}\n`, { flag: "wx" });
console.log(`FIXTURE_QA_COMPLETE checks=7 commands=${commands.length}`);
