# Independent source replay command

Date: 2026-11-12.

The producer's immutable, reviewed `../source/probe.ts` is executed in a fresh
process against a new owned fork, with its output argument redirected into
this verifier directory. The helper uses the independently source-bound
existing Solar artifact; no compilation or source change is needed.

```text
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-17-weighted-receipt; export PATH=/Users/cyotee/.foundry/bin:$PATH; /opt/homebrew/Cellar/bun/1.4.2/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/weighted-receipt/source/probe.ts ../source-verification/replay-01'
```

First invocation: monitor `mon_0HSK5JH0NFNMQNAA`, `bash_1`, exit 1.
The parent `source-verification/` directory did not yet exist, so the runner's
non-recursive output mkdir failed with ENOENT before resolving RPC or starting
Anvil. This file creates that parent. No source witness or runtime was created
by the failed invocation. The corrected invocation uses the same unused
`replay-01` output path.

This is a source-mechanics replay, not a Migration implementation or
production acceptance suite. The verifier separately checks raw bindings,
signed transactions, traces, logs, arithmetic and cleanup.
