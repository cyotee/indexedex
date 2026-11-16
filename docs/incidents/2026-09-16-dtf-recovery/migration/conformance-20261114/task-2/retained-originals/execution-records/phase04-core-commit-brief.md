# Verified bounded core: local delivery

Work only in `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`,
branch `work/dtf-migration-phase-04`, expected parent
`6e27ecaa242c4acca132e3575a160514aad07b11`.
The user authorizes scoped verified local commits. No push, PR, main merge,
integration merge, production operation, source fix or history rewrite.

Read the phase04 core and correction briefs, repository instructions,
git-master, implementation/report.md, correction/report.md and the complete
correction-verification/report.md under the worktree incident migration/core.
Independent AdversarialVerify is confirmed for this bounded core only:
24 independent tests, 83 focused tests, 10,102 combined tests and 246 mined
local QA receipts; source/artifact/historical preservation and cleanup verified.
No original plan checkbox is closed. All legacy, recovery, operator and
release gates remain open.

## Commit producer

Inspect current branch, parent, status, index, full proposed diff and recent
commit convention. Account for every dirty path. Never stage unrelated work,
symlink dependencies, generated out/cache/broadcast files or bulk evidence.
Do not alter any source to prepare the commit.

Allowed source candidates are exactly the original core brief's owned new
Migration contracts/interfaces, seven enumerated common files, two ordinary
V4 DETF extension files, new core TM tests, MigrationCoreLocalQA.s.sol and
core-local-qa-guard.sh; plus the correction brief's capital/Permit2 tests and
external callback fixture. Previously committed snapshot sources/tests stay
unchanged. Intersect these candidates with actual diff/untracked status and
the independent current-source hash manifest. Any unexplained mismatch,
foreign staged change or out-of-scope source blocks the commit, not a reason
to clear the index or broaden the allowlist.

Create `migration/core/commit/source-manifest.json` listing every exact staged
path, source hash, file mode, acceptance evidence and expected parent before
committing. Verify current bytes against independent source bindings.
The integrated parent/children are one coherent buildable increment; do not
split them into unbuildable intermediate commits. Stage exact paths, inspect
the staged full diff, and commit with the established message style and the
git-master coauthor trailer exactly once. Every Git call uses GIT_MASTER=1.

Write `migration/core/commit/receipt.md` with full commit/parent, path count,
message/trailer, staged/current/committed hash equivalence, actual status,
remaining untracked evidence, and unchanged main/integration refs.
Evidence files remain outside the source commit and are retained for delivery.
Do not rerun already bound valid tests merely because Git records the bytes.
If bytes changed, stop and report rather than manufacture acceptance.

## Independent commit verifier

Write only `migration/core/commit/verification.md` and supporting evidence in
that directory. Read the producer manifest/receipt and prior independent
verdict; missing evidence is a failure. Independently compare the actual
commit parent, full path list, modes, commit blobs and current source bytes
against the accepted source hashes. Check the exact trailer, clean scoped
index/tracked state, preserved unrelated files and unchanged main/integration.
Use consistent index serialization when comparing fingerprints.
No commit, source edit, merge or redundant test run.

Each node stops with a decisive receipt/verdict and no pending command or
owned runtime. A mismatch is needs-fix, never full Migration acceptance.
