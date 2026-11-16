# Independent immutable audit reproduction

Date: 2026-11-12. This is an offline audit, not a test replay.

The only working directory is
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-24-stateful-invariants`.
All owned additions are directly under its existing excluded `commit/`
evidence directory. No source, artifact, cache, dependency, index, ref,
original report, seal, receipt or manifest is edited.

## Admission and accepted source set

Read the complete root commit, original and closure briefs, root twelve-row
acceptance file, actual four phase24 producer/verifier reports, actual
receipt, manifest, original inventory recipe and capture script. Retain the
complete prior phase23 producer, r2 and immutable reports as cumulative
context. Parse the complete manifests, seals, source/runtime bindings,
carrier payloads, baseline inventories and execution/cleanup recipes.

Compute raw SHA-256, length and lstat mode of the actual r2 report. Require
`fd9aaa6531a1a3fddcd5fb7084c533a80588eddeee3ef72c269125d0f0654e60`.
Independently hash each of its twelve exact property-table lines, without
the line-ending newline, against the root acceptance row hashes.

Derive the accepted paths from independent
`verification-r2/source-locators.json` `candidate`, not the delivery list.
Join every path to the lossless producer `candidate-r2-01.json` `files`,
the entire new-file patch, compiler metadata, actual filesystem bytes,
HEAD blob, stage-zero index entry and absent required-parent entry.
Only after deriving that set compare the completed delivery manifest.

For the patch, split at `diff --git`, read each destination and new-file
mode, and reconstruct every complete hunk body by removing its leading
addition marker and restoring the recorded final newline. Require the same
raw source hash and length. This is not a partial-text or filename check.

## Read-only Git

Every Git invocation sets `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`; status and
diff ignore submodules. No `write-tree`, stage, commit, reset, rebase,
fetch, merge or public operation is needed.

Use these exact read-only checks from the worktree:

```text
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git status --short --ignore-submodules=all
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git rev-list --parents -n 1 HEAD
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git rev-list --count 15fd629375edeb361f6a39262795bdc66723ca3a..HEAD
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git branch --show-current
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git diff-tree --no-commit-id --raw -r HEAD
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git diff --ignore-submodules=all --check 15fd629375edeb361f6a39262795bdc66723ca3a HEAD
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git diff --cached --ignore-submodules=all --exit-code
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git diff --ignore-submodules=all --exit-code
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git cat-file commit HEAD
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git rev-parse HEAD^{tree}
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git -c gpg.program=/usr/local/bin/gpg verify-commit HEAD
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git rev-parse --abbrev-ref @{upstream}
GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 git show-ref
```

For each independently derived path, also use `cat-file blob HEAD:<path>`,
`ls-files --stage -- <path>`, `ls-tree <parent> -- <path>` and
`check-attr filter -- <path>`. Independently compute the Git blob SHA-1
over `blob <decimal byte length>\0<raw bytes>`, and commit SHA-1 over the
corresponding `commit` framing. Require one parent, one local increment,
the exact fourteen-path all-addition delta, modes100644, and exactly one
required coauthor trailer. Signature ownertrust remains a separate limit.

## Every original inventory row

Follow `commit/precommit/recipe.txt` and the complete original `capture.py`
field rules, without executing its precommit-only main function or changing
its historical baseline. The original function intentionally refuses to run
after `commit/` exists. Reproduction here evaluates the same walk and field
rules against the actual current roots.

Use lstat, never follow directory symlinks. Hash regular file raw bytes;
for symlinks hash the UTF-8 target string and retain that string. Sort paths
ascending by Unicode code point. For git-mode rows retain, in original key
order, `path,kind,mode,size,sha256,target`. Exclude ordinary directories.
For permission rows include directories and retain
`path,kind,perm,size,sha256`, with `perm=oct(st_mode & 0o777)`.
Serialize compact UTF-8 JSON, no ASCII escaping, one newline per row.

Project each current row onto the exact original field keys. Retain original
line number, complete expected/current fields and every changed field in
`audit-inventories.json`. Independently enumerate membership and additions.
Reproduce the original serialization hash as an additional check, never as
a substitute for the rows. Git mode100644 does not establish historical
read-only permission bits absent from an out/cache baseline.

Apply this to all138 incident entries,147 incident permission rows,
7369 out entries and550 cache entries. Rehash every one of the148 original
preservation rows, including bound external authority/source/host inputs.
Allow only the actual own-index and own-branch movements caused by the
scoped commit, and the enclosing excluded-directory size192->224.

Hash all26 original index files as raw binary bytes; compare all25 foreign
indexes, full modes, permissions and lengths. Re-enumerate common/linked
worktree index membership. Compare every original raw loose/packed ref row,
and the entire64-line `show-ref` baseline, replacing only the owned branch's
required-parent value with the actual commit. Re-enumerate raw ref membership.
Do not replace missing baseline rows with `ls-files`, a clean index or an
aggregate. Held09 access is limited to these prescribed raw Git metadata rows.

Verify the original dependency links' target, raw target hash, length,
permission, full lstat mode and inode. Verify all original inventory anchor
files and source/receipt/manifest inputs themselves in addition to their
declared rows.

## Complete seals and original carriers

For each of `implementation`, `verification`, `implementation-r2` and
`verification-r2`, compare exact directory membership to the seal plus the
seal itself. Independently verify every member's raw SHA-256, length and
mode, and the retained external seal digest. Required total memberships are
22,13,72,17. Rehash all17 original authorities and8 additional source inputs.

Decode every base64 payload of the179 original artifacts,189 stopped r2
candidate artifacts,6 changed artifacts and23 original report/authority
carriers. Compare decoded raw length/hash and recorded mode. Reproduce
all52 pre-r2 original evidence/authority rows and all179 original artifact
baseline rows against their original carriers. Decode the separate fresh
raw r2 index/HEAD/ref payloads; do not upgrade the first verifier's
decoded-string index observation.

Also compare every artifact identity in the first producer and first
independent runtime binding collections. Their path union is179, but five
producer raw hashes differ from the post-first-verifier original carriers.
Search all admitted original/candidate/changed carrier payload identities
for those exact raw hashes and lengths. Three have exact stopped-candidate
carriers; two do not. Record the missing identities explicitly. Equal
creation/runtime-object text fingerprints and metadata fingerprints do not
reconstruct missing raw JSON bytes. Do not synthesize them.

## Current source, artifact and actual deployment binding

Re-derive artifact membership from actual expanded build roots before the
first `--skip`, concrete candidate outputs whose metadata compilation target
names that source, and the original179 artifact paths. Record absent abstract
TestBase outputs as absences and require their source identity in concrete
metadata. This yields189 current artifacts.

For every artifact compare current raw length, SHA-256 and full mode to the
independent binding and exact current carrier. Compare all979 compiler-source
raw bytes, modes and lengths and their metadata-declared Keccak256, including
every candidate source. Conflicting metadata declarations fail.

Compare all189 stopped-candidate carrier bytes to current artifacts. Exactly
six differ. Recompute the full recursive JSON changed-field paths, preserve
old and new raw identities and exact carriers, and require unchanged
creation object, deployed runtime object and compiler metadata. The other
183 match the stopped-candidate carriers exactly. Restore nothing.

Read the complete retained three independent final logs. Count literal PASS
lines and zero failed/skipped summaries; join every invariant and selector
table row by original line number, exact result and call/revert/discard fields.
Require171/147/58 and four512-call tables at32runs/depth16. Retain complete
original commands, expansions, seeds and exit records, but execute none.

Decode all `STATEFUL_SUBJECT` payloads as nine addresses and bytes32, and all
`STATEFUL_RUNTIME` payloads as address/bytes. Compare all13 subjects and1127
runtime records to the sealed independent binding. Rehash actual code.
For each of66 distinct address/code pairs, compare the entire runtime to
its current artifact, substituting only compiler-declared immutable/link
spans. Retain each name, offset, length and value; repeated occurrences of
one declared value must agree. Metadata and every other byte must match.

Decode all four inline `native submitted package arguments` payloads using
the current actual package `deployVault` tuple ABI. Compare the complete
decoded values and actual following captured hook, not a pre-normalized
helper argument. These are actual in-process deployments, not signed mined
constructor receipts or proof every linked helper was separately executed.

## Cleanup and owned evidence

Inspect `lsof -nP -iTCP:18574 -sTCP:LISTEN` and
`ps -ax -o pid=,command=` for actual Forge/Solar/Anvil/artifact-helper
processes. Check own Git-operation markers and index.lock are absent.
Require incoming/current raw own-index equality throughout this audit.
No background process, node, monitor or subscription is started.

Only apply_patch writes the report and new JSON/Markdown support. Directly
parse JSON and hash raw support bytes; unavailable Biome is not an editor
validation pass and does not authorize installation. Final read-only source,
index, ref and exclusion checks establish a stopped handoff without another
runtime gate.
