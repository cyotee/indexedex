import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdir, open, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { Readable } from "node:stream";
import { createHash } from "node:crypto";

const [label, executable, ...args] = process.argv.slice(2);
if (!label || !executable || !/^[a-z0-9-]+$/.test(label)) throw new Error("label and exact argv required");
const root = resolve(dirname(fileURLToPath(import.meta.url)), `attempt-${label}`);
await mkdir(root, { recursive: false });
const sources: Record<string, string> = {};
async function census(path: string): Promise<void> {
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const file = join(path, entry.name);
    if (entry.isDirectory()) await census(file);
    else if (/\.(sol|ts|py)$/.test(file)) sources[file] = createHash("sha256").update(await readFile(file)).digest("hex");
  }
}
for (const path of ["contracts/vaults/detf/protocols/dexes/uniswap/v4/migration",
  "scripts/recovery/dtf-migration", "scripts/foundry/recovery/dtf-migration",
  "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration",
  "test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration",
  "docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-11"]) await census(path);
for (const file of ["scripts/forge-artifacts.py",
  "docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts"]) {
  sources[file] = createHash("sha256").update(await readFile(file)).digest("hex");
}
const argv = [executable, ...args];
const command = argv.map((arg) => /^[a-zA-Z0-9_./:=+-]+$/.test(arg) ? arg : JSON.stringify(arg)).join(" ");
const log = await open(join(root, "raw.log"), "wx");
await log.write(`ARGV ${JSON.stringify(argv)}\n$ ${command}\n`);
console.log(`$ ${command}`);
const child = spawn(executable, args, { env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const exited = once(child, "close");
const copy = async (stream: Readable) => {
  for await (const chunk of stream) {
    if (!Buffer.isBuffer(chunk)) throw new Error("expected raw process bytes");
    await log.write(chunk); process.stdout.write(chunk);
  }
};
const [status] = await Promise.all([exited, copy(child.stdout), copy(child.stderr)]);
const [code, signal] = status;
await log.write(`\nEXIT_CODE ${code}\nSIGNAL ${signal}\n`);
await log.close();
await writeFile(join(root, "commands.json"), JSON.stringify({
  command, argv, cwd: process.cwd(), sourceFingerprint: createHash("sha256").update(JSON.stringify(sources)).digest("hex"),
  sources, runtime: { bun: process.versions["bun"], forge: process.env["FORGE_BIN"] }, exitCode: code, signal,
  log: join(root, "raw.log"), caseCounts: "See raw log; no count inferred from success text.",
}, null, 2), { flag: "wx" });
console.log(`EXIT_CODE ${code}`);
process.exitCode = typeof code === "number" ? code : 1;
