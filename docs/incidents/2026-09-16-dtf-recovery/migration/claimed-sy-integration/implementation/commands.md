# Final candidate commands

Run from `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-23-claimed-sy-integration`.
All shell pipelines used `set -o pipefail`. These commands actually completed,
not proposed follow-up work. Commands that run Foundry used
`PATH=/Users/cyotee/.foundry/bin:$PATH`.

## Artifact-first currentMigration checks

The exact expanded `forge build --use solar ...` and subsequent
`forge test --use solar ...` command lines are retained verbatim in
`commands-expanded.json`, extracted from `specs.log` and `forks-01.log`.
The specifications use the default profile; forks use `FOUNDRY_PROFILE=fork`.
The artifact-first wrapper resolved 122 build roots / 880 source imports /
116 runtime artifact IDs for specs, and 117 / 879 / 109 for forks.
The current migration test tree is under
`test/foundry/{spec,fork}/vaults/detf/protocols/dexes/uniswap/v4/migration/`.

The two operator stages were compiled together:

```sh
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
```

Each artifact-first wrapper builds its production roots using Solar before
testing. Evidence: `specs.log`, `forks-01.log`, `stages.log`. The initial malformed
shell-wrapper attempt is described in `failed-attempts.md` and retained in
`build.log`; it is not counted as a passing standalone build.

## Final operator version

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node \
  scripts/recovery/dtf-migration/*.ts \
  docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration/implementation/probe/*.ts \
  docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration/implementation/capture.ts
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
```

Evidence: `types-final-02.log`, `operator-tests-final-02.log`. The earlier
complete 91-test invocation is retained under `operator-tests-final.log`;
the final invocation was repeated because the reviewed-record downgrade
behavior changed. No test was weakened or skipped.

## Final fresh runtime

Let `E` be the absolute path of this `implementation` directory.

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18573 \
  --checkpoint .omo-runtime/dtf-migration-claimed-sy/checkpoints \
  --evidence "$E/runtime-03"
```

Before starting that command, an owned monitor subscribed to the port becoming
available and started `bun "$E/capture.ts"`. It retained original local wire
bodies in `rpc-03.ndjson`. The observer exited when the owned node exited.
Evidence: `cli-03.log` and
`runtime-03/rehearsal-1794496225193/`. The same unchanged observer and CLI
commands for attempts 01 and 02 remain represented by their separate logs and
runtime directories; they are not substituted for the final version.

## Stopped audit

```sh
bun "$E/probe/audit.ts" \
  "$E/runtime-03/rehearsal-1794496225193" "$E/rpc-03.ndjson"
```

Evidence: `audit-final.json` and empty `audit-final.stderr.log`. Its probe
typecheck also passed in `probe-types-final.log`. The audit makes no RPC
request or state-changing operation.

The same `probe/downgrade-repro.ts` ran against retained `runtime-02` input
before and after the correction. `downgrade-before.json` records acceptance;
`downgrade-after.json` records `PROVENANCE` rejection. Neither invocation
signed or broadcast anything.

## Cleanup and Git

`cleanup-final-02.log` records no listener on 18573, no owned Anvil PID
(3428, 5533, 9068), absent live checkpoint and owned runtime parent, audited
HEAD and branch, passing read-only whitespace/index checks and complete
changed-path inventory. Every Git command used
`GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0` and ignored submodules where applicable.
No commit, staging, branch movement, provider change or push was performed.
