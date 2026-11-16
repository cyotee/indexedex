import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";
import { fingerprint, readReference } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "adversarial");
await mkdir(root, { recursive: false });
const results: unknown[] = [];
const run = async (label: string, argv: readonly string[], timeout?: number) => {
  const executable = argv[0];
  if (!executable) throw new Error("executable required");
  console.log("ARGV", JSON.stringify(argv));
  const child = spawn(executable, argv.slice(1), { env: process.env,
    stdio: ["ignore", "pipe", "pipe"], ...(timeout ? { timeout } : {}) });
  const closed = once(child, "close");
  let output = "";
  child.stdout.on("data", (bytes: Buffer) => { output += bytes.toString(); });
  child.stderr.on("data", (bytes: Buffer) => { output += bytes.toString(); });
  const [code, signal] = await closed;
  await writeFile(join(root, `${label}.log`),
    `ARGV ${JSON.stringify(argv)}\n${output}\nEXIT_CODE ${code}\nSIGNAL ${signal}\n`, { flag: "wx" });
  return { code, signal, output };
};
const misleading = await run("misleading-success", ["bun", "-e", 'console.log("ALL TESTS PASS"); process.exit(7)']);
assert.equal(misleading.code, 7);
results.push({ probe: "misleading_success_output", accepted: false, ...misleading });
const hung = await run("hung-command", ["bun", "-e", 'console.log("READY"); setInterval(() => {}, 1000)'], 500);
assert.equal(hung.code, null);
assert.equal(hung.signal, "SIGTERM");
results.push({ probe: "hung_commands", ...hung,
  qualification: "Synthetic child deadline only. No Forge process was killed for silence." });
const original = Buffer.from('{"blockNumber":"108944663","book":"A"}');
const path = resolve(root, "state.json");
await writeFile(path, original, { flag: "wx" });
const reference = { path, sha256: fingerprint(original), bytes: String(original.length) };
assert.deepEqual(await readReference(reference), original);
await writeFile(path, '{"blockNumber":"108944664","book":"B"}');
await assert.rejects(readReference(reference), /referenced raw bytes differ/);
results.push({ probe: "stale_state", rejected: true, boundary: "readReference authenticated bytes" });
const artifactPath = "out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json";
const artifact = await readFile(artifactPath);
const cached = resolve(root, "cached-artifact.json");
await writeFile(cached, artifact, { flag: "wx" });
const artifactReference = { path: cached, sha256: fingerprint(artifact), bytes: String(artifact.length) };
await readReference(artifactReference);
await writeFile(cached, '{"abi":[]}');
await assert.rejects(readReference(artifactReference), /referenced raw bytes differ/);
results.push({ probe: "generated_or_cached_artifacts", rejected: true, originalArtifact: artifactPath,
  sha256: fingerprint(artifact), boundary: "readReference authenticated bytes",
  qualification: "Fresh Solar runtime artifact rebuild and source hashes are recorded separately." });
const dirty = await run("dirty-worktree", ["env", "GIT_MASTER=1", "git", "status", "--short"]);
assert.equal(dirty.code, 0);
assert.match(dirty.output, /rehearsal|migration/);
results.push({ probe: "dirty_worktree", observed: true, mutations: "Only task 11 owned paths; no Git mutations." });
await writeFile(join(root, "results.json"), JSON.stringify({
  results, flaky: "not applicable; no retry-to-green policy",
  cancellation: "Applicable only to the deliberately hung synthetic child; SIGTERM observed.",
  interruptions: "not introduced in economic operations",
  untrustedText: "not applicable; no command was derived from untrusted text",
}, null, 2), { flag: "wx" });
console.log("ADVERSARIAL_PROBES_PASS");
