# Independent bounded operator source commit verification

Date: 2026-11-11.

**Disposition: confirmed for the scoped local source commit and preservation only.**

Commit: `3f577eeca049c1bd70a812d130941c8a38dd4781`.
Parent: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
Tree: `733f7d641f215178b4ae9d77a0a6f7c2089f8401`.
Branch: `work/dtf-migration-phase-08-operator`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator`.

## Independence and method

This is a separate auditor session, not the committing session. Acceptance
was independently derived from `../verification/evidence.json#/finalSources`
and `../verification/baseline.json#/sources`, rather than copied from the
producer's pass flags, `audit.json` or `delivery-proof.json`. The runbook
binding was independently joined from `../verification/evidence.json#/preservedInputs/20`
and `../rehearsal/source-evidence-bindings.json#/runbook`.

Read the complete commit brief, execution brief, fixed CLI contract,
preparation/execution/rehearsal reports, independent runtime verdict and actual
runbook. Read current candidate bytes for identity and endpoint inspection.
This is a committed-source identity/preservation audit, not another semantic
implementation review or new runtime acceptance. No accepted suite was rerun.

`independent-audit.json` records this session's independently computed
per-path Git blobs, modes, sizes, raw SHA-256, current-byte hashes, provenance
locators, input identities, command forms and preservation results. All Git
invocations used `GIT_MASTER=1`; the programmatic equivalent was
`env GIT_MASTER=1 git -C <worktree> ...`.

## Actual commit findings

No delivery-integrity defect was found.

- Actual `diff-tree --no-commit-id --name-only -r -z` returns exactly the
  independently derived 26 accepted paths: 22 TypeScript modules/tests/fixture,
  two new Foundry stages, the existing local QA helper and the runbook.
- For every actual `ls-tree` entry, mode is `100644` and type is blob.
  Actual `cat-file blob` bytes, byte length and SHA-256 equal the accepted
  identity, current worktree bytes and source-manifest identity. All 26 blob
  IDs also equal the producer manifest's expected blobs. Zero mismatches.
- Actual commit has exactly one parent, equal to the expected parent above.
  `rev-list --count <parent>..<commit>` returns 1. The owned branch points
  to this commit.
- The only modification to an existing file is
  `MigrationCoreLocalQA._localInfrastructure` from private to internal.
  The actual parent/commit diff confirms that one-line visibility change.
- No production contracts, shared TestBase, dependency/configuration files,
  historical reports, witness, logs, generated transactions or runtime evidence
  appear in the exact changed-path set. No unrelated path is absorbed.
- Actual committed whitespace check exits 0 with no diagnostics.

Actual subject and trailer:

