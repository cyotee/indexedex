import assert from "node:assert/strict";
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const evidence = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification`;
const parent = "/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/verification.30kbMI";
const [label, observable, ...args] = process.argv.slice(2);
assert.match(label ?? "", /^[a-z0-9-]+$/);
assert.ok(observable && args.length);
assert.equal(process.cwd(), root);
const runRoot = await mkdtemp(`${parent}/${label}.`);
const env = {
  ...process.env, TMPDIR: runRoot, HOME: runRoot,
  BUN_INSTALL_CACHE_DIR: `${runRoot}/bun-cache`,
  npm_config_cache: `${runRoot}/node-cache`,
  XDG_CACHE_HOME: `${runRoot}/cache`,
  FOUNDRY_CACHE_PATH: `${runRoot}/foundry-cache`,
  NODE_COMPILE_CACHE: `${runRoot}/node-compile`,
  BUN_RUNTIME_TRANSPILER_CACHE_PATH: `${runRoot}/bun-transpiler`,
};
await mkdir(evidence, { recursive: true });
const secret = process.env.ALCHEMY_KEY;
const redact = text => secret ? text.replaceAll(secret, "[REDACTED]") : text;
const contract = {
  label, cwd: root, argv: args, literal: args.map(s => `'${s.replaceAll("'", "'\\''")}'`).join(" "),
  binaryPassObservable: observable, started: new Date().toISOString(),
  runtime: { bun: Bun.version, executable: process.execPath },
  resources: { runRoot, TMPDIR: env.TMPDIR, HOME: env.HOME,
    BUN_INSTALL_CACHE_DIR: env.BUN_INSTALL_CACHE_DIR,
    npm_config_cache: env.npm_config_cache, XDG_CACHE_HOME: env.XDG_CACHE_HOME,
    NODE_COMPILE_CACHE: env.NODE_COMPILE_CACHE,
    BUN_RUNTIME_TRANSPILER_CACHE_PATH: env.BUN_RUNTIME_TRANSPILER_CACHE_PATH },
  credentialPresent: Boolean(secret),
};
await writeFile(`${evidence}/${label}.command.json`, `${JSON.stringify(contract, null, 2)}\n`);
console.log(`WORKING ${label}: ${contract.literal}`);
console.log(`PASS_OBSERVABLE ${observable}`);
const child = spawn(args[0], args.slice(1), { cwd: root, env, stdio: ["ignore", "pipe", "pipe"] });
let stdout = "";
let stderr = "";
child.stdout.setEncoding("utf8");
child.stderr.setEncoding("utf8");
child.stdout.on("data", chunk => { stdout += chunk; });
child.stderr.on("data", chunk => { stderr += chunk; });
const outcome = await new Promise((resolve, reject) => {
  child.once("error", reject);
  child.once("close", (code, signal) => resolve({ code, signal }));
});
await writeFile(`${evidence}/${label}.stdout.log`, redact(stdout));
await writeFile(`${evidence}/${label}.stderr.log`, redact(stderr));
await writeFile(`${evidence}/${label}.exit.json`, `${JSON.stringify({
  ...contract, childPid: child.pid, ...outcome, finished: new Date().toISOString(),
}, null, 2)}\n`);
console.log(`VERIFY_COMMAND_DONE ${label} exit=${outcome.code}`);
process.exitCode = 0;
