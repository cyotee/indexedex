# Independent immutable delivery audit method

Date: 2026-11-12. This audit reads already completed local evidence. It does
not start a runtime, execute a suite, replay the CLI or invoke either original
audit runner. Only this file, `audit-evidence.json` and `verification.md` are
owned outputs. Prior evidence is not edited.

## Subject and accepted source derivation

Use worktree `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp`.
Required branch is `work/dtf-migration-phase-21-held-se-lp`; required sole
parent is `3ec0912bafebf9c0aa66770a72f04501e5c11865`.

Read the complete admitted commit and implementation briefs, actual producer
and independent runtime reports, four phase20 source/funding admissions,
ED source contract/producer/admission and cumulative ED producer/runtime/
receipt/immutable reports. Read the original preservation recipe and actual
binding, wire, constructor, lifecycle and raw-check algorithms. Fully parse
manifests, seals, original row inventories and final runtime audit collections.
Recompute the admitted runtime report SHA-256 from raw bytes.

Derive the accepted set from `verification/audit-final.json`
`results[1].bound.preserved`, selecting this worktree's `contracts/`,
`scripts/`, `test/` paths and exact
`docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`.
Require 35 unique paths. Cross-check the complete set and identities against
`results[0].bound.preserved`, `implementation/source-manifest.json:source`,
`commit/precommit/source-identity-before.json:paths`,
`commit/source-manifest.json:paths`, and the immutable raw Git delta.
The delivery manifest is a cross-check, not the source of the accepted set.

For every accepted path, hash raw worktree bytes and `git cat-file blob
HEAD:path` bytes, compare raw lengths, recompute the Git blob ID using
`SHA1("blob " + byteLength + NUL + rawBytes)`, and compare stage0 index and
`ls-tree` entries. Require current permissions 0644, accepted decimal
permissions 420, committed/index mode 100644, exact accepted SHA-256 and
length. Modified parent entries retain 100644; additions have no parent
entry. Compare every declared SHA-256 field in the delivery manifest.

Every Git call uses `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git -C <worktree>`.
Status and diff use `--ignore-submodules=all`. The read-only command
collection in `audit-evidence.json:gitCommands` retains args, exit, stdout
and stderr. Commands include:

```text
status --short --ignore-submodules=all
rev-parse HEAD HEAD^ HEAD^{tree}
branch --show-current
show -s --format=raw HEAD
diff-tree --no-commit-id --raw -r HEAD
diff --ignore-submodules=all --check 3ec0912bafebf9c0aa66770a72f04501e5c11865 HEAD
diff --ignore-submodules=all --exit-code
diff --cached --ignore-submodules=all --exit-code HEAD
rev-list --count HEAD^..HEAD
show-ref
verify-commit HEAD
diff --ignore-submodules=all --shortstat HEAD^ HEAD
```

`ls-files --stage -z`, `ls-tree HEAD -- path`, `ls-tree HEAD^ -- path`,
`cat-file blob HEAD:path` and `cat-file commit HEAD` supply the other raw
identity checks. Recompute the commit ID with the `commit` Git object
framing; require exactly one parent header and one exact required coauthor
trailer. No index-writing command is needed. The full immutable whitespace
check includes every addition; an empty-index whitespace check is not its
replacement.

## Original per-entry preservation

The authoritative original recipe is `precommit/recipe.txt`, not a newly
invented empty or aggregate-only baseline. Each original JSONL line is
retained with its one-based line number, original row, independently observed
current row and exact changed field names under
`audit-evidence.json:originalPreservation.rows`.

For each row, use `lstat` at its original path. Relative paths resolve
against the worktree; absolute host paths remain absolute. Do not follow
symlinks. For files, SHA-256 hashes raw file bytes. For symlinks, hash the
UTF-8 target string and retain that target. For directories/other entries
the digest is null. Raw size is `lstat.st_size`.

Git-mode rows use exactly these keys in this order:
`path, kind, mode, size, sha256, target`. Mode is 120000 for a link,
100755 for an executable regular file, 100644 for a non-executable regular
file, and 000000 otherwise. Permission rows use
`path, kind, perm, size, sha256`, including ordinary directories and the walk
root; `perm` is `"0o" + (st_mode & 0777).toString(8)`.
This separate permission baseline, not normalized Git mode, preserves
sealed read-only permissions.

Host rows use `path, kind, mode, perm, size, sha256, target, role`.
Independently derive host membership from every external `authority`,
`immutable` and `parentPreserved` producer-manifest entry. Retain all 2621
rows, not only the 2615 unique paths: six paths occur in two roles.
Do not collapse rows into a path-keyed map.

To reproduce serialization, retain original row order, create the current
object with the original field order, serialize each with `JSON.stringify`,
join with LF, and append exactly one LF. Original inventory order is POSIX
path sorted by JavaScript UTF-16 code-unit order. Compare every field of
every row before computing a subset digest. Enumerate each original root
without link descent to detect missing/new membership independently.
Evidence additions are allowed only at excluded `commit/` or below.
`out/` and `cache_forge/` have no allowed missing, changed or new entries.

