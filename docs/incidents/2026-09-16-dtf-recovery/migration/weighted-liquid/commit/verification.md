# Independent phase13 local source-delivery audit

Date: 2026-11-11.

**Verdict: confirmed for bounded local source delivery only.** No committed,
current, or accepted source mismatch was found. This verdict does not accept
all Migration categories, full-plan completion, target gas, or public execution.

## Actual delivery and independently derived source identity

The actual receipt exists at `commit/receipt.md`, raw SHA-256
`e3bd8ed4e32cc287fcc0bf74dd9b7045e5efa1cd92f5517da0c5bfd4e4d73d0e`.
The actual commit is
`75d513cb8b36e53f14c8aa3a352f21703ad91ba1`, subject
`Add verified bounded Stage2 surrender and owner-first bond`, on branch
`work/dtf-migration-phase-13-weighted-liquid`, in the prescribed worktree.
Its sole parent is `2c2b3370ded30cae1662329025d4fb58f7197330`.
There is exactly one commit between that parent and HEAD.

The complete actual independent runtime report was read and its raw SHA-256
was independently recomputed as
`6f2b72c1a50919171790459be6699ce26fefdb4bdc09a2f577f9c01ba3fc365d`.
Its sealed `bindings.json` hashes to
`7225cbf454f4d93821186e91f0b2ffd0ad4f1faf272381e6dd5ab9ebefc24def`.
The complete commit brief, producer report, receipt, verifier admission,
bindings and reconciliation evidence, and all three complete bound authority
snapshots were read. The local authority snapshots reproduce the admitted
main plan r5, PRD r22, and owner-first-bond directive hashes; no stale
worktree requirements were substituted and no additional main-tree inspection
was needed.

The accepted path set was independently derived from the runtime verifier's
54 `sourceFiles` records, not from the delivery manifest's pass flags. For
every path, the verifier's `finalSha256` was compared with:

- The actual sealed producer source snapshot.
- The current worktree file's raw SHA-256.
- The actual committed `HEAD:<path>` blob's SHA-256.
- The Git blob ID independently recomputed from the committed content.

All 54 agree. The actual commit changes exactly those paths: 46 modifications
and eight additions, with no extra or missing path. All modes are `100644`.
For the 46 existing files the parent mode is preserved; the eight additions
are actual regular files without execute bits. Historical runtime bindings
seal bytes, not modes: mode provenance comes from the parent tree and actual
file metadata, rather than an invented runtime mode attestation.

`independent-verification.json` records the independently derived exact path,
mode, accepted/current/snapshot/committed SHA-256, parent blob, and committed
blob set. Its raw SHA-256 is
`03d8fa16267050f8183df721cc0a5943518dead59dd6c19a9e08de5497e56801`.
Only after deriving that set was it compared with `source-manifest.json`;
the manifest agrees on every path, mode, accepted hash and parent/current blob.
The producer's corresponding source hashes also agree, but were not treated
as independent acceptance.

## Commit, complete diff, and exclusions

Direct `git show`, `git diff-tree`, `git cat-file`, `git ls-tree`, and
`git ls-files --stage` observations establish the parent, content and modes.
The commit contains exactly one required trailer:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

The complete actual parent-to-commit diff is 235,159 bytes, with 2,093
insertions and 140 deletions across 54 paths. Its SHA-256 is
`19a77e47a7dbaa48f66ba725a83de8363df56a63500008c57cb54085d05dfb23`,
identical to the complete saved `staged.diff`. The complete
`candidate-reviewed.diff` has a different raw hash because its file-block
order differs; its full diff-block multiset is identical. This is an ordering
reconciliation, not acceptance of changed source or different hunks.

Every changed path is a Migration-specific production/TestBase/interface,
neighboring spec/fork, existing recovery operator/Foundry stage, or the
operator runbook. No evidence, snapshot, probe, journal, broadcast, generated
artifact, cache, dependency link, configuration, root control file,
requirements archive, or unrelated source is in this commit.

All complete committed candidate blobs and the complete diff were scanned
for endpoint and signing-material exclusions. The only URL occurrences are
loopback templates in `preparation.fixture.ts:89` and
`rehearsal-chain.ts:32`, and `https://example.invalid` in
`preparation.test.ts:213`. The Anvil mnemonic reference at
`rehearsal-data.ts:16` contains no mnemonic words or private key.
`rehearse.ts:101` deletes `PRIVATE_KEY` from the forge environment.
No embedded signing material, resolved secret endpoint, or secret literal
assignment was found. This is static inspection, not a claim to prove the
absence of every possible encoded secret.

All Git invocations used `GIT_MASTER=1`; status/diff invocations used
`--ignore-submodules=all`. The commit whitespace check exited 0. The branch
has no configured upstream; its upstream lookup exited 128 with the explicit
`no upstream configured` message. No fetch, push, merge, PR, or new commit
was attempted by this audit.

## Final runtime acceptance and the 42 regenerated artifacts

