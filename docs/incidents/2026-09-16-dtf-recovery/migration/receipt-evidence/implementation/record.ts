import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdir, writeFile, readdir, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const evidence = dirname(fileURLToPath(import.meta.url));
const root = resolve(evidence, "../../../../../..");
const phase = process.argv[2];
const typeArgs = ["node_modules/typescript/bin/tsc", "--noEmit", "--target", "ES2022", "--module", "ESNext",
  "--moduleResolution", "Bundler", "--strict", "--noUncheckedIndexedAccess", "--exactOptionalPropertyTypes",
  "--verbatimModuleSyntax", "--skipLibCheck", "--types", "node"];
const sources = (await readdir(join(root, "scripts/recovery/dtf-migration"))).filter((p) => p.endsWith(".ts"))
  .map((p) => `scripts/recovery/dtf-migration/${p}`);
const commands: Readonly<Record<string, readonly string[]>> = {
  "types01": ["bun", ...typeArgs, ...sources, join(evidence, "record.ts")],
  "focused01": ["bun", "test", "--timeout", "15000", "./scripts/recovery/dtf-migration/receipt.test.ts",
    "./scripts/recovery/dtf-migration/receipt-reconciliation.test.ts"],
  "mutation01": ["bun", "test", "--timeout", "15000", "./scripts/recovery/dtf-migration/receipt.test.ts",
    "./scripts/recovery/dtf-migration/receipt-reconciliation.test.ts"],
  "types-final": ["bun", ...typeArgs, ...sources, join(evidence, "record.ts"), join(evidence, "independent.ts")],
  "operator-tests-final": ["bun", "test", "--timeout", "15000", ...sources.filter((p) => p.endsWith(".test.ts")).map((p) => `./${p}`)],
  "collect": ["/bin/zsh", "-lc", `cd '${root}' && exec bun scripts/recovery/dtf-migration/cli.ts collect-receipts --input '/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery' --output '${evidence}/actual' --rpc-alias robinhood_mainnet_alchemy`],
  "independent": ["bun", join(evidence, "independent.ts")],
};
const command = phase ? commands[phase] : undefined;
if (!phase || !command?.[0]) throw new TypeError("explicit recorder phase required");
await mkdir(evidence, { recursive: true });
const started = new Date().toISOString();
const sourceIdentities = await Promise.all(sources.map(async (path) => {
  const bytes = await readFile(join(root, path));
  return { path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") };
}));
const child = spawn(command[0], command.slice(1), { cwd: root, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const exited = once(child, "close");
let stdout = "", stderr = "";
child.stdout?.on("data", (b: Buffer) => { stdout += b.toString(); });
child.stderr?.on("data", (b: Buffer) => { stderr += b.toString(); });
const [code, signal] = await exited;
await writeFile(join(evidence, `${phase}.stdout`), stdout, { flag: "wx" });
await writeFile(join(evidence, `${phase}.stderr`), stderr, { flag: "wx" });
const identity = (bytes: string) => ({ bytes: Buffer.byteLength(bytes), sha256: createHash("sha256").update(bytes).digest("hex") });
await writeFile(join(evidence, `${phase}.command.json`), JSON.stringify({
  command, cwd: root, started, stopped: new Date().toISOString(), code, signal,
  stdout: identity(stdout), stderr: identity(stderr), sourceIdentities,
}, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ phase, code, signal, stdout, stderr }));
process.exitCode = code === 0 ? 0 : 1;
