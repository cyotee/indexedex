import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdir, readFile, readdir, symlink, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const evidence = dirname(fileURLToPath(import.meta.url));
const root = resolve(evidence, "../../../../../..");
const runtime = join(evidence, "runtime");
const input = "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery";
const sources = (await readdir(join(root, "scripts/recovery/dtf-migration")))
  .filter((p) => p.endsWith(".ts")).sort().map((p) => join(root, "scripts/recovery/dtf-migration", p));
const identity = (bytes: Uint8Array) => ({
  bytes: bytes.byteLength, sha256: createHash("sha256").update(bytes).digest("hex"),
});
const sourceIdentities = await Promise.all(sources.map(async (path) => ({
  path, ...identity(await readFile(path)),
})));
const typeArgs = [join(root, "node_modules/typescript/bin/tsc"), "--noEmit", "--target", "ES2022",
  "--module", "ESNext", "--moduleResolution", "Bundler", "--strict", "--noUncheckedIndexedAccess",
  "--exactOptionalPropertyTypes", "--verbatimModuleSyntax", "--skipLibCheck", "--types", "node",
  "--typeRoots", join(root, "node_modules/@types")];
const phase = process.argv[2];
let command: readonly string[];
let cwd = root;
switch (phase) {
  case "types":
    command = ["bun", ...typeArgs, ...sources, fileURLToPath(import.meta.url)];
    break;
  case "support-types":
  case "support-types-final":
    command = ["bun", ...typeArgs, ...sources, fileURLToPath(import.meta.url),
      join(evidence, "raw.ts"), join(evidence, "oracle.ts")];
    break;
  case "oracle":
  case "oracle-final":
    command = ["bun", join(evidence, "oracle.ts")];
    break;
  case "suite":
    await mkdir(runtime);
    await mkdir(join(runtime, "tmp"));
    await symlink("/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-28-receipt-evidence/out", join(runtime, "out"));
    cwd = runtime;
    command = ["bun", "test", "--timeout", "15000", ...sources.filter((p) => p.endsWith(".test.ts"))];
    break;
  case "suite-final":
    await symlink(join(root, "scripts"), join(runtime, "scripts"));
    cwd = runtime;
    command = ["bun", "test", "--timeout", "15000", ...sources.filter((p) => p.endsWith(".test.ts"))];
    break;
  case "collect":
    command = ["bun", join(root, "scripts/recovery/dtf-migration/cli.ts"), "collect-receipts",
      "--input", input, "--output", join(evidence, "actual"), "--rpc-alias", "robinhood_mainnet_alchemy",
      "--selection", "conversions-and-recoveries"];
    break;
  default: throw new TypeError("explicit types, suite or collect phase required");
}
const started = new Date().toISOString();
const child = spawn(command[0] ?? "", command.slice(1), {
  cwd, env: { ...process.env, ...(phase?.startsWith("suite") ? { TMPDIR: join(runtime, "tmp") } : {}) },
  stdio: ["ignore", "pipe", "pipe"],
});
const closed = once(child, "close");
const stdout: Buffer[] = [], stderr: Buffer[] = [];
child.stdout?.on("data", (bytes: Buffer) => stdout.push(bytes));
child.stderr?.on("data", (bytes: Buffer) => stderr.push(bytes));
const [code, signal] = await closed;
const stopped = new Date().toISOString();
const out = Buffer.concat(stdout), err = Buffer.concat(stderr);
const secrets = phase === "collect" && process.env["ALCHEMY_KEY"]
  ? [process.env["ALCHEMY_KEY"], encodeURIComponent(process.env["ALCHEMY_KEY"])] : [];
for (const secret of secrets) {
  if (out.includes(secret) || err.includes(secret)) throw new TypeError("credential-bearing command stream withheld");
}
await writeFile(join(evidence, `${phase}.stdout`), out, { flag: "wx" });
await writeFile(join(evidence, `${phase}.stderr`), err, { flag: "wx" });
await writeFile(join(evidence, `${phase}.command.json`), JSON.stringify({
  phase, command, cwd, started, stopped, code, signal,
  stdout: identity(out), stderr: identity(err), sourceIdentities,
}, null, 2) + "\n", { flag: "wx" });
if (phase === "collect") {
  let files = 0;
  const scan = async (directory: string): Promise<void> => {
    for (const item of await readdir(directory, { withFileTypes: true })) {
      const path = join(directory, item.name);
      if (item.isDirectory()) await scan(path);
      else {
        const bytes = await readFile(path);
        files++;
        if (secrets.some((secret) => bytes.includes(secret))) throw new TypeError("credential present in evidence");
      }
    }
  };
  await scan(join(evidence, "actual"));
  await scan(join(evidence, "../implementation"));
  await writeFile(join(evidence, "credential-scan.json"), JSON.stringify({
    checkedLiteralAndEncodedSelectedCredential: secrets.length === 2, files, findings: 0,
    commandStreams: "clear", stopped,
  }, null, 2) + "\n", { flag: "wx" });
}
console.log(JSON.stringify({ phase, code, signal, stdout: out.toString(), stderr: err.toString() }));
process.exitCode = code === 0 ? 0 : 1;
