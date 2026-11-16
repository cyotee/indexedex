import { createHash } from "node:crypto";
import { open, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { spawn } from "node:child_process";
import { once } from "node:events";

const root = process.cwd();
const base = dirname(new URL(import.meta.url).pathname);
const attempt = process.env["TASK7_QA_ATTEMPT"];
if (attempt !== undefined && !/^attempt-[1-9][0-9]*$/.test(attempt)) throw new Error("Invalid evidence attempt directory");
const output = attempt ? join(base, attempt) : base;
const label = process.argv[2];
const argv = process.argv.slice(4);
if (!label || !/^[a-z0-9-]+$/.test(label) || process.argv[3] !== "--" || !argv.length) {
  throw new Error("Expected label -- exact argv");
}
const digest = (bytes: string | Uint8Array) => createHash("sha256").update(bytes).digest("hex");
const quote = (arg: string) => /^[a-zA-Z0-9_./:=*-]+$/.test(arg) ? arg : `'${arg.replaceAll("'", "'\\''")}'`;
const command = argv.map(quote).join(" ");
const sources = async () => {
  const paths: string[] = [];
  const scan = async (path: string) => {
    for (const entry of await readdir(join(root, path), { withFileTypes: true })) {
      const file = join(path, entry.name);
      if (entry.isDirectory()) await scan(file);
      else if (entry.isFile() && /\.(ts|sol)$/.test(entry.name)) paths.push(file);
    }
  };
  await scan("scripts/recovery/dtf-migration");
  await scan("contracts/vaults/detf/protocols/dexes/uniswap/v4/migration");
  paths.push("scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol",
    "scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol");
  return Promise.all(paths.sort().map(async (path) => ({ path, sha256: digest(await readFile(join(root, path))) })));
};
const before = await sources();
const sourceFingerprint = digest(JSON.stringify(before));
const log = join(output, `${label}.log`);
const preflight = { argv, command, cwd: root, runtime: { bun: process.versions["bun"], nodeCompatibility: process.version },
  harness: { recorderSha256: digest(await readFile(new URL(import.meta.url))),
    forgeHelperSha256: digest(await readFile(join(root, "scripts/forge-artifacts.py"))) },
  environment: { PATH: process.env["PATH"] ?? null,
    FOUNDRY_SCRIPT_EXECUTION_PROTECTION: process.env["FOUNDRY_SCRIPT_EXECUTION_PROTECTION"] ?? null },
  sourceFingerprint, sources: before, startedAt: new Date().toISOString(), log };
await writeFile(join(output, `${label}.preflight.json`), JSON.stringify(preflight, null, 2) + "\n", { flag: "wx" });
const file = await open(log, "wx");
let exitCode: number;
let processExitCode: number | null;
let processSignal: NodeJS.Signals | null;
try {
  await file.writeFile(command + "\n");
  await file.sync();
  const executable = argv[0];
  if (!executable) throw new Error("Executable missing");
  const child = spawn(executable, argv.slice(1), { cwd: root, env: process.env, stdio: ["ignore", file.fd, file.fd] });
  await once(child, "close");
  processExitCode = child.exitCode;
  processSignal = child.signalCode;
  exitCode = processExitCode ?? 1;
  await file.writeFile(`\nPROCESS_EXIT_CODE=${processExitCode}\nPROCESS_SIGNAL=${processSignal ?? "none"}\n`);
  await file.sync();
} finally { await file.close(); }
const raw = await readFile(log, "utf8");
const after = await sources();
const unchanged = digest(JSON.stringify(after)) === sourceFingerprint;
const passed = raw.match(/\n\s*(\d+) pass\b/)?.[1];
const failed = raw.match(/\n\s*(\d+) fail\b/)?.[1];
const result = { ...preflight, completedAt: new Date().toISOString(), exitCode, processExitCode, processSignal,
  sourceUnchanged: unchanged, logSha256: digest(raw),
  passed: passed === undefined ? null : Number(passed), failed: failed === undefined ? null : Number(failed) };
await writeFile(join(output, `${label}.command.json`), JSON.stringify(result, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ label, exitCode, sourceUnchanged: unchanged, passed: result.passed, failed: result.failed, log: resolve(log) }));
console.log(`QA_EXIT_CODE=${exitCode}`);
process.exitCode = unchanged ? exitCode : 1;
