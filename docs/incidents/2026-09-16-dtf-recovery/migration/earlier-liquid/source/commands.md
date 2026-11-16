# Executed commands and failed attempts

All commands ran from
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source`.
No command wrote to a public chain. Runtime evidence is under this directory.

## Artifact-first helper build

```sh
PATH=/Users/cyotee/.foundry/bin:$PATH forge build --use solar docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/EdCustodyProbe.sol --out docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/artifacts --cache-path docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/compiler-cache
```

Monitor `mon_WQKF2D05EH2FHH2J`, session `bash_9`, exit 0.
Observed output: `Compiling 1 files with Solar 0.8.38`,
`Solar 0.8.38 finished in 7.38ms`, `Compiler run successful!`.
Existing nightly-build and unknown `fmt.skip` warnings were emitted.
There was no legacy-source recompile or production build.

The first monitor registration requested 7200000 milliseconds and was rejected
before starting a process: `timeout_ms: must be <= 3600000`. The corrected
registration used 3600000. This is a tool registration failure, not a compile.

## Probe typechecks

```sh
./node_modules/.bin/tsc --noEmit --target es2022 --module esnext --moduleResolution bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/probe.ts
```

Initial check: `mon_HWNGJT7EJWQW6VXS`, `bash_11`, exit 0.
Final check, sequenced before the custody-only control:
`mon_TKP7ZWPG9GN80JV6`, `bash_16`, exit 0 for the combined command.
No diagnostics were printed. `skipLibCheck` is limited to dependency declarations;
strict checking remains enabled for the probe and imported project code.
The editor's TypeScript diagnostic freshness timed out. JSON LSP was unavailable
because Biome was absent; no dependency or configuration was installed.

## Exact runtime invocation

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source; export PATH=/Users/cyotee/.foundry/bin:$PATH; /opt/homebrew/Cellar/bun/1.4.2/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/probe.ts'
```

Existing `robinhood_mainnet_alchemy` configuration and login bootstrap only.
No credential value or resolved upstream URL is retained.

* `mon_M451EKEYSGRKFY02`, `bash_12`, exit 1: `run-01`.
  `history/probe-01.ts.txt` is its exact probe source. After genuine acquisition
  and local helper deployment, publishing the deployment witness failed:
  `TypeError: JSON.stringify cannot serialize BigInt.`
  Stack: `provenance.ts:12:53`, `canonical`, `rehearsal-data.ts:31:84`,
  `probe.ts:88:11`. The deployment witness was not saved; it is not admitted
  as complete receipt proof. Existing identity/acquisition evidence and
  `cleanup.json` remain untouched. PID 40431 stopped.
* `mon_7CJME985ZVHZE4NB`, `bash_14`, exit 0: `run-02`.
  `history/probe-02.ts.txt` is its exact probe source. The material correction
  converts bigint evidence fields to decimal strings before the unchanged
  canonical writer. The source route and economic inputs were not changed.
  The single actual ED conversion attempt is in this run.

The final source adds a custody-only control. Its invocation, after the final
typecheck in the same command, was:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid-source; export PATH=/Users/cyotee/.foundry/bin:$PATH; /opt/homebrew/Cellar/bun/1.4.2/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/source/probe.ts control'
```

`mon_TKP7ZWPG9GN80JV6`, `bash_16`, exit 0: `run-03-control`.
This fresh fork proves missing balance with a positive allowance after the
original wallet's terminal pull. It performs no conversion and does not retry
the failed ED exit. It clears the unused allowance before stopping PID 43102.
The main run's PID 41088 had already stopped.

The first offline audit cell had a JavaScript parse error,
`Unexpected token ')'`, before executing any statement. The corrected cell
audited 20 signed transactions, eight economic rollbacks, the full helper
runtime and compiler-source equality, and wrote `audit.json`.
These are producer checks, not independent verifier results.

## Scope and cleanup checks

`git rev-parse HEAD` returned `acdbe319f3a20c3af6bea594c62461b6c7988717`;
branch was `work/dtf-migration-phase-19-earlier-liquid-source`.
Every Git command used `GIT_MASTER=1`.
Ordinary `git status --short` initially failed with exit 128:
`error: expected submodule path 'lib/crane' not to be a symbolic link`.
Status and diff with `--ignore-submodules=all` were clean before authoring.
The prescribed dependency links were not changed.

After runtime shutdown, `lsof -nP -iTCP:18569 -sTCP:LISTEN` exited 1 with
no listener. Final resource and scope checks are bound in `cleanup.json`.
All execution monitors completed; no standing subscription was created.
