import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { resolve } from "node:path";
import { z } from "zod";
import { bind, binding, files, json, root, save } from "./evidence.js";

const here = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation");
const sourceRoot = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid";
const earlierRoot = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt/docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt";
const git = async (args: readonly string[]) => (await promisify(execFile)("git",
  ["-c", "submodule.recurse=false", ...args], {
    cwd: root, env: { ...process.env, GIT_MASTER: "1", GIT_OPTIONAL_LOCKS: "0" },
  })).stdout.trim();
assert.equal(await git(["rev-parse", "HEAD"]), "1df9076c73b94a4f63172395763fa8cdd48fe060");
assert.equal(await git(["branch", "--show-current"]), "work/dtf-migration-phase-19-earlier-liquid");
assert.equal(await git(["diff", "--cached", "--ignore-submodules=all", "--name-only"]), "");
const tracked = (await git(["diff", "--ignore-submodules=all", "--name-only"])).split("\n");
const additions = (await git(["ls-files", "--others", "--exclude-standard"])).split("\n")
  .filter(path => !path.startsWith("docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation/"));
const paths = [...new Set([...tracked, ...additions])].filter(Boolean).sort();
for (const path of paths) assert(
  path.startsWith("contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/")
  || path.startsWith("test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/")
  || path.startsWith("test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/")
  || path.startsWith("scripts/recovery/dtf-migration/")
  || path.startsWith("scripts/foundry/recovery/dtf-migration/")
  || path === "docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md", path);
const source = await Promise.all(paths.map(path => bind(resolve(root, path))));
const immutable = [];
for (const name of ["source", "source-verification"]) {
  const directory = resolve(sourceRoot, name);
  const sealed = z.object({ members: z.array(binding) }).passthrough()
    .parse(await json(resolve(directory, "seal.json")));
  const expected = sealed.members.map(row => resolve(directory, row.path)).sort();
  assert.deepEqual((await files(directory)).filter(path => !path.endsWith("/seal.json")), expected);
  for (const row of sealed.members) {
    const actual = await bind(resolve(directory, row.path));
    assert.equal(actual.bytes, row.bytes, row.path); assert.equal(actual.sha256, row.sha256, row.path);
    immutable.push(actual);
  }
  immutable.push(await bind(resolve(directory, "seal.json")));
}
assert.equal((await bind(resolve(sourceRoot, "source/contract.md"))).sha256,
  "86d4cf1d517b688b6b3aa8da73b00252c171d22182d92cb56a7e70f93d5339b4");
assert.equal((await bind(resolve(sourceRoot, "source-verification/report.md"))).sha256,
  "e56481a5040ae406b1c14122d404e227a0ea4391ecb03dd54b77283142b1af1b");
const inputSeal = z.object({ inputs: z.array(binding) }).passthrough()
  .parse(await json(resolve(sourceRoot, "source/seal.json")));
const authority = [];
for (const row of inputSeal.inputs) {
  const actual = await bind(row.path);
  assert.equal(actual.sha256, row.sha256, row.path); assert.equal(actual.bytes, row.bytes, row.path);
  authority.push(actual);
}
for (const path of [
  "/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase19-earlier-liquid-implementation-brief.md",
  resolve(earlierRoot, "verification/report.md"), resolve(earlierRoot, "commit/receipt.md"),
  resolve(earlierRoot, "commit/verification.md"), resolve(earlierRoot, "implementation/seal.json"),
]) authority.push(await bind(path));
const parentSeal = z.object({ evidence: z.array(binding) }).passthrough()
  .parse(await json(resolve(earlierRoot, "implementation/seal.json")));
const parentPreserved = [];
for (const row of parentSeal.evidence) {
  const actual = await bind(row.path);
  assert.equal(actual.sha256, row.sha256, row.path); assert.equal(actual.bytes, row.bytes, row.path);
  parentPreserved.push(actual);
}
await save(resolve(here, "source-manifest.json"), {
  base: "1df9076c73b94a4f63172395763fa8cdd48fe060", source, immutable, authority, parentPreserved,
});
console.log(JSON.stringify({ source: source.length, immutable: immutable.length, authority: authority.length,
  parentEvidencePreserved: parentPreserved.length, sourceModificationsStopped: true }));
