import { spawn } from "node:child_process";
import { once } from "node:events";
import { createWriteStream } from "node:fs";
import { finished } from "node:stream/promises";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

class RecordingError extends Error {
  constructor(readonly reason: string) { super(reason); this.name = "RecordingError"; }
}
const digest = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
async function main() {
  const [label, cwdInput, executable, ...args] = process.argv.slice(2);
  if (!label || !cwdInput || !executable || !/^[0-9]{2}-[a-z0-9-]+$/.test(label)) {
    throw new RecordingError("numbered label, cwd, executable and argv required");
  }
  const cwd = resolve(cwdInput);
  const output = join(dirname(fileURLToPath(import.meta.url)), "attempts", label);
  await mkdir(dirname(output), { recursive: true });
  await mkdir(output);
  const sources: Record<string, string> = {};
  const walk = async (path: string): Promise<void> => {
    for (const entry of await readdir(join(cwd, path), { withFileTypes: true })) {
      const relative = join(path, entry.name);
      if (entry.isDirectory()) await walk(relative);
      else if (entry.isFile()) sources[relative] = digest(await readFile(join(cwd, relative)));
    }
  };
  for (const path of ["scripts/recovery/dtf-migration", "scripts/foundry/recovery/dtf-migration",
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration"]) await walk(path);
  const started = new Date().toISOString();
  await writeFile(join(output, "command.json"), JSON.stringify({
    argv: [executable, ...args], cwd, started, sources, runtime: process.versions,
    environment: { forge: process.env["FORGE_BIN"] ?? "forge", anvil: process.env["ANVIL_BIN"] ?? "anvil",
      archiveCredentialPresent: Boolean(process.env["ALCHEMY_KEY"]) },
  }, null, 2), { flag: "wx" });
  const stdout = createWriteStream(join(output, "stdout.log"), { flags: "wx" });
  const stderr = createWriteStream(join(output, "stderr.log"), { flags: "wx" });
  const child = spawn(executable, args, { cwd, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
  const closed = once(child, "close");
  child.stdout.pipe(stdout);
  child.stderr.pipe(stderr);
  const [code, signal] = await closed;
  await Promise.all([finished(stdout), finished(stderr)]);
  const streams = {};
  const identities = [];
  for (const name of ["stdout.log", "stderr.log"]) {
    const raw = await readFile(join(output, name));
    identities.push({ name, bytes: raw.length, sha256: digest(raw) });
  }
  await writeFile(join(output, "result.json"), JSON.stringify({ code, signal, started,
    finished: new Date().toISOString(), streams: identities, sources }, null, 2), { flag: "wx" });
  console.log(JSON.stringify({ label, code, signal, output }));
  process.exitCode = typeof code === "number" ? code : 1;
}
try { await main(); }
catch (error) {
  if (!(error instanceof Error)) throw error;
  console.error(JSON.stringify({ recordingFailed: error.message }));
  process.exitCode = 1;
}
