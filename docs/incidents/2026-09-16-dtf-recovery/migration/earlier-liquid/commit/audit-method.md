# Independent ED delivery audit method

Date: 2026-11-12. This is an offline immutable-delivery inspection recipe, not a runtime replay.

## Inputs and ownership

Working directory is `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid`. Evidence root is `docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid`. Only `commit/verification.md`, this document and `commit/audit-evidence.json` are audit-owned. The entire `commit/` tree is excluded from the delivered source set and original incident inventories.

Read the complete commit, implementation and source briefs, actual ED source contract/producer/admission reports, implementation and independent runtime reports, actual delivery receipt, original precommit recipe, binding/capture/receipt algorithms, cleanup and cumulative ER runtime/receipt/immutable audit. Parse the complete JSON manifests, seals, final audits and original JSONL inventories, rather than treating displayed excerpts as the whole JSON. `audit-evidence.json` retains the resulting complete per-entry comparisons.

Every Git invocation uses `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`. Commands execute with this worktree as `-C`; status and diff include `--ignore-submodules=all`. Read-only command execution used `Bun.spawn(["env", "GIT_MASTER=1", "GIT_OPTIONAL_LOCKS=0", "git", "-C", wt, ...args], {env: process.env, stdin: "ignore", stdout: "pipe", stderr: "pipe"})`, awaiting stdout, stderr and process exit together. No index/ref write is necessary.

## Exact original inventory reproduction

The independent JS kernel imported `node:fs/promises` as `fs`, `node:crypto` as `crypto`, and `node:assert/strict` as `assert`. `wt` is the worktree above; `ed` is its absolute evidence root. The following is the actual field algorithm, expanded for readability:

```js
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex");
async function inspectEntry(path, relative, permissions) {
  const s = await fs.lstat(path);
  const target = s.isSymbolicLink() ? await fs.readlink(path) : null;
  const kind = s.isFile() ? "file" : s.isDirectory() ? "dir"
    : s.isSymbolicLink() ? "symlink" : "other";
  const hash = s.isFile() ? sha(await fs.readFile(path))
    : target !== null ? sha(target) : null;
  return permissions
    ? {path: relative, kind, perm: "0o" + (s.mode & 511).toString(8),
        size: s.size, sha256: hash}
    : {path: relative, kind,
        mode: s.isFile() ? ((s.mode & 73) ? "100755" : "100644")
          : s.isSymbolicLink() ? "120000" : "000000",
        size: s.size, sha256: hash, target};
}
async function walk(root, permissions) {
  const result = [];
  async function visit(path) {
    const row = await inspectEntry(path, path.slice(wt.length + 1), permissions);
    if (row.kind === "dir") {
      if (permissions) result.push(row);
      for (const name of (await fs.readdir(path)).sort()) {
        await visit(path + "/" + name);
      }
    } else {
      result.push(row);
    }
  }
  await visit(wt + "/" + root);
  return result.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
}
for (const [name, root, permissions] of [
  ["docs-incidents.jsonl", "docs/incidents", false],
  ["docs-incidents-perms.jsonl", "docs/incidents", true],
  ["out.jsonl", "out", false],
  ["cache_forge.jsonl", "cache_forge", false],
]) {
  const raw = await fs.readFile(ed + "/commit/precommit/" + name, "utf8");
  const original = raw.trimEnd().split("\n").map(JSON.parse);
  const current = await walk(root, permissions);
  const byPath = new Map(current.map(row => [row.path, row]));
  const priorPaths = new Set(original.map(row => row.path));
  const comparisons = original.map(before => ({
    path: before.path, before, after: byPath.get(before.path) ?? null,
    equal: JSON.stringify(before) === JSON.stringify(byPath.get(before.path)),
  }));
  const newRows = current.filter(row => !priorPaths.has(row.path));
  const retainedCurrentSha256 = sha(comparisons
    .map(row => JSON.stringify(row.after) + "\n").join(""));
  // Retain every comparison, missing/changed row, new row and both hashes.
}
```

No symlink directory is descended. Sorting is JS UTF-16 code-unit order, not locale collation. JSONL uses compact `JSON.stringify`, fixed insertion key order and one newline per record. Permission rows include ordinary directories and the root; git-mode rows do not. Compare each original row before considering aggregate equality. The sole permitted original-row difference is the reported enclosing directory size; do not suppress it or relabel its aggregate equal.

For every `host-dependencies.jsonl` row, apply `inspectEntry(absolutePath, absolutePath, false)` and insert `perm: "0o" + (lstat.mode & 511).toString(8)` between mode and size. Compare every original key including raw length/hash, target, kind and permission. Do not relocate dependencies.

For every `indexes.json:indexes` row, hash its original absolute `indexPath`; compare current raw length/hash, normalized regular mode and actual octal permission to that original row. Only the owned index may change. Retain all 21 foreign comparisons, including the held09 index hash without inspecting its candidate.

