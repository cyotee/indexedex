# Source probe commands and exits

All commands ran from
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`.
In this document P means
`docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/source`.
It is a readable path abbreviation, not an unbound execution variable.
All compiling Forge calls used Solar. Source probes used only fixed18568.

## Compiler

First attempt, `commands/bash_4.log`, exit1:

```sh
/Users/cyotee/.foundry/bin/forge build --use solar P/ReceiptCustodyProbe.sol --out P/build --cache-path P/cache
```

The command lacked Solar in PATH. The successful existing-environment wrapper
was, with P expanded to its path above:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt && export PATH=/Users/cyotee/.foundry/bin:$PATH && forge build --use solar P/ReceiptCustodyProbe.sol --out P/build --cache-path P/cache'
```

`commands/bash_6.log`: exit0, five sources.
`commands/bash_10.log`: the same build after the measurement correction,
one changed source, successful before the source probe. No viaIR.

## Source executions

Each source runtime command used this existing login bootstrap:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt && export PATH=/Users/cyotee/.foundry/bin:$PATH BUN_RUNTIME_TRANSPILER_CACHE_PATH=0 NODE_DISABLE_COMPILE_CACHE=1 && /opt/homebrew/Cellar/bun/1.4.2/bin/bun P/probe.ts run-01'
```

The program resolves the existing `robinhood_mainnet_alchemy` Foundry alias
in memory. Its launch helper redacts the resolved upstream from Anvil output.
No environment file, download, credential print or metadata fetch is involved.

| Command tail inside the wrapper | Tool command evidence | Result |
| --- | --- | --- |
| `bun P/probe.ts run-01` | `commands/bash_7.log` | Exit1 after completed custody cases; missing donor DTF |
| `bun P/rate-probe.ts run-02` | `commands/bash_9.log` | Exit1; ED transfer to LP did not change rate |
| `forge build ... && bun P/probe.ts run-03 && bun P/rate-probe.ts run-04` | `commands/bash_10.log` | Build and source child exit0; rate child and outer command exit1 |
| `bun P/rate-probe.ts run-05` | `commands/bash_11.log` | Exit0; actual2197->4046 rate movement and subsequent pull/rollback |

Here `bun` in the table expands to the exact installed1.4.2 binary in the
wrapper. Failed earlier recipes are retained in `history/`. Final replay
requires a new, nonexistent output-directory name because evidence writes
are create-only.

## Static checks and offline proof

The strict command, with actual source paths substituted, is:

```sh
/opt/homebrew/Cellar/bun/1.4.2/bin/bun node_modules/typescript/bin/tsc --noEmit --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --module nodenext --moduleResolution nodenext --target es2022 --skipLibCheck P/probe.ts P/probe-runtime.ts P/rate-probe.ts
```

`commands/bash_8.log` passes the initial two files; `commands/bash_12.log`
passes all three final runtime recipes. `commands/bash_14.log` passes the
initial audit. Final audit source, after decimal-output correction:

```sh
/opt/homebrew/Cellar/bun/1.4.2/bin/bun P/audit.ts
/opt/homebrew/Cellar/bun/1.4.2/bin/bun node_modules/typescript/bin/tsc --noEmit --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --module nodenext --moduleResolution nodenext --target es2022 --skipLibCheck P/audit.ts
```

These last two ran with `&&` in one command and exited0 with `AUDIT_PASS`.
The first audit's BigInt serialization failure is retained in
`commands/audit-failed.log`. The corrected proof is `proof.json`.
No production test suite or operator rehearsal was run.

## Cleanup checks

Read-only Git operations use `GIT_MASTER=1`, `GIT_OPTIONAL_LOCKS=0` and
`--ignore-submodules=all` where applicable. Tracked and staged diffs exit0
with no output; HEAD/branch match the task. Only this evidence tree is new.

```sh
ps -p 89388,91077,94135,94201,95785 -o pid=,command=
lsof -nP -iTCP:18568 -sTCP:LISTEN
```

Each exits1 with no process/listener output. The fixed checkpoint path is
absent. These are successful absence checks, not exit0 process discoveries.
