# Independent immutable audit method

Date: 2026-11-12. Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-23-claimed-sy-integration`.
This audit uses read-only filesystem and Git observations. It does not execute
the producer/verifier runner, tests, builds, CLI, RPC or source transactions.
All Git processes have `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`; every status/diff
ignores submodules. No index refresh, write-tree, staging or ref write is used.

## Inputs and derivation

Read the complete actual commit and amended implementation briefs, actual
commit receipt, producer and independent-r2 reports, original failed
verification report, source22 contract/producer/admission reports, and the
phase21 producer/runtime/immutable-delivery reports. Read both final cleanup
records, both command recipes, r2 audit.ts and producer probe/bindings.ts.
Parse complete manifests, seals, original precommit inventories, source22
membership and additional-input bindings; do not infer membership from totals.

Require the actual r2 report's raw SHA-256
`14750c64ed29a92ddf36b8c68fd6ec8b9fcdd39b7bc61e612662b1ff617a3f41`.
Derive the accepted source set from
`verification-r2/audit-01.json:results[1].bound.preserved`, selecting absolute
paths under this worktree's `scripts/`, `test/`, and the exact existing
`docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`.
Require 28 unique paths. Cross-check complete set equality against producer
source, producer seal sourceAndPreservation, both accepted runtime bindings,
precommit source identity, delivery manifest and actual immutable delta.
The delivery manifest does not supply the accepted set.

For each source path require equal raw SHA-256 and length across accepted,
producer, both runtime bindings, precommit, delivery manifest, current file
and committed Git blob. Compare index and tree modes/blobs, parent entry
and parent absence for additions. Interpret permission 420 as decimal 0644,
full lstat regular-file mode 33188 as 0100644, and Git mode 100644. Recompute
Git object SHA-1 over `blob <raw byte length>\0<raw bytes>`. The current hash
equality also proves the Git stdout UTF-8 round trip did not alter these files.

## Exact Git observations

Each command below is invoked with the two environment variables above, cwd
equal to the worktree. `git` is the program, not a shell alias. Capture
stdout/stderr and process exit separately. All actual outputs and exits are
in audit-evidence.json:git and sources[].tree/parent/index.

```text
git status --short --untracked-files=all --ignore-submodules=all
git branch --show-current
git rev-list --parents -n 1 HEAD
git cat-file commit HEAD
git rev-list --count 4eaa7decab80d24cf37cb3781eff5ffaf9362942..HEAD
git rev-parse HEAD^{tree}
git show -s --format=%B HEAD
git diff-tree --no-commit-id --name-status -r 4eaa7decab80d24cf37cb3781eff5ffaf9362942 HEAD
git diff --ignore-submodules=all --numstat 4eaa7decab80d24cf37cb3781eff5ffaf9362942 HEAD
git diff --ignore-submodules=all --check 4eaa7decab80d24cf37cb3781eff5ffaf9362942 HEAD
git diff --ignore-submodules=all --exit-code
git diff --cached --ignore-submodules=all --exit-code
git ls-files --stage -- <all 28 accepted paths>
git ls-tree HEAD -- <path>
git ls-tree 4eaa7decab80d24cf37cb3781eff5ffaf9362942 -- <path>
git cat-file blob HEAD:<path>
git show-ref
git -c gpg.program=/usr/local/bin/gpg verify-commit HEAD
git rev-parse --abbrev-ref @{upstream}
git rev-parse --absolute-git-dir
```

Recompute the commit ID from `commit <raw byte length>\0<raw commit bytes>`.
Require exactly one parent header and one child commit after the named base;
require exactly one exact coauthor trailer. Full immutable whitespace includes
all three additions. Empty staged/unstaged checks are additional checks,
never substitutes for parent-to-HEAD whitespace. Missing upstream exit128
is retained, not treated as an error in source delivery.

## Original inventory reproduction

Use the complete original `precommit/recipe.txt`, not a new baseline.
Walk with lstat, never follow symlink directories. Sort paths by JS UTF-16
code-unit order. For regular files SHA-256 hashes raw bytes; for symlinks
hash the UTF-8 raw target string. Serialize each object with JSON.stringify
in its specified field order, append one newline per row and nothing else.

Git-mode fields in order are `path,kind,mode,size,sha256,target`; skip ordinary
directories. File mode is 100755 if any executable bit is set, else 100644;
symlink mode is 120000, other is 000000. Permission rows include ordinary
directories and walk root, with `path,kind,perm,size,sha256`, where perm is
`"0o" + (st_mode & 511).toString(8)`. Directory hash is null.

The actual independent row function used in the resident Bun kernel was:

```javascript
const digest = b => new Bun.CryptoHasher("sha256").update(b).digest("hex");
async function inspectEntry(abs, path, permOnly = false) {
  const s = await fs.lstat(abs);
  const kind = s.isFile() ? "file" : s.isSymbolicLink() ? "symlink"
    : s.isDirectory() ? "dir" : "other";
  const target = kind === "symlink" ? await fs.readlink(abs) : null;
  const sha256 = kind === "file"
    ? digest(await Bun.file(abs).arrayBuffer())
    : kind === "symlink" ? digest(Buffer.from(target)) : null;
  return permOnly
    ? { path, kind, perm: "0o" + (s.mode & 511).toString(8),
        size: s.size, sha256 }
    : { path, kind, mode: kind === "file"
          ? ((s.mode & 73) ? "100755" : "100644")
          : kind === "symlink" ? "120000" : "000000",
        size: s.size, sha256, target };
}
```

Here `fs` is `node:fs/promises`. Recursively visit `docs/incidents`, `out`
and `cache_forge`; only descend when kind is dir. Retain all file rows,
including hidden files. Build both Git-mode and permission rows in the same
walk; compare the appropriate rows to each original JSONL. Require original
raw hash equal to its exact reencoding. Match each original path and compare
every specified field, retaining expected/current/changed plus original line
number. Separately enumerate every new path and require its exclusion.
Do not collapse 0400/0444/0600/0644 into a permission pass.

The only allowed original permission-row difference is the enclosing
claimed-sy-integration directory's size160->192 caused by the excluded
commit directory. It is recorded, not normalized away. All new file and
directory rows at the initial audit walk were under commit/. Audit support
and verification add three further files directly there.

Reproduce host rows by taking every producer authority/immutable/
parentPreserved path outside this worktree. Keep `(path,role)` as the key,
not just path. Compare original host rows in exact field order
`path,kind,mode,perm,size,sha256,target,role`. Sort by path, then role.
Check every supplied binding's raw length/hash and permission when present;
an omitted permission has no invented value.

Read every original indexPath as bytes and compare length, normalized mode,
permission and SHA-256 for all 24 foreign indexes. The owned index alone is
allowed to differ; independently check all accepted index modes/blobs and
empty staged/unstaged tracked comparisons. For held09 only its prescribed
foreign-index bytes/ref identity are read, never its candidate source.

Compare every original show-ref object/refname, enumerate new refs and allow
only the owned branch's parent->actual-commit movement. Check all 14 original
aggregate anchors as supplementary evidence, never instead of rows.
Independently lstat/readlink both dependency links and compare target string,
hash, length, mode, permissions and inode.

## Seals and existing runtime proof

For each of the producer's1465 and r2's682 declared evidence members,
compare current raw bytes/length/permissions and require exact directory
membership excluding only its own seal. Independently check all64 producer
source/preservation bindings and all22 additional historical inputs.
For source22, independently walk the actual source and verification trees
without following links, require exact 12/13 memberships including seals,
and compare all declared raw hashes/lengths plus seal hashes.

Bind the delivery to the already executed r2 proof by its admitted report,
complete seal, raw audit and unchanged complete evidence tree. Count literal
`[PASS]` lines and require167/142, matching zero-failed/skipped summary lines.
Check91-pass/zero-fail one-invocation operator output, both stage-success
output and exact empty strict-type logs, fresh CLI completion, and sealed
three genuine before/after checkpoint-resume witnesses. Zero-byte type logs
are not fresh executions here; their existing successful completion is bound
by the actual report, seal and command records.

For both runs decode every original-input-bytes and replacement-original-
input-bytes record. Require canonical base64 round-trip, exact raw length,
SHA-256, terminal-newline flag and current byte identity:68 references over
35 unique paths per run. Do not normalize JSON or restore artifacts.
The raw audit retains all57 artifact/75 repeated runtime/301 compiler-source
bindings, stage-source545/68 sets, constructor/library/22-immutable bindings,
original signatures and canonical wire/resume/economic proof. This audit
binds those existing computations rather than reexecuting the passing runner
or claiming a second independent behavioral implementation.

## Cleanup, ownership and output

Read-only lsof18573 and ps for recorded producer/verifier PIDs return exit1
with empty output. lstat finds neither the exact checkpoint nor its runtime
parent, index.lock, MERGE_HEAD, CHERRY_PICK_HEAD or rebase directories.
No owned runtime, monitor, node, subscription or impersonation is started.

Only audit-evidence.json, this method and verification.md are new owned
writes. They are excluded from the immutable source commit. Report support
raw hashes after writing; do not claim a report or support self-digest.
JSON is directly parsed and raw-hashed; unavailable Biome is a tooling gap,
not a source defect or reason to install dependencies. Final read-only
tracked/index status confirms no source mutation.
