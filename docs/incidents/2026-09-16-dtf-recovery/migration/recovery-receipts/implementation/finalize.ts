import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { readFile, writeFile, readdir, stat, rmdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { z } from "zod";

const base = dirname(fileURLToPath(import.meta.url)), root = resolve(base, "../../../../../..");
const mode = z.enum(["inventory", "seal"]).parse(process.argv[2]);
const identity = (b: Uint8Array) => ({ bytes: b.byteLength, sha256: createHash("sha256").update(b).digest("hex") });
const key = process.env["ALCHEMY_KEY"];
const secrets = key ? [key, encodeURIComponent(key)] : [];
const save = async (name: string, value: unknown) => {
  const b = Buffer.from(JSON.stringify(value, null, 2) + "\n");
  for (const secret of secrets) assert.equal(b.includes(secret), false, "credential in generated evidence");
  await writeFile(join(base, name), b, { flag: "wx" });
  return { path: name, ...identity(b) };
};
const json = async (name: string): Promise<unknown> => JSON.parse(await readFile(join(base, name), "utf8"));
const commandSchema = z.object({ code: z.number(), started: z.string(), stopped: z.string(),
  sourceIdentities: z.array(z.object({ path: z.string(), bytes: z.number(), sha256: z.string() })) });
if (mode === "inventory") {
  const command = "GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat git --no-pager";
  const args = ["-c", `${command} status --short --ignore-submodules; ${command} rev-parse HEAD; ${command} diff --ignore-submodules --check; ${command} diff --staged --stat; ${command} diff --ignore-submodules --binary`];
  const started = new Date().toISOString();
  const child = spawn("/bin/zsh", args, { cwd: root, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
  const closed = once(child, "close"); const out: Buffer[] = [], err: Buffer[] = [];
  child.stdout?.on("data", (b: Buffer) => out.push(b)); child.stderr?.on("data", (b: Buffer) => err.push(b));
  const [code, signal] = await closed; assert.equal(code, 0);
  await writeFile(join(base, "source.diff"), Buffer.concat(out), { flag: "wx" });
  await writeFile(join(base, "boundary.stderr"), Buffer.concat(err), { flag: "wx" });
  await save("boundary.command.json", { command: ["/bin/zsh", ...args], cwd: root, started,
    stopped: new Date().toISOString(), code, signal, stdout: identity(Buffer.concat(out)), stderr: identity(Buffer.concat(err)) });
  const operator = "scripts/recovery/dtf-migration";
  const paths = (await readdir(join(root, operator))).filter((p) => p.endsWith(".ts")).sort().map((p) => `${operator}/${p}`);
  paths.push("docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md");
  const sourceIdentities = await Promise.all(paths.map(async (path) => ({ path, ...identity(await readFile(join(root, path))) })));
  const gates = [];
  for (const phase of ["types-final", "operator-tests-complete", "collect", "reconcile"]) {
    const c = commandSchema.parse(await json(`${phase}.command.json`)); assert.equal(c.code, 0);
    for (const s of c.sourceIdentities) assert.deepEqual(sourceIdentities.find((v) => v.path === s.path), s);
    gates.push({ phase, code: c.code, started: c.started, stopped: c.stopped });
  }
  const failed = commandSchema.parse(await json("operator-tests-final.command.json"));
  const leaked = [];
  for (const name of await readdir(tmpdir())) {
    if (!name.startsWith("dtf-prepare-test-")) continue;
    const path = join(tmpdir(), name), s = await stat(path);
    if (s.birthtimeMs < Date.parse(failed.started) || s.birthtimeMs > Date.parse(failed.stopped)) continue;
    assert.deepEqual(await readdir(path), []);
    leaked.push(path);
  }
  assert.equal(leaked.length, 84);
  await save("temporary-cleanup-selection.json", { qualification: "empty fixture directories born during recorded failed-suite interval",
    started: failed.started, stopped: failed.stopped, paths: leaked });
  for (const path of leaked) await rmdir(path);
  const support = [];
  for (const path of ["record.ts", "reconcile.ts", "finalize.ts"]) support.push({ path, ...identity(await readFile(join(base, path))) });
  await save("source-manifest.json", { base: "07d54b9a3d20d98aee24e75235bbf16b650a8028",
    sourceIdentities, support, gates, sourceDiff: identity(Buffer.concat(out)),
    assumptions: ["current plan r5 and PRD r22 govern historical labels", "native output matching is not economic approval",
      "separate independent verification is not performed by this producer"] });
  await save("cleanup.json", { stopped: true, gates, runtime: "all owned collectors, test servers and recorder children exited",
    temporaryDirectoriesRemoved: leaked.length, retained: "all actual outputs, failed attempts and diagnostics",
    dependencies: { node_modules: "read-link to phase28/node_modules", out: "read-link to phase28/out for existing ABI only",
      copiedOrBuilt: false, installed: false },
    independentVerifier: "not run here; producer does not own verification/" });
  console.log(JSON.stringify({ inventory: "complete", sourceFiles: sourceIdentities.length, cleanup: leaked.length }));
} else {
  assert.ok(key, "existing credential required for literal/encoded absence scan");
  const files: string[] = [];
  async function visit(directory: string, prefix: string): Promise<void> {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = prefix ? `${prefix}/${entry.name}` : entry.name;
      assert.equal(entry.isSymbolicLink(), false);
      if (entry.isDirectory()) await visit(join(directory, entry.name), path);
      else if (entry.isFile()) files.push(path);
    }
  }
  await visit(base, "");
  assert.ok(files.includes("report.md")); assert.ok(!files.includes("seal.json")); assert.ok(!files.includes("manifest.json"));
  for (const path of files) {
    const bytes = await readFile(join(base, path));
    for (const secret of secrets) assert.equal(bytes.includes(secret), false, "credential found in evidence");
  }
  await save("credential-scan.json", { files: files.length, matches: 0,
    qualification: "existing selected RPC credential literal and URL-encoded values; never printed",
    runtime: "collector and oracle exited before scan; sealer exits after its final write" });
  files.push("credential-scan.json");
  const entries = await Promise.all(files.sort().map(async (path) => ({ path, ...identity(await readFile(join(base, path))) })));
  const manifest = await save("manifest.json", { files: entries, excludes: ["manifest.json", "seal.json"] });
  const bindings = await Promise.all(["report.md", "source-manifest.json", "cleanup.json", "actual/archive.json",
    "actual/reconciliation.json", "actual/http-manifest.json", "independent-proof.json"]
    .map(async (path) => ({ path, ...identity(await readFile(join(base, path))) })));
  await save("seal.json", { status: "stopped-producer-deliverable", manifest, bindings,
    independentVerification: "required separate verifier, not claimed", lastProducerWrite: true });
  console.log(JSON.stringify({ sealed: true, files: entries.length, credentialMatches: 0 }));
}
