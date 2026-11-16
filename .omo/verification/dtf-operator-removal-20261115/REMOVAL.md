# DTF operator removal

Date: November 15, 2026.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

The owner requested removal of the custom application and retention of working
migration contracts and simple native Foundry scripts.

## Removed

- All 90 application files under `scripts/recovery/dtf-migration/`, including
  21 TypeScript test files, the CLI, preparation and bundle machinery, journals,
  rehearsal drivers, shell guards and the recently added rehearsal launcher.
- Four Solidity files used exclusively by that application:
  `Phase_08_Stage_00_OperatorEnvironment.s.sol`, `MigrationClaimWitness.sol`,
  `MigrationDelegatedReceiverFixture.sol` and `MigrationIndirectClaimFixture.sol`.
- The external shell invocation in `MigrationSnapshotLocalQA.s.sol`.
- The live `migration/operator-runbook.md`.

The TypeScript tests were removed with the application whose behavior they
tested, as requested. No Solidity contract test was deleted or weakened.

## Retained

- Migration production contracts and native Foundry tests.
- `Phase_08_Stage_01_MigrationExecution.s.sol` with its existing typed native
  deployment, funding, pricing, configuration, issuance, owner purchase,
  activation, surrender and recovery functions.
- `MigrationCoreLocalQA.s.sol`, `MigrationDeploymentGasResumedQA.s.sol` and
  `MigrationSnapshotLocalQA.s.sol`. Snapshot QA retains its native local-chain,
  development-account and Anvil checks.
- Historical reports, transaction receipts, authority bundles and archived source
  snapshots. Their old operator commands are historical, not current entry points.
- All unrelated pre-existing worktree changes.

The live implementation plan now records the owner's scope correction and points
to `docs/incidents/2026-09-16-dtf-recovery/migration/foundry-runbook.md`.

## Verification

Forge: `1.9.1-nightly`, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`.
Solar: `0.3.0-dev`, Solidity-compatible `0.8.38`,
commit `a2b4435466bff1b91459a1bc64b04e5e8144ed9f`.
Commands used that Forge binary and `PATH="$HOME/.foundry/bin:$PATH"`.

1. `forge build --use solar contracts scripts/foundry/recovery/dtf-migration test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration`
   - Exit 0; compiler warnings retained in `build-solar-path.log`.
2. `forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**/*.t.sol'`
   - Exit 0; 236 passed, 0 failed, 0 skipped across 34 suites.
   - Output: `native-spec.log`.
3. `FOUNDRY_PROFILE=fork forge test --use solar --match-path 'test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/**/*.t.sol' -j 1 --compute-units-per-second 10 --rpc-timeout 120`
   - Exit 0; 183 passed, 0 failed, 0 skipped across 30 suites.
   - Output: `native-fork.log`.
4. Search across active contracts, tests, scripts, frontend and CI found no
   executable references to the removed application or its removed Solidity helpers.
5. `git diff --check` passed after the removal and primary documentation update.

The first build attempt failed before compilation because Solar was absent from
the inherited PATH. Its output remains in `build.log`. The corrected run used
the existing installed Solar executable; no compiler fallback or installation
was used.

The retained scripts compiled. They were not broadcast in this removal task.
The full repository test suite and production allocation datasets were not
revalidated. No production contract behavior was edited, no public transactions
were submitted, and no project commit was made. All build/test watchers and the
read-only dependency investigation completed; no QA service was started.
