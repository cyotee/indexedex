import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { lstat, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

const [logArgument, executable, ...args] = process.argv.slice(2);
if (!logArgument || !executable) throw new Error("Expected log path and command");
const cwd = process.cwd();
const evidence = join(cwd, "docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-2");
const log = resolve(logArgument);
if (!log.startsWith(`${evidence}/`)) throw new Error("Command evidence must be task owned");
await mkdir(dirname(log), { recursive: true });
const temporary = join(evidence, "temporary");
await mkdir(temporary, { recursive: true });
const hashes = [];
const sources = [
  "docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts",
  "docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts",
  ...((await readdir(join(cwd, "scripts/recovery/dtf-migration")))
    .filter((name) => name.endsWith(".ts")).map((name) => `scripts/recovery/dtf-migration/${name}`)),
  "docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-2/recover.ts",
  "docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-2/run-command.ts",
];
for (const path of sources) {
  try {
    const stat = await lstat(join(cwd, path));
    if (!stat.isFile()) throw new Error(`Source is not a regular file: ${path}`);
    const bytes = await readFile(join(cwd, path));
    hashes.push({ path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") });
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      hashes.push({ path, absent: true });
    } else throw error;
  }
}
const started = new Date().toISOString();
const child = spawn(executable, args, { cwd, env: { ...process.env,
  TMPDIR: temporary, TMP: temporary, TEMP: temporary,
  XDG_CACHE_HOME: join(temporary, "cache"), BUN_RUNTIME_TRANSPILER_CACHE_PATH: "0",
}, stdio: ["ignore", "pipe", "pipe"] });
let output = "";
child.stdout.on("data", (chunk: Buffer) => { output += chunk.toString(); });
child.stderr.on("data", (chunk: Buffer) => { output += chunk.toString(); });
const result = await new Promise<{ code: number | null; signal: NodeJS.Signals | null }>((accept, reject) => {
  child.once("error", reject);
  child.once("close", (code, signal) => accept({ code, signal }));
});
await writeFile(log, output, { flag: "wx" });
await writeFile(`${log}.command.json`, `${JSON.stringify({
  command: [executable, ...args], cwd, started, ended: new Date().toISOString(), ...result,
  runtime: { bun: process.versions["bun"], node: process.versions.node, platform: process.platform, arch: process.arch },
  sourceBindings: hashes, log, temporary, qualification: "No Solidity compilation or network verification modes authorized for task 2.",
}, null, 2)}\n`, { flag: "wx" });
console.log(output);
console.log(`COMMAND_EXIT ${result.code} ${log}`);
process.exitCode = result.code ?? 1;
