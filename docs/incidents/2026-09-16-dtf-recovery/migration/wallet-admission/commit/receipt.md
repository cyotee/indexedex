# Verified bounded original-wallet admission local source delivery

Date: 2026-11-11. Status: **complete for local source delivery only**.

## Exact local commit

- Commit: `2c2b3370ded30cae1662329025d4fb58f7197330`
- Subject: `Add verified bounded original-wallet Migration admission`
- Parent: `3f577eeca049c1bd70a812d130941c8a38dd4781`
- Branch: `work/dtf-migration-phase-12-wallet-admission`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-12-wallet-admission`
- Exactly **24 source/test/runbook paths**, 574 insertions and 108 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Exactly one commit after the required parent. No push, PR, merge, public action or source fix.
- The source commit deliberately excludes this manifest/receipt and all other evidence/generated artifacts. Evidence remains local and uncommitted.

## Source provenance and exceptions

`source-manifest.json` binds every candidate path, mode, accepted historical SHA-256, current SHA-256, Git blob, parent blob and provenance. Candidate set independently derived from the verifier's 101-source intake and actual parent/index/worktree changes: 23 runtime-audited changed/new paths plus the help-only `cli.ts` correction. Current and committed bytes/modes match for all 24. Historical runtime evidence records bytes, not file modes; modes are separately bound from unchanged parent/index entries or new regular-file intake.

Only these two current hashes differ from the independent runtime-audited sources:

1. `scripts/recovery/dtf-migration/cli.ts`: accepted `09670f4bd3f18d0d89b040fcd985dde97a9c22d19ac0c050de93c1822571a90a`; current `f7ef8752b523fbcb4420b0cc0a95720e3a0037e7eee2993a8b54c4d295678bab`. One literal within the exported help template changed port 18560 to 18562. Reversing that literal reconstructs the exact accepted hash; no executable logic changed. Actual `bun scripts/recovery/dtf-migration/cli.ts --help` ran here on Bun 1.4.2, exit 0, and agrees with the fixed port in `rehearse.ts`. Output: `cli-help.txt`.
2. `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`: accepted `f9f910e0a7258caba782f8d36e9315bdbf158f3e16d33692b16f493cb8bc2a88`; current `8a528053067d253f438c63ee201d3caa56638854a6fa255703cb525e3c0c4e81`. Wording distinguishes current 42,985,865-gas deployment from 42,985,843 baseline and points to current wallet-admission reports/receipts while retaining historical pointers. Four exact reverse replacements reconstruct the accepted hash. The implementation and independent verification reports were read completely; both substantiate the corrected figures/locators.

These are explicitly reviewed **post-runtime wording exceptions**, not falsely matching runtime hashes. Exact current/accepted replacements are recorded in the manifest. No new prose-pinning tests or full-suite rerun was performed. No runtime obligation remains pending.

## Verification performed here

- Read complete brief, required authority section 1.3, implementation and independent verification reports, and repository rules. Verified branch/parent, empty incoming staged set, recent commit convention and all current source bindings. No upstream is configured; no fetch or push was attempted.
- Read the entire tracked candidate diff and both new files. URL/signing-material inspection found only loopback templates and `https://example.invalid`, no resolved secret endpoints, hardcoded signing keys or private-key markers.
- Staged exact individual paths only. Complete existing-file staged diffs equal the already reviewed diffs byte-for-byte; added-file diffs reconstruct the fully read source bytes. Every staged mode/blob/hash matched the manifest. Full evidence: `staged.diff`, `staged-inspection.json`.
- Checked actual `HEAD^`, one-child count, full commit message/trailer, exact `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current SHA-256. All 24 match. Final staged and unstaged tracked diffs are empty; `git diff --check` and staged whitespace checks exit 0.
- JSON artifacts parse and match their constructed records. Biome LSP is unavailable because its existing executable is absent; no dependency was installed. This is not a clean-LSP claim.
- Prior independent runtime evidence was corroborated from its reports, bound source/artifact identities and actual log summaries: 97 specs, 47 pinned forks, 54 operator tests, strict TypeScript, real CLI admission, mined-before-checkpoint resumes and cleanup. Those are the independent verifier's runs, not new runs by this commit lane. No unchanged transaction suite was rerun.

## Preservation and cleanup

`preservation-baseline.json` and `commit-verification.json` record the before/after checks.

- All **614 prior migration evidence entries** retain identical path/mode/size/mtime/SHA-256 inventories; no historical report, binding, witness, log, journal or broadcast was rewritten.
- All **7,302 `out/` entries** and **512 `cache_forge/` entries** retain identical path/mode/size/mtime metadata inventories. Five final independent artifact SHA-256 values also match. Cache bytes were not exhaustively rehashed; no build, deletion or cache write was performed.
- `lib/crane` and `node_modules` symlink targets, inode identities and modes are unchanged. No configuration/dependency/link changes.
- All **50 refs other than the authorized source branch** remain identical, including main, origin/main, prior phase branches, held phase09 and stash. Their exact names/hashes are in the manifest and verification record. No held phase09 candidate was read/imported/changed/tested.
- All noncandidate index entries and prior noncandidate untracked paths are preserved. The incoming staged set was empty; the final staged set is empty. Only local evidence remains untracked under `docs/incidents/2026-09-16-dtf-recovery/migration/wallet-admission/`.
- Current port 18562 has no listener (`lsof` exit 1 with empty output); producer PID 71170 and verifier PID 75636 are absent (`ps` exit 1 with empty output); checkpoint/runtime parent is absent. This lane started no node, impersonation, transaction suite, child or monitor. Commit/help processes completed. **No pending runtime.**

## Retained scope limits

Only bounded H1/H2/H7 original-wallet NFT admission and operator propagation are delivered. Full categories/task 9 remain open. Current and baseline parent deployments both exceed the historical 32,000,000 gas target limit; no gas-feasibility acceptance, operational award approval, full-source audit or public readiness is claimed.

## Exact committed path list

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol`
- `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`
- `scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol`
- `scripts/recovery/dtf-migration/cli.ts`
- `scripts/recovery/dtf-migration/execution-state.ts`
- `scripts/recovery/dtf-migration/payloads.ts`
- `scripts/recovery/dtf-migration/preparation.fixture.ts`
- `scripts/recovery/dtf-migration/preparation.test.ts`
- `scripts/recovery/dtf-migration/rehearsal-admission.ts`
- `scripts/recovery/dtf-migration/rehearsal-chain.ts`
- `scripts/recovery/dtf-migration/rehearsal-data.ts`
- `scripts/recovery/dtf-migration/rehearsal-recovery.ts`
- `scripts/recovery/dtf-migration/rehearse.ts`
- `scripts/recovery/dtf-migration/schema.ts`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftLifecycle.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOriginalWallet.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryGas.t.sol`
- `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeighted.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationGenesisCapital.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol`
