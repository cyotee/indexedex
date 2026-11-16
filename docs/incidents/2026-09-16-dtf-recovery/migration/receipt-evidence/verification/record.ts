import { spawn } from "node:child_process";
import { once } from "node:events";
import { readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const owned = dirname(fileURLToPath(import.meta.url));
const root = resolve(owned, "../../../../../..");
const sources = (await readdir(join(root, "scripts/recovery/dtf-migration"))).filter((p) => p.endsWith(".ts"))
  .sort().map((p) => `scripts/recovery/dtf-migration/${p}`);
const input = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery";
const typeArgs = ["node_modules/typescript/bin/tsc", "--noEmit", "--target", "ES2022", "--module", "ESNext",
  "--moduleResolution", "Bundler", "--strict", "--noUncheckedIndexedAccess", "--exactOptionalPropertyTypes",
  "--verbatimModuleSyntax", "--skipLibCheck", "--types", "node"];
const git = "GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager";
const commands: Readonly<Record<string, readonly string[]>> = {
  types: ["bun", ...typeArgs, ...sources, join(owned, "record.ts")],
  tests: ["bun", "test", "--timeout", "15000", ...sources.filter((p) => p.endsWith(".test.ts")).map((p) => `./${p}`)],
  collect: ["/bin/zsh", "-lc", `cd '${root}' && exec bun scripts/recovery/dtf-migration/cli.ts collect-receipts --input '${input}' --output '${owned}/actual' --rpc-alias robinhood_mainnet_alchemy`],
  oracle: ["python3", "-B", join(owned, "independent.py"), input, join(owned, "actual"), join(owned, "../implementation/actual"), owned],
  boundary: ["/bin/zsh", "-c", `${git} rev-parse HEAD && ${git} branch --show-current && ${git} status --short --ignore-submodules=all && ${git} diff --ignore-submodules=all && ${git} diff --cached --ignore-submodules=all && ${git} diff --check --ignore-submodules=all`],
  scan: ["/bin/zsh", "-lc", `cd '${root}' && exec bun '${owned}/scan.ts'`],
};
const phase = process.argv[2];
const argv = phase ? commands[phase] : undefined;
if (!phase || !argv?.[0]) throw new TypeError("explicit known phase required");
const identity = (b: Uint8Array) => ({ bytes: b.byteLength, sha256: createHash("sha256").update(b).digest("hex") });
const sourceIdentities = await Promise.all(sources.map(async (path) => ({ path,
  ...identity(await readFile(join(root, path))) })));
const started = new Date().toISOString();
const child = spawn(argv[0], argv.slice(1), { cwd: root, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
const closed = once(child, "close");
const stdout: Buffer[] = [], stderr: Buffer[] = [];
child.stdout?.on("data", (chunk: Buffer) => stdout.push(chunk));
child.stderr?.on("data", (chunk: Buffer) => stderr.push(chunk));
const [code, signal] = await closed;
const out = Buffer.concat(stdout), err = Buffer.concat(stderr);
await writeFile(join(owned, `${phase}.stdout`), out, { flag: "wx" });
await writeFile(join(owned, `${phase}.stderr`), err, { flag: "wx" });
await writeFile(join(owned, `${phase}.command.json`), JSON.stringify({
  argv, cwd: root, started, stopped: new Date().toISOString(), code, signal,
  stdout: identity(out), stderr: identity(err), sourceIdentities,
}, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ phase, code, signal, stdoutBytes: out.length, stderrBytes: err.length }));
process.exitCode = code === 0 ? 0 : 1;