The only expected changed original permission row is the enclosing
`held-se-lp` directory size 128 to 160 from creation of excluded `commit/`.
Its kind, permission and null digest must remain unchanged. Report the
honestly different current permission-subset digest; do not rewrite a row
or chmod a directory to manufacture equality.

For every original `precommit/indexes.json:indexes` entry, hash the actual
raw `indexPath` and compare size, Git mode and permission. There are 23
original entries: 22 foreign and one owned. Only the owned index may change
for this delivery; compare its current stage0 entries to HEAD. Do not use
an empty staged set as a substitute for foreign raw-index baselines.
Access to held09 is limited to its prescribed index hash and ref identity.

Parse every original `show-ref.txt` line into refname/object ID and compare
the complete current map, including missing and new entries. Only the owned
branch may move from required parent to actual commit. Reproduce all 14
non-self `extra.json:aggregates` bindings. Compare dependency-link targets,
target hashes, sizes, permissions and inodes to `extra.json:links`.

## Sealed execution binding without replay

Rebind every producer source, immutable, authority, parent-preserved and
producer/verifier seal-member row by raw length/SHA-256 and available
permission. Enumerate each evidence tree; membership must be exactly its
owned seal entries plus the self-excluded seal.

Parse retained HTTP JSONL, skipping only the explicit closing summary.
Parse each original body string, require request/response ID equality and
strictly increasing IDs, and index actual block/transaction/receipt objects.
For every transaction require block membership and matching block number,
hash, transaction index, sender, recipient, receipt timestamp and every
nested log's transaction/block identity and `removed=false`.

Using the existing installed Ethers package offline, reconstruct type0/2
transactions from all canonical fields and signature scalars. Require
chain4663 and recovered hash/signer equality for every nonsynthetic row.
Classify exactly r=s=1 as Anvil synthetic fixture transactions without a
cryptographic signer claim. Decode each retained raw signing record and
compare its raw payload to its original containing file, hash/signer/chain,
and complete canonical receipt. Check the four separately reconstructed
records without relabeling their bytes original captures. These 155+4
records are subsets of the wire transactions, not additional transactions.

Compare each genuine resume's original transaction, before receipt and after
receipt to actual wire objects across all fields. Preserve the original
SIGKILL/code-null interruption witnesses. Match actual activation
`DiamondFunctionRemoved(bytes4,address)` logs against the complete current
Allocation ABI's 14 selectors.

Recompute each captured code Keccak. Match actual runtime bytes against
current artifact bytes allowing only declared immutable/link spans and
compiler library self-address substitution. Validate spans against current
artifact metadata and named captured library identities; do not accept an
arbitrary mask. Recompute all 301 compiler-source Keccaks and both stage
metadata source sets (545 and 68 entries). Require Solar compiler identity,
no viaIR and actual runtime lengths below 24576.

Decode actual registry deployPkg calldata. Require creation-bytecode equality,
exact creation initcode composition, and derive all 22 package immutable
values from decoded constructor inputs and SELF in declaration order.
Compare them at every declared immutable span. This audit corroborates the
already sealed registry/deployment argument proof, not a new deployment.

Decode signed held-source surrender calldata. Starting separately for each
source at Q=10013/C=2774608, independently calculate partial
floor(C*3337/Q)=924684, remaining Q/C=6676/1849924, then terminal credit
1849924 and final Q=C=0. Compare canonical receipts, same-wallet signatures
and retained per-source accounting. The existing complete specs/forks supply
the accepted funding, rollback, reentry and mixed-inventory execution, not
new executions by this audit.

Decode all 30 original base64 prepared-input captures; require exact original
byte lengths, SHA-256 and terminal-newline states. Independently structurally
compare the three drifted JSON artifacts: only top-level `$.id` may differ,
758 to 534 for Allocation/Migration and 760 to 536 for package. Preserve all
36 repeated producer references and their exact original capture identities.
Verify separately captured fresh current ABI inputs and fresh zero drift.
Do not restore artifacts or call normalized/reconstructed JSON original.

Count actual `[PASS]` lines in sealed spec/fork logs and require final totals
167/139 with zero failures/skips. Check the single operator invocation's
88 pass/0 fail and the CLI completion marker. These are corroboration of
already executed checks, not suite replay.

## Cleanup and output validation

Independently run `lsof -nP -iTCP:18571 -sTCP:LISTEN` and
`ps -p 41253,62726 -o pid=,command=`; exit1 with empty output means absent
in these observations. Check that the exact checkpoint/runtime parent,
index lock and merge/cherry-pick/rebase state are absent. Start or adopt no
runtime, monitor, provider or subscription.

Parse the new JSON support and hash its actual raw bytes. Recheck that only
the three owned excluded files were added and no prior evidence/source/index
was changed. No raw-final-file self-digest is claimed. JSON LSP cannot start
because Biome is unavailable; direct JSON parsing is used, and no
dependency/configuration installation is performed.
