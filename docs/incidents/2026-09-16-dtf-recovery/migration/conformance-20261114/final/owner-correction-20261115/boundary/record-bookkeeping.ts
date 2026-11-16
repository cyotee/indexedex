import { mkdir, writeFile, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const [label, ...argv] = process.argv.slice(2);
if (!label || !/^[a-z-]+$/.test(label) || !argv.length) throw new Error("label and exact command required");
const directory = join(dirname(fileURLToPath(import.meta.url)), "commands", label);
await mkdir(directory, { recursive: true });
const recorder = resolve("docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts");
const recorderBytes = await readFile(recorder);
const started = new Date().toISOString();
await writeFile(join(directory, "command.json"), JSON.stringify({
  cwd: process.cwd(), argv, started, runtime: process.versions,
  recorder: { path: recorder, sha256: createHash("sha256").update(recorderBytes).digest("hex") },
  scope: "Offline file inventory bookkeeping only",
}, null, 2) + "\n", { flag: "wx" });
const executable = argv[0];
if (!executable) throw new Error("executable required");
const child = spawn(executable, argv.slice(1), {
  cwd: process.cwd(), env: process.env, stdio: ["ignore", "pipe", "pipe"],
});
if (!child.stdout || !child.stderr) throw new Error("captured command streams required");
const stdoutChunks: Buffer[] = [];
const stderrChunks: Buffer[] = [];
child.stdout.on("data", (chunk: Buffer) => stdoutChunks.push(chunk));
child.stderr.on("data", (chunk: Buffer) => stderrChunks.push(chunk));
const outcome = await new Promise<{ exit: number | null; signal: string | null }>((resolve, reject) => {
  child.once("error", reject);
  child.once("close", (exit, signal) => resolve({ exit, signal }));
});
const stdout = Buffer.concat(stdoutChunks);
const stderr = Buffer.concat(stderrChunks);
const { exit, signal } = outcome;
// Publish immutable raw streams after the scanner exits, so no growing log is
// misrepresented as a frozen inventory preimage.
await writeFile(join(directory, "stdout.log"), Buffer.from(stdout), { flag: "wx" });
await writeFile(join(directory, "stderr.log"), Buffer.from(stderr), { flag: "wx" });
await writeFile(join(directory, "result.json"), JSON.stringify({
  argv, cwd: process.cwd(), started, finished: new Date().toISOString(),
  exit, signal, stdoutBytes: stdout.byteLength, stderrBytes: stderr.byteLength,
}, null, 2) + "\n", { flag: "wx" });
console.log(`BOUNDARY_COMMAND ${label} exit=${exit}`);
console.log(new TextDecoder().decode(stdout).trim());
process.exitCode = exit ?? 1;
