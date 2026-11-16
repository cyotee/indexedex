# Independently completed commands

Working directory:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-23-claimed-sy-integration`.
Commands used `/bin/zsh -lc`, correct single-quoted arguments,
`PATH=/Users/cyotee/.foundry/bin:$PATH`, and `set -o pipefail` for pipelines.
Output was retained with tee. Monitors delivered completion with exit 0.

## Artifact-first checks

```sh
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
```

`specs.log` and `forks.log` contain the exact expanded artifact-first Solar
build/test commands. The worktree already had warm artifacts; no cache was
deleted or reseeded.

## Types and the one operator-test invocation

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node \
  scripts/recovery/dtf-migration/*.ts \
  docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration/implementation/probe/*.ts \
  docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration/implementation/capture.ts
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
```

Evidence: `types.log` and `operator-tests.log`.

## Fresh cumulative runtime

Let E be this verification-r2 directory's absolute path.

```sh
bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18573 \
  --checkpoint .omo-runtime/dtf-migration-claimed-sy/checkpoints \
  --evidence "$E/runtime-01"
```

Before starting the CLI, a monitor waited for the owned listener and launched
the unchanged read-only `../implementation/capture.ts`, teeing its original
HTTP body observations to `fresh-wire.ndjson`. The separate owned
`observe.ts` subscribed and backfilled historical source/surrender books
while the node was live, writing `independent-books.ndjson`. Both observers
exited when the CLI stopped Anvil. The readiness loop ran inside the monitor,
not inside an eval wait or a test.

## Stopped audit

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node \
  "$E"/*.ts
bun "$E/audit.ts" "$E/runtime-01/rehearsal-1794498106137"
```

Evidence: empty `probe-types-01.log`, `audit-01.json` and empty
`audit-01.stderr.log`. The audit is read-only and makes no RPC request.
It reexecutes the explicitly inspected producer binding/receipt/economic/
constructor algorithms and adds owned canonical field checks and independent
actual historical books. It does not adopt a producer PASS flag.

## Cleanup

`cleanup.log` records HEAD/branch, whitespace/index checks, absent listener
and PID 13650, and absent exact checkpoint/runtime parent. Every Git call
used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`; status/diff ignored submodules.
The empty parent was removed with `rmdir`, not recursive cleanup.
