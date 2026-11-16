# Phase21 execution commands

Working directory for every build, test, signer, CLI and audit command:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-21-held-se-lp`.
Shell commands used `/bin/zsh -lc` and the existing login environment;
Foundry commands prepended `/Users/cyotee/.foundry/bin` to PATH.
No dependency, configuration, compiler, provider or credential change occurred.

## Production and complete current test trees

The actual eight artifact-first production roots were:

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryFacet.sol
```

`python3 scripts/forge-artifacts.py build` received all eight explicit roots,
not an interface-only or stale-artifact build (`build-01.log`, exit0).
The same eight roots were passed to each artifact-first test invocation:

```text
python3 scripts/forge-artifacts.py test [the eight roots above] --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test [the eight roots above] --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration
```

The bracketed notation expands to the eight literal paths listed above; it
is documentation, not a suggested shell argument. `specs-01.log` retains
the initial checksum compiler failure. `specs-02.log` is the complete
167-test pass; `forks-01.log` is the complete139-test pinned fork pass.
Compiling commands used Solar. No alternate compiler, viaIR, code-size
override, ignored test, or weakened assertion was used.

## Both concrete operator stages

The generic artifact helper was initially invoked with script paths. Its
success did not refresh the concrete script ABI and was not accepted as
stage validation. The corrective explicit command was:

```sh
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
```

`stages-02.log`: exit0. The resulting Stage01 ABI has the actual
`configureHeldSeLp` tuple and `surrenderHeldSeLp` wrapper. Both stage source
hashes and Stage00 execution artifacts are bound by the raw audit.

## Strict types and the final operator invocation

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 \
  --module ESNext --moduleResolution Bundler --strict \
  --noUncheckedIndexedAccess --exactOptionalPropertyTypes \
  --verbatimModuleSyntax --skipLibCheck --types node \
  scripts/recovery/dtf-migration/*.ts

bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
```

`types-01.log`: exit0. After the stale Stage01 artifact was corrected,
one final invocation across all10 files passed all88 tests with zero
failures (`operator-tests-final-02.log`, exit0). The earlier invocation
with three stale-stage failures is retained as `operator-tests-final.log`.
No test edit was used to make those three failures pass.

The same strict TypeScript flags were applied to all owned evidence `.ts`
files. `probe-types-01.log` has empty compiler output and exit0. The second
compiler output is empty too, but its following shell wrapper exited1.
The final standalone exit gate is `probe-types-final.log`, covering every
owned evidence probe and the final audit entry point. The wrapper mistake
is separately recorded in `failed-attempts.md`.

## Fresh cumulative CLI, raw observer and audit

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy \
  --fork-block 108944663 --port 18571 \
  --checkpoint .omo-runtime/dtf-migration-held-se-lp/checkpoints \
  --evidence docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp/implementation/runtime-01
```

`cli-01.log`: exit0, `bounded-rehearsal-complete`. The actual run is
`runtime-01/rehearsal-1794485231687`. No prior checkpoint or source proof
was substituted for this run.

Before launch, a monitor subscribed to actual loopback18571 RPC readiness,
then ran `bun [owned evidence]/capture.ts`. The observer acknowledged its
`newHeads` subscription before backfill. `rpc.ndjson` retains the actual
HTTP request and response bodies; it ended on node closure with671 observed
blocks, exit0.

```text
bun docs/incidents/2026-09-16-dtf-recovery/migration/held-se-lp/implementation/audit.ts
```

Run from the worktree, this read-only auditor printed `audit-01.json` through
the command's stdout/tee output: exit0, `producer-audit-pass`. It checks
raw compiler/input/runtime/library/constructor data, signatures and receipt
fields, inherited ED/ER accounting, all three new sources and genuine resumes.
No RPC endpoint remains required for this audit.

## Cleanup and Git boundary

`cleanup-final.log` records no listener on18571, no owned Anvil PID41253,
no checkpoint, removal of the empty owned runtime parent, and clean
`git diff --check`. The CLI and HTTP observer exited. Every monitor and
the temporary Git pager also completed. No process was left pending.

Every Git read used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`. Status and diff
ignored submodules, and discovery disabled submodule recursion. No add,
commit, merge, checkout, reset, push or public action occurred.
