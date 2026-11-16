# Independent commands and exits

Date: 2026-11-12. Cwd for every command:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`.

The shell was `/bin/zsh -lc`, using the existing inherited archive bootstrap.
No resolved credential or environment file was printed or created.
For the commands below, P is
`docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt`.
P is a documented path abbreviation; actual commands used its full expansion.
Bun is `/opt/homebrew/Cellar/bun/1.4.2/bin/bun`.

## Runtime and types

With `PATH=/Users/cyotee/.foundry/bin:$PATH`,
`BUN_RUNTIME_TRANSPILER_CACHE_PATH=0` and `NODE_DISABLE_COMPILE_CACHE=1`:

```sh
bun node_modules/typescript/bin/tsc --noEmit --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --module nodenext --moduleResolution nodenext --target es2022 --skipLibCheck P/source-verification/probe.ts &&
bun P/source-verification/probe.ts
```

Monitor `mon_2GS6DD581CM1G2WB`, session `bash_2`: exit0,
`INDEPENDENT_ER_PASS`. The first command had no diagnostics and succeeded
before the runtime could execute. The runtime writes all raw signed
transactions, canonical receipts, traces and before/after observations into
`runtime-01/`; no producer file is an output.

The runtime resolves the existing `robinhood_mainnet_alchemy` Foundry alias
in memory and uses the existing redacting launch helper. It subscribes to
the exact receipt before submission and closes each subscription in finally.
Only loopback18568 is used.

## Independent raw audit and types

With the same cache isolation:

```sh
bun node_modules/typescript/bin/tsc --noEmit --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --module nodenext --moduleResolution nodenext --target es2022 --skipLibCheck P/source-verification/audit.ts &&
bun P/source-verification/audit.ts
```

Monitor `mon_BQBAQ2F6A4YA3JCK`, session `bash_3`: exit0,
`INDEPENDENT_AUDIT_PASS`. Strict types emitted no diagnostics.
`audit.json` is a create-only generated result. The audit reads final
producer run03/run05 and the fresh independent runtime, and separates those
identities. It does not import the producer audit.

## Independent sealed-helper rebuild

```sh
forge build --use solar P/source/ReceiptCustodyProbe.sol --out P/source-verification/build --cache-path P/source-verification/cache
```

Monitor `mon_ZACJ8WEXR809AWV4`, session `bash_4`: exit0.
Actual output:

```text
Warning: This is a nightly build of Foundry.
Warning: Found unknown `skip` config key in section `fmt` defined in foundry.toml.
Compiling 5 files with Solar 0.8.38
Solar 0.8.38 finished in 23.81ms
Compiler run successful!
```

The first warning is shortened here; no warning was suppressed.
No viaIR, profile, dependency, configuration, source or production artifact
change was made. Independent comparison finds creation object, runtime
object, immutable references and raw metadata exactly equal to the sealed
artifact used by the actual probes. All compiling Forge commands used Solar.

## Final read-only state and cleanup

All Git invocations used `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`.

```sh
git rev-parse HEAD
git branch --show-current
git diff --ignore-submodules=all --exit-code
git diff --cached --ignore-submodules=all --exit-code
ps -p 15934 -o pid=,command=
lsof -nP -iTCP:18568 -sTCP:LISTEN
test ! -e .omo-runtime/dtf-migration-earlier-receipt/checkpoints
```

Read-only session `bash_6` completed exit0, with individual recorded results:

```text
acdbe319f3a20c3af6bea594c62461b6c7988717
work/dtf-migration-phase-18-earlier-receipt
TRACKED_EXIT=0
INDEX_EXIT=0
PID_EXIT=1
PORT_EXIT=1
CHECKPOINT_ABSENT_EXIT=0
```

PID and port commands produced no process/listener output. Their exit1
means absence, not a failed cleanup action. The runtime's finally block
already stopped its node and impersonations and closed providers.
No checkpoint or persistent impersonation was created outside that node.
No operation remains pending.
