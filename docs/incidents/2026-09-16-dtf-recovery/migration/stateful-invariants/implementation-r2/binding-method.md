# Binding and preservation method

## Raw preservation

Before any r2 build, read raw bytes with `Bun.file(path).arrayBuffer()`,
hash with SHA-256, and retain `stat.mode` and byte length. Base64 carriers
preserve those exact bytes, including original JSON serialization and final
newlines. This is not a decoded-string comparison.

`preservation-baseline.json` records all 35 original implementation/verification
members, 17 authority documents, 179 original bound artifacts and the current
raw owned index/HEAD/branch ref. `original-reports-and-authorities.json` retains
complete original reports, source manifest/patch, seals and authority bytes.
`original-artifacts-01.json` through `-15.json` retain every artifact in the
union of the original producer and verifier binding collections. Every original
artifact matched its prior binding at capture. Original logs remain untouched
at their original paths and are individually rechecked at closure.

The current binary index capture is a new baseline only. It does not turn the
first verifier's explicitly qualified decoded-string digest into historical
raw-byte proof. No original baseline or report was rewritten.

## Candidate and compiled sources

`candidate-r2-01.json` records all 14 complete source byte strings and their
prior first-pass SHA-256, where one existed. Its complete new-file patch is
against unchanged audited HEAD, because these files remain untracked. Relative
to the first pass, seven owned files are extended, six are added and the
capture library is unchanged.

Derive final artifact paths from the union of source roots before `--skip` in
all three actual `forge build --use solar` command lines, the first-pass
binding artifact paths, and concrete outputs of all candidate source files.
This yields 189 artifacts. The two abstract TestBases do not have standalone
artifact directories; their full source hashes are present in concrete test
metadata. Missing abstract output was initially an audit-script ENOENT, not
a product build failure or missing deployable artifact.

For every artifact metadata source, compare declared Keccak-256 with current
raw source bytes. All 979 distinct declarations match, including every candidate
file. No conflicting declarations exist. `candidate-artifacts-01.json` through
`-16.json` retain exact final artifact bytes, hashes, lengths and modes.

In `source-artifact-deployment.json`, top-level artifact `sha256` hashes the
raw JSON file. `creationSha256` and `runtimeObjectSha256` hash the literal UTF-8
artifact object strings, including any unresolved link placeholders: they are
object-text fingerprints, not raw linked-bytecode hashes. Actual deployed
`keccak256` values hash the decoded runtime bytes. Compiler metadata, link
references and immutable references are retained without normalization.

## Actual deployments

Decode every `STATEFUL_SUBJECT` and `STATEFUL_RUNTIME` record from the final
spec/fork logs. There are 13 subject records, 1127 repeated runtime records
and 66 unique address/runtime pairs. All unique pairs match a current artifact
template after substitution only at compiler-declared link/immutable spans.
Every repeated span for one declared value agrees. All other bytes, including
metadata, must match. No arbitrary masking, metadata stripping or address-only
matching is allowed.

Four logged native submitted package tuples decode through the current actual
`deployVault` ABI. Their hook fields match the corresponding captured actual
subject. Handler assertions verify the supplied initial owner against the
actual proxy owner. These are in-process Foundry deployments, not independent
signed constructor transactions or mined receipt archives. Runtime substitutions
are recorded; not every linked library runtime was separately captured.

The old artifacts are never reconstructed from new compiler output. Final
artifact carriers preserve this candidate independently of later verifier
compilation. Warm cache/host dependency identity is retained; no cold,
portable or archive-equivalent reconstruction claim follows.

## Test evidence

Final command lines are recorded literally, with Solar artifact-first builds
before test execution. Runs=32, depth=16 and fail-on-revert are explicit.
Native seed is `0x24c1`, pinned fork seed `0x24c2`, ordinary seed `0x24c3`.
All four invariant selector tables sum to 512 calls each, with zero unexpected
reverts or discards. Raw tables and per-test named metrics are extracted with
line locators into `execution-results.json`.

Selected-selector tables aggregate the generated calls. Printed handler
counters include setup/prelude and describe only retained sequences or named
deterministic tests, not all-run success totals. Empty-domain actions execute
another real prerequisite or an exact rejection; those are not nominal-action
successes. Zero-valued claims are not positive payouts. Mandatory successful
preludes and explicit cliff/terminal sequences supply nonprobabilistic witnesses.
