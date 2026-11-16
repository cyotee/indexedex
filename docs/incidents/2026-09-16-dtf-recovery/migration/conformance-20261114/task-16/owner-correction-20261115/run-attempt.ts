import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, open, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [attempt, command, ...args] = process.argv.slice(2);
assert(attempt && /^\d{2}-[a-z0-9-]+$/.test(attempt) && command);
assert(command === "bun" || command === "env");
assert(process.versions["bun"]);
const cwd = process.cwd();
const recorder = fileURLToPath(import.meta.url);
const directory = join(dirname(recorder), "attempts", attempt);
await mkdir(directory, { recursive: true });
const operator = "scripts/recovery/dtf-migration";
const paths = (await readdir(operator)).filter((name) => name.endsWith(".ts")).map((name) => join(operator, name));
paths.push(relative(cwd, recorder),
  "docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-12/mixed-fixture.ts");
for (const arg of args) {
  if (arg.endsWith(".ts") && !paths.includes(arg)) paths.push(arg);
}
const sources = await Promise.all(paths.sort().map(async (path) => {
  const raw = await readFile(path);
  return { path: resolve(path), bytes: raw.length, sha256: createHash("sha256").update(raw).digest("hex") };
}));
const runtimePath = command === "bun" ? process.execPath : "/usr/bin/env";
const runtimeRaw = await readFile(runtimePath);
const metadata = {
  cwd, argv: [command, ...args], resolvedExecutable: runtimePath,
  executableSha256: createHash("sha256").update(runtimeRaw).digest("hex"),
  recorder: { executable: process.execPath, bun: process.versions["bun"], node: process.versions.node,
    platform: process.platform, arch: process.arch },
  started: new Date().toISOString(), sources,
  stdout: join(directory, "stdout.log"), stderr: join(directory, "stderr.log"),
};
await writeFile(join(directory, "command.json"), JSON.stringify(metadata, null, 2) + "\n", { flag: "wx" });
const stdout = await open(metadata.stdout, "wx");
const stderr = await open(metadata.stderr, "wx");
let result: { readonly code: number | null; readonly signal: NodeJS.Signals | null };
try {
  const child = spawn(runtimePath, args, { cwd, env: process.env, stdio: ["ignore", stdout.fd, stderr.fd] });
  result = await new Promise((accept, reject) => {
    child.once("error", reject);
    child.once("exit", (code, signal) => accept({ code, signal }));
  });
} finally {
  await stdout.close();
  await stderr.close();
}
await writeFile(join(directory, "result.json"), JSON.stringify({
  ...result, ended: new Date().toISOString(), command: join(directory, "command.json"),
}, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ attempt, ...result, directory }));
process.exitCode = result.code ?? 1;
