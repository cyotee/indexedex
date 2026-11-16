# ED implementation execution ledger

Working directory:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-19-earlier-liquid`.
All shell execution used the real login-shell environment. Compiling commands
used Solar through the repository artifact-first launcher or explicit
`forge build --use solar`; no alternate compiler or size override was used.
The current worktree inherited the stopped phase18 warm `out/`/`cache_forge`.

1. Verified the clean starting tree, branch and exact audited cumulative HEAD.
   Every Git read supplied `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0`, disabled
   submodule recursion and ignored submodules where supported.
2. Verified the two required ED document SHA-256 values. Read the implementation
   brief, source brief, current r5 plan/r22 PRD, complete ED contract/producer and
   independent reports, actual ED source excerpts, admitted earlier/CP/NFT
   recovery inputs, and inherited WS/ER runtime and delivery audits. Historical
   limitations remain qualifications, not requests to implement excluded paths.
3. Ran `/bin/zsh .../implementation/contracts-check.sh`. Its exact eight edited
   production roots and full current spec/fork roots are in the script. Build,
   146 specs and the initial107 forks exited0.
4. Ran strict operator types and built both Stage00 and Stage01 with Solar.
   `types-01.log` and `stages-01.log` retain the results.
5. Ran `/bin/zsh .../implementation/operator-check.sh`. It ran strict types,
   exactly one final operator-test invocation covering all nine current test
   files (76 passing), then the actual CLI:

   ```sh
   bun scripts/recovery/dtf-migration/cli.ts rehearse \
     --rpc-alias robinhood_mainnet_alchemy \
     --fork-block 108944663 --port 18569 \
     --checkpoint .omo-runtime/dtf-migration-earlier-liquid/checkpoints \
     --evidence docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation/runtime-01
   ```

   The CLI includes the three genuine mined-before-checkpoint interruptions
   and fresh-process resumes. It completed and removed checkpoints/runtime;
   the wrapper removed the empty owned runtime parent.
6. Ran `bun .../implementation/capture-inputs.ts` before further compilation.
   All24 original pre-capture inputs matched their recorded raw hashes and
   sizes, and their actual bytes were captured unchanged. No reconstructed
   bytes are presented as original artifact bytes.
7. Added only the two ED-specific real-source inventory/cliff fork regressions
   and approval-persistence assertion. Ran the full fork suite again using
   the same eight production roots and artifact-first launcher. All109 passed.
   This did not change production/operator code.
8. Ran `bun .../implementation/source-manifest.ts`. It froze32 candidate source
   files, verified78 ED source-only evidence files and26 admitted authority
   bindings, and rechecked1386 original phase18 producer evidence files.
   Source modifications stopped at this manifest.
9. Strict evidence-probe types passed. Producer audit attempt01 rejected an
   overly broad ERC20 Transfer decoder encountering the ERC721 Transfer with
   the same topic but empty data. Restricted that evidence-only decoder to
   ED/new-DETF logs. Attempt02 completed all runtime/economic checks.
10. Evidence-only attempt03 reached the exclusive-create guard for the existing
    `audit.json`; it did not overwrite that successful audit. Added a distinct
    `--final` output path. Attempt04 and final probe strict types are retained
    separately. No production/operator/test fix was needed for either audit
    tooling issue.
11. Final seal command is `bun .../implementation/audit.ts --seal`, with
    `set -o pipefail` and output retained in `seal.log`. It rechecks the frozen
    candidate, original evidence, runtime/compiler/signatures/economics,
    original phase18 evidence, and absent owned runtime/process/port before
    sealing all evidence except its own self-reference and output stream.

All generated artifacts, original receipts, signed raw transactions, traces,
CLI command records, failure attempts and cleanup evidence remain retained.
No test was skipped, weakened or deleted; no source-only witness was used
instead of the registry integration.