The actual final verifier reconciliation, raw SHA-256
`9d3a07f33c93b53db945b964637e5dc0f5c3fc9c532e0f8e44ec1a4b66184b3a`,
was read and checked through its sealed evidence chain.
All 59 final artifact JSON hashes were independently recomputed and match
their accepted final hashes. Recomputing the old/final comparison yields
exactly **42 different raw JSON hashes and 17 unchanged hashes**. The old
admission hashes remain historical facts; they are not relabeled as current.
The older Stage2 reconciliation of 13 regenerated artifacts remains separate.

All **684 current compiled-input keccak256 values** were independently
recomputed against the final reconciliation's expected values, with zero
mismatches. All 43 recorded test compilation-target source checks agree.
These are new hash comparisons, not copies of the verifier's match flags.

The sealed runtime verifier, not this source-delivery audit, performed the
ten artifact-to-runtime comparisons and 31 captured-runtime comparisons.
Its reconciliation permits only compiler-declared immutable/library spans
and retains their observed values. The changed paid-bond facet and bond-child
facet matched with no masked spans. This audit binds unchanged committed
source and current accepted artifacts back to that final runtime acceptance;
it does not claim a new runtime replay or byte-identical old/new artifact JSON.

The final independent report admits 109 specs, 52 pinned forks, 57 operator
tests, both operator-stage builds, strict TypeScript, the real fixed18563 CLI,
three critical traces and three actual mined-before-checkpoint resumes.
Those are the admitted independent runtime results, not tests rerun here.
No unchanged transaction suite, build, or rehearsal was rerun.

## Independent preservation findings

- All **2,103 historical weighted-liquid evidence entries** in the precommit
  inventory were independently rehashed. Paths, modes, sizes, raw hashes and
  exact integer nanosecond mtimes agree, with no missing or changed entry.
  The baseline inventory digest was also reproduced using its JSON encoding:
  `f11b24d2a117604fbc2a69b702467ae5ed5cb4f29a372d5634abca1444197adb`.
  Historical failures, reports, snapshots, receipts and artifact qualifications
  remain preserved.
- All **341 verifier-owned evidence bindings**, **57 admission snapshots**,
  **15 historical seal entries**, and **eight final verifier seal entries**
  were independently checked with no mismatch. The 465 local non-artifact
  admission entries also match; the remaining three non-artifact authority
  identities were checked against their exact bound local snapshots. These
  reproduce the verifier's 468 non-artifact identities without leaving the
  authorized worktree.
- All seven pre-existing `commit/` evidence files are retained with their
  independently captured hashes in `independent-verification.json`; none was
  rewritten by this audit.
- The current index has **13,016 stage-zero entries**, exactly matching HEAD
  in path, mode and blob. Every noncandidate parent-tree entry is unchanged.
  Staged and unstaged tracked diffs are empty. The delivery's recorded incoming
  index was empty and matched its parent tree; that historical incoming-state
  record is distinguished from this audit's direct current-index observation.
  The pre-audit status enumerated 1,784 untracked, nonignored files, all under
  weighted-liquid evidence, with none elsewhere.
- Every ref other than the authorized phase13 branch matches the precommit
  baseline. This includes main and origin/main at
  `90ff0307a7a8e084aa073e02eff125e9c7973933`, phase12 at the expected parent,
  the protected held phase09 ref at
  `421072a7630a0d3d47a6f36e1062d9eae98c93e2`, and stash at
  `7321b70c984423699475cfb45907b6dd70bb8ef4`. Only the held ref identity was
  compared; no held phase09 candidate was inspected, imported, or replayed.
- `lib/crane` and `node_modules` retain their original symlink targets,
  inode identities and modes. No dependency/configuration change was made.

**Artifact-wide metadata qualification:** current file counts agree with the
delivery baseline: 7,310 under `out/` and 588 under `cache_forge/`. The baseline
retains only aggregate metadata hashes for these directories, not per-entry
artifact metadata inventories or the serialization recipe. Those aggregate
hashes were not independently reproduced here, so the producer's complete
precommit/postcommit artifact-metadata assertion is not promoted to an
independent finding. This does not qualify the exact 59 accepted artifact
hash checks above or the committed source equivalence. Generated directories
are excluded from the commit and this audit performed no artifact write.

## Cleanup and retained limits

Live external probes found no listener on port18563 (`lsof` exit 1, empty
output) and no verifier Anvil PID 54333 (`ps` exit 1, empty output).
The fixed checkpoint is absent (`test` exit 0). This audit started no node,
impersonation, child, monitor, transaction suite, or background operation.
All inspection commands finished; **no owned operation remains pending**.

Only this verification report and its supporting
`commit/independent-verification.json` were authored. JSON LSP diagnostics
could not run because the configured Biome executable is absent; no install
or configuration change was made. The supporting evidence was constructed
from valid serialized JSON, and its raw identity is recorded above.

Other legacy source categories, full hermetic/full-plan completion,
operational original-wallet/canonical-origin/Q0/ETH-and-DTF input records,
and the earlier sale-and-hold versus liquidation limitation remain open.
Fixture amounts are synthetic. The accepted local parent used **43,263,865
gas**, exceeding the retained historical **32,000,000** transaction limit.
This report neither accepts target gas nor authorizes public deployment,
funding, transactions, a merge, or resumption of the held gas lane.

**Final source-delivery disposition: confirmed, with the explicit
artifact-wide metadata qualification above and no source-delivery fix
requested.**
