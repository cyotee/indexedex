import { spawn } from "node:child_process";
import { once } from "node:events";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const directory = fileURLToPath(new URL(".", import.meta.url));
const label = process.argv[2];
if (!label || !/^[a-z0-9-]+$/.test(label)) throw new Error("Expected evidence run label");
const defaultArgv = ["bun", "test", "--timeout", "15000",
  "./scripts/recovery/dtf-migration/bundle.test.ts",
  "./scripts/recovery/dtf-migration/preparation.test.ts",
  "./scripts/recovery/dtf-migration/execution.test.ts"] as const;
const argv = process.argv.length === 3 ? [...defaultArgv] : process.argv.slice(4);
const executable = argv[0];
if (!executable || (process.argv.length > 3 && process.argv[3] !== "--")) throw new Error("Expected label [-- exact argv]");
const paths = ["bundle.test.ts", "preparation.test.ts", "rehearsal-portable.ts", "rehearsal-proof.ts",
  "execution.test.ts", "bundle.ts", "bundle-files.ts", "execution-domain.ts", "journal.ts", "claimed-sy-witness.ts"];
const sourceHashes = async () => Promise.all(paths.map(async (name) => {
  const path = `scripts/recovery/dtf-migration/${name}`;
  return { path, sha256: fingerprint(await readFile(path)) };
}));
const before = await sourceHashes();
await writeFile(join(directory, `${label}.argv.json`), JSON.stringify({ argv, cwd: process.cwd(), sources: before }, null, 2) + "\n", { flag: "wx" });
const child = spawn(executable, argv.slice(1), {
  env: { ...process.env, ...(label === "final" ? { TASK12_EVIDENCE: directory } : {}) },
  stdio: ["ignore", "pipe", "pipe"],
});
const chunks: Buffer[] = [];
child.stdout.on("data", (chunk: Buffer) => chunks.push(chunk));
child.stderr.on("data", (chunk: Buffer) => chunks.push(chunk));
await once(child, "close");
const output = Buffer.concat(chunks);
// The exact command and observed exit precede all helper/test output.
const log = Buffer.concat([Buffer.from(`ARGV=${JSON.stringify(argv)}\nEXIT=${child.exitCode}\nSIGNAL=${child.signalCode ?? "none"}\n`), output]);
await writeFile(join(directory, `${label}.log`), log, { flag: "wx" });
await writeFile(join(directory, `${label}.result.json`), JSON.stringify({
  argv, exit: child.exitCode, signal: child.signalCode, logSha256: fingerprint(log),
  recorderSha256: fingerprint(await readFile(fileURLToPath(import.meta.url))),
  sourcesUnchanged: JSON.stringify(before) === JSON.stringify(await sourceHashes()),
}, null, 2) + "\n", { flag: "wx" });
console.log(log.toString());
process.exitCode = child.exitCode ?? 1;