Parse original `show-ref.txt` and fresh `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git -C "$WT" show-ref` into refname-to-object maps. Compare the union of keys. Exactly the owned branch may move from the required parent to the delivered commit. Ref identity has no filesystem mode. Independently compare both dependency links' lstat inode/mode/permission/length, raw target string and SHA-256.

Rehash every original `extra.json:aggregates` target. Its 13 non-self bindings match. The self entry has a distinct reproducible meaning: delete only `aggregates["extra.json"]` from the parsed object, serialize with `JSON.stringify(value, null, 2) + "\n"`, and hash. That reproduces the declared self value, not the raw final file hash. Preserve and disclose both.

## Source and immutable commit checks

Derive the accepted source roles from complete `verification/audit-final.json:results[1].bound.preserved`: paths under this worktree's `contracts/`, `scripts/`, `test/`, and the exact operator runbook path. Require 32 unique entries. Cross-check the complete set and every binding against results[0], producer `implementation/source-manifest.json:source`, `implementation/audit-final.json:runtimeBindings.preserved`, precommit source identity and delivery manifest.

Inspect complete `git diff --ignore-submodules=all --no-ext-diff --no-color "$PARENT" HEAD`, including all added file bodies. Compare its complete raw no-abbreviation delta to the derived accepted set. For every path, hash current bytes and `git cat-file blob HEAD:path`; compare lengths, accepted permission420, committed mode100644, precommit/producer/both-audit hashes and every manifest hash field. Recompute each Git blob ID from `blob <raw byte length>\0<raw bytes>`. Match parent blob/mode and distinguish all four additions from 28 modifications. Compare actual `ls-files --stage -z` records to those same blobs/modes at stage0.

Read `git cat-file commit HEAD`; recompute SHA-1 with the raw `commit <length>\0` object framing. Require one parent header equal to `1df9076c73b94a4f63172395763fa8cdd48fe060`, one commit in parent..HEAD, expected branch/tree/subject and exactly one required coauthor in the final trailer paragraph. Verify the actual commit signature, preserving unknown ownertrust.

Run the complete immutable whitespace gate, not merely the empty index:

```text
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git -C "$WT" diff --ignore-submodules=all --check 1df9076c73b94a4f63172395763fa8cdd48fe060 HEAD
```

Require exit0 with empty output. Check staged and unstaged tracked diffs with `--exit-code`; no `write-tree`, staging or commit is needed. Preserve original staged-gate records as historical evidence, not a newly reconstructed staging operation.

## Static runtime binding without replay

Rehash all complete producer/verifier seal members, manifest source/immutable/authority/parent-preserved arrays and all current binding records in both independent audits. Verify exact producer/verifier evidence membership with their basename self exclusions; original source-only seals have absolute and relative member paths, so use `path.resolve(root, row.path)`. Source producer mode strings are octal (`"644"`); implementation bindings use decimal420. Normalize their encoding, not their bytes or permissions.

For both retained runtime runs, parse actual artifacts and metadata, compare current compiler-source keccak256 values, runtime lengths and code hashes, and complete deployed bytes after only re-derived compiler-declared immutable/link spans and explicitly checked compiler library self-address spans. Check actual library identity/addresses. Decode registry `deployPkg(bytes,bytes,bytes32)`, require exact creation bytecode and constructor argument concatenation against the CREATE record, derive all22 immutable addresses from decoded constructor fields and SELF, and compare each declared runtime span. The package-constructor transaction is not the much larger parent registration transaction.

Parse every `rpc.ndjson` line and each original HTTP body. Index canonical transaction/receipt/block objects by hash. Require417 nonsynthetic signatures to reconstruct to their actual hash/signer/chain4663; retain167 exact synthetic r=s=1 fixtures without a cryptographic signer claim. Match transaction/receipt block identity and transaction membership. Compare all fields of every fresh89 signed and four reconstructed receipts recursively with captured wire receipts.

For both runs, decode89 retained original raw payloads against their original files and receipt objects. Independently recreate four acquisition signatures from their disclosed local derivation index, recorded request/nonce/type0/effective gas price and2000000 gas limit; require actual mined-hash equality. Reconstructed bytes are never original signing captures.

For three resumes per run, compare original pre-resume and completion receipts including nested logs, nonce/gas/signature quantities and raw signed hash. Check actual retained SIGKILL/code-null command records and mined-before-checkpoint faults. Authenticate odd-length scalar values as integers; do not execute or fix the frozen producer auditor.

Compare all24 original captured prepared-input files and current bytes to their original hashes/lengths. Retain48 historical producer drift rows and zero present independent drift separately. Do not overwrite historical current hashes with today's equal values. Independently recompute ED remaining-credit arithmetic, exact terminal credit, fresh cliff, seven-unit raw/booked gap and preserved ER ledgers from retained observations.

Finally inspect actual listener/PID state, absent checkpoint/runtime parent and Git operation/lock files. No service or monitor was started by this audit. `audit-evidence.json` records commands, exits, complete per-entry results and the two corrected inspection-schema mistakes; they were not source/evidence defects.
