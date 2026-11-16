# Portable operator command record

All commands ran from the phase26 worktree at
`137fa0c8749165087c7d1d0156788f58a1dbf1b8`. `E` below denotes this
`implementation/` directory, not an external evidence location.
Pipelines used `set -o pipefail`. Monitor completion supplies the actual exit
status; retained log files contain original command output.

## Preservation and explicitly supplied authorities

`bun "$E/preserve.ts"` completed before any source edit or compilation.
It captured 13,989 per-entry current identities with lossless raw copies.
`preservation-baseline.json` records absolute originals, copy identities,
raw lengths and full original modes. It is not all-history preservation.

`bun "$E/authorities.ts" /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase23-portability-inputs.json`
exported the audited complete 22-role inventory to two owned roots. The
generator is task evidence, not a hardcoded operator input or discovery
fallback. `authority-template.json` is a newly generated explicit template.
Its referenced source captures retain their original bytes and qualifications.

`sandbox-exec -f "$E/no-original-inputs.sb" bun "$E/check-access.ts"`
proved all 22 old inputs and authority-location-a unreadable with EPERM/EACCES
while authority-location-b remained readable. `physical-access.log` retains
the actual result. The same profile governs the whole rehearsal process tree.

## Strict types and operator tests

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node \
  scripts/recovery/dtf-migration/*.ts "$E"/*.ts "$E"/probe/*.ts
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun "$E/freeze.ts"
```

The initial candidate passed strict types in `types-final-r2.log` and 107 tests
in one invocation in `operator-tests-final.log`. The actual first runtime then
exposed the normalized replacement proof-pointer defect. After that concrete
source repair, `types-corrected.log` and the single final-source invocation in
`operator-tests-corrected.log` passed: 108 tests across 11 files, zero failures.
The earlier focused bundle invocation passed 16 tests separately.
`source-manifest.json` retains the first stopped candidate; the corrected
second candidate is frozen separately in `source-manifest-final.json`.
Its actual runtime exposed ordinary-SY selection by array position after
normalization. The final candidate selects the unique ordinary source and
also preserves native rejection of noncanonical prepared envelopes.
`types-stopped.log` and one final-source complete invocation in
`operator-tests-stopped.log` passed 109/109. `source-manifest-stopped.json`
and `final-source-bytes.json` bind its exact source, with raw source capture
before its runtime. `candidate-r2-source-bytes.json` separately retains
the second candidate's original bytes. No Solidity gate was repeated.

## Artifact-first stages

The first PATH-resolved attempt failed because the installed Homebrew Forge
does not accept Solar. The second attempt explicitly selected the already
installed Solar-capable tools with `PATH="$HOME/.foundry/bin:$PATH"`.
No install, configuration edit or solc fallback occurred.

```sh
python3 scripts/forge-artifacts.py build \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  --consumer scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol \
  scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
```

Both completed with exit 0 in the same serial runner:
`runtime-artifacts-r2.log`, `stages-r2.log`, and monitor
`PORTABLE_STAGE_BUILD_COMPLETE`. Existing compiler warnings remain visible.
No Solidity edit occurred, so the accepted 28,576-test repository gate was
not repeated. Shell helpers passed `bash -n`; scoped Git whitespace passed.

## Real relocated runtime

An owned monitor waited for local18575 and then ran `bun "$E/capture.ts"`,
capturing original HTTP bodies into `wire.ndjson`. The observer acknowledges
its subscription and backfills every block since the fork pin before
following new heads. Its final line and monitor exit record closure.

The existing login shell ran:

```sh
export FORGE_BIN="$HOME/.foundry/bin/forge"
export ANVIL_BIN="$HOME/.foundry/bin/anvil"
export PATH="$HOME/.foundry/bin:$PATH"
sandbox-exec -f "$E/no-original-inputs.sb" \
  bun scripts/recovery/dtf-migration/cli.ts rehearse \
  --bundle "$E/authority-location-b/bundle.json" \
  --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18575 \
  --checkpoint .omo-runtime/dtf-migration-portable/checkpoints \
  --evidence "$E/runtime"
```

`cli.log` records the first failed run, retained under `runtime/`.
The second invocation uses `--evidence "$E/runtime-r2"`, with separate
`cli-r2.log` and `wire-r2.ndjson`; that failed run is also preserved.
The final invocation uses `--evidence "$E/runtime-r3"`, `cli-r3.log` and
`wire-r3.ndjson`. Every internal CLI command,
exit code/signal and stdout/stderr has its own `.log.command.json` and `.log`.
Original captures and all negative fixtures are retained. No resolved archive
credential URL is printed. Forge's environment stage uses Solar and the
existing real registry deployment path.

The stopped audit invocation is `bun "$E/probe/audit.ts" "$RUNTIME" "$E/wire-r3.ndjson"`.
Its completed evidence, not this recipe, supplies the runtime verdict.

All Git invocations use `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat PAGER=cat`
and `git --no-pager`; status/diff ignore submodules. No commit/ref/index write
or public action is part of this increment.
