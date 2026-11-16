import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { text } from "node:stream/consumers";
import { lstat, readFile, readdir, rmdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { createHash } from "node:crypto";
import { z } from "zod";

const here = dirname(import.meta.filename);
const runtime = process.argv[2];
assert(runtime, "exact stopped runtime required");
const cleanup = z.object({ node: z.literal("exited"), runtime: z.literal("removed"),
  checkpoint: z.string(), pid: z.number().int().positive() }).passthrough()
  .parse(JSON.parse(await readFile(join(runtime, "cleanup.json"), "utf8")));
const commands: { readonly binary: string; readonly args: readonly string[];
  readonly code: number | null; readonly signal: string | null;
  readonly stdout: string; readonly stderr: string }[] = [];
async function command(binary: string, args: string[]) {
  const child = spawn(binary, args, { cwd: process.cwd(), env: { ...process.env,
    GIT_MASTER: "1", GIT_OPTIONAL_LOCKS: "0", GIT_PAGER: "cat", PAGER: "cat" },
  stdio: ["ignore", "pipe", "pipe"] });
  const done = once(child, "close", { signal: AbortSignal.timeout(30000) });
  const [stdout, stderr, closed] = await Promise.all([text(child.stdout), text(child.stderr), done]);
  const [code, signal] = z.tuple([z.number().nullable(), z.string().nullable()]).parse(closed);
  const row = { binary, args, code, signal, stdout, stderr };
  commands.push(row);
  return row;
}
const listener = await command("lsof", ["-nP", "-iTCP:18575", "-sTCP:LISTEN"]);
assert.equal(listener.code, 1);
assert.equal(listener.stdout, "");
const processState = await command("ps", ["-p", String(cleanup.pid), "-o", "pid="]);
assert.equal(processState.code, 1);
assert.equal(processState.stdout, "");
await assert.rejects(lstat(cleanup.checkpoint), { code: "ENOENT" });
const parent = resolve(".omo-runtime/dtf-migration-portable");
assert.equal(dirname(cleanup.checkpoint), parent);
assert.deepEqual(await readdir(parent), []);
await rmdir(parent);
for (const args of [
  ["--no-pager", "diff", "--check", "--ignore-submodules=all"],
  ["--no-pager", "diff", "--cached", "--exit-code", "--ignore-submodules=all"],
  ["--no-pager", "status", "--short", "--ignore-submodules=all"],
  ["--no-pager", "rev-parse", "HEAD"],
  ["--no-pager", "branch", "--show-current"],
]) assert.equal((await command("git", args)).code, 0);
assert(commands.some(c => c.stdout.trim() === "137fa0c8749165087c7d1d0156788f58a1dbf1b8"));
assert(commands.some(c => c.stdout.trim() === "work/dtf-migration-phase-26-portable-operator"));
const manifest = z.object({ git: z.array(z.object({
  path: z.string(), sha256: z.string(), bytes: z.number(), mode: z.number(),
})) }).passthrough().parse(JSON.parse(await readFile(join(here, "source-manifest-stopped.json"), "utf8")));
for (const entry of manifest.git) {
  const raw = await readFile(entry.path);
  assert.equal(raw.length, entry.bytes);
  assert.equal(createHash("sha256").update(raw).digest("hex"), entry.sha256);
  assert.equal((await lstat(entry.path)).mode & 0o777, entry.mode);
}
await writeFile(join(here, "cleanup-final.json"), JSON.stringify({
  runtime, cleanup, commands, checkpointAbsent: true, ownedEmptyRuntimeParentRemoved: parent,
  sourceStopped: true, ownedIndexAndRefUnchanged: true,
  subscriptions: "CLI receipt subscriptions close in finally; canonical observer exited 0 after node exit.",
  pendingOwnedOperations: "none after the completed audit and this cleanup process exits",
}, null, 2) + "\n", { flag: "wx" });
console.log("PORTABLE_CLEANUP_COMPLETE");