```text
Add verified bounded Migration operator and resume tooling

Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

Exactly one coauthor trailer is present and matches the required identity.
The subject follows the inspected recent `Add verified ...` convention.
No signature-validity claim is made; parent, tree, message and blob checks do
not depend on one.

The runbook raw SHA-256 is
`bf2523b0012b0d77fd9b50e612bf98c059d7864669d2ffdbd26f7df6e0f924ce`.
The final CLI raw SHA-256 is
`09670f4bd3f18d0d89b040fcd985dde97a9c22d19ac0c050de93c1822571a90a`.
Historical preparation hashes are not substituted for those final identities.
The source endpoint scan found only loopback/example literals; the embedded
execution key is the public Anvil development key, not production material.

## Preservation independently reconstructed

The saved baseline files were first hash-checked against
`preservation-baseline.json`. The actual index, refs and inventory were then
reconstructed with the same serialization, not producer comparison flags.

| Check | Independent observation |
| --- | --- |
| Noncandidate index | All 12,980 records exactly equal the saved initial index after excluding only the 26 candidates |
| Staged differences | Empty |
| Tracked worktree differences | Empty with prescribed `--ignore-submodules=all` |
| Whole-worktree inventory | All 22,187 records byte-identical to saved serialization |
| Inventory SHA-256 | `6bfe81f9e585989af28b24efbcabd4c11ee7536356dbae00479c4e0dc251f714` |
| Protected refs | All 48 refs other than the owned branch unchanged, including main, integration and other work branches |
| Protected-ref SHA-256 | `2970336f915261b7e4b56eba2896cf4fb8b894a1c5991a4b6a7861ef237b3cba` |
| Separately rehashed accepted bindings | 577 entries; zero hash/size mismatches |

The 577 entries comprise 21 preserved inputs, 276 predecessor final-run
files, 276 independent-run files and four artifact envelopes. The inventory
contains 14,195 content-hashed regular files, 7,838 stat-only regular files
and 154 literal symlinks. Symlink targets were not traversed. Inventory excludes
only the administrative `.git` entry and this `operator/commit/` directory.
Stat-only roots remain `.next`, `broadcast`, `cache`, `cache_forge` and
`out`. No claim is made that every cache byte was hashed.

Nanosecond mtimes were serialized from bigint values as exact decimal integers.
An initial JavaScript Number serialization rounded these values and produced a
different inventory hash; using the original exact-integer serialization
resolved it with exact byte equality, not a relaxed comparison.

Prior runtime reports, witness, failed/successful run evidence, synthetic
inputs, dependency links and unrelated files remain unchanged and uncommitted.
Artifact-envelope SHA-256 is not an executable Keccak identity or deployed
immutable-populated runtime identity. Those identities and the 226 compiler-source
comparisons remain the preserved prior independent evidence, not newly rerun
runtime or compiler claims from this audit.

The previous producer-authored self-check at this requested report path is
preserved verbatim in `producer-verification-before.md`, SHA-256
`1d9945ee23bd054d1ee126689d36abab2ff00f9065adb7ce41c34550e74c951d`.
Only this report and its new supporting evidence were written by this auditor.
The producer's receipt, manifest, baselines and other delivery evidence were
not edited. All audit output remains uncommitted.

## Accepted runtime verdict and limits retained

The complete preserved `../verification/report.md` accepts only the bounded
local operator/resume contract: 264 unique successful receipts, actual
mined-before-checkpoint donation and issuance interruptions, fresh-process
resume without duplicate funding/bonds, a meaningful two-row remaining issuance
permutation, deterministic real snapshot preparation, selected NFT/recovery
paths, strict TypeScript checking and 50 passing tests. These are prior
independent results, not new executions by this commit auditor.

Stage 01 was source-inspected, not separately invoked. The real fixture has no
original with both ETH and DTF components nonzero; that case belongs to the
synthetic wire fixture. Recovery precedes activation in that run; previous
postactivation coverage remains historical. Reorgs, pending-transaction
ambiguity, lost send responses, concurrent dead-writer races and filesystem-sync
crash windows are not additional proven runtime coverage.

**Deployment feasibility remains open:** the genuine local parent deployment
used **42,985,843 gas**, above the historical **32,000,000** transaction limit.
The permissive local fork does not prove public deployability. Phase09 diagnosis
remains separate. Selected recovery bounds remain eight weighted claims or one
other stage, not universal gas guarantees.

Full original task 9, all original category gates and E2 ancestry, the ten
blocked categories, earlier liquidation and missing-source qualifications,
operational funding/beneficiary provenance, full integration/invariants and
release remain open. The blocked categories remain weighted/earlier liquid,
weighted/earlier receipts, weighted SY, TokenStaking, claim-vault rights,
underlying SE shares, fungible LP and earlier liquidation, with E1/E2 or
SB-E1/E2/E3/E4 gates. Earlier masked-authorization qualifications remain.
Synthetic inputs are not approved allocations. Local commit delivery closes
none of these gates and authorizes no public operation.

## Cleanup and audit execution notes

No runtime was started. Fresh read-only checks found no listener on port 18560,
prior owned PID 67831 absent and no `.omo-runtime/dtf-migration-operator`
checkpoint parent. No pending owned runtime exists. No source/test edit, commit,
push, merge, dependency install or public operation occurred.

Ordinary Git status initially rejected the prescribed Crane symlink; the
read-only retry used `--ignore-submodules=all`. Two audit-cell syntax/helper
issues and a patch argument-name error were corrected without source changes.
JSON is parsed directly; JSON LSP is unavailable because Biome is not installed.
No accepted test/build/runtime suite was rerun or counted again.

**Final verdict: confirmed for this scoped local source commit only.**
