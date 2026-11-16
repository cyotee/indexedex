# Task 13 final-tree verification

Date: 2026-11-15. Worktree: /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1.

Verdict: acceptance incomplete. Execution and classification are delivered; the full operator command failed, and the task 10 rehearsal plus task 12 current-chain lifecycle proofs remain unmet. This report does not mark the plan checkbox or authorize a public transaction or allocation.

## Observed command results

| Required surface | Exact command or raw command record | Actual exit | Observed cases |
| --- | --- | ---: | --- |
| Production build | forge build --use solar; hermetic-r2/03.log.command.json | 0 | Compiled 3,237 files with Solar; warnings retained |
| Full hermetic | forge test --use solar -vv --no-match-path '**/fork/**' --no-match-contract Fork; hermetic-r2/04.log.command.json | 0 | 28,641 passed, 0 failed, 0 skipped; 2,691 suites |
| All K pinned forks | fork/03.log.command.json: python3 scripts/forge-artifacts.py test contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv | 0 | 183 passed, 0 failed, 0 skipped; 30 suites, all 26 test files |
| Operator typecheck | operator-r2/03.log.command.json | 0 | Typecheck, not a test count |
| Full operator tests | bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts; operator-r2/04.log.command.json | 1 | 240 passed, 1 failed; 241 cases across 21 files |
| Delivered helper typecheck | helper-typecheck.log, helper-typecheck.exit.log, invocation-inventory.json | 0 | Typecheck, not a test count |

The exact two TypeScript invocations are:

```bash
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

Each recorder was invoked through the delivered resumed-integration/record-verification.ts. The initial hermetic and operator attempts retain completed:false after an unsuitable inherited PATH; replacement outputs are additive at hermetic-r2 and operator-r2. The passing hermetic-r2 and fork directories each contain environment.json, numbered complete raw logs, per-command sidecars and results.json. operator-r2 contains the same records with completed:false. Recorder console output is preserved separately for every attempt. Failure dispositions explain absent command-1 raw logs in the failed startup attempts without inventing them.

## Ordinary-family coverage actually observed

hermetic-suite-summary.json records each relevant suite header, line number and actual suite summary from the full log. The Uniswap V4 DETF prefix ran 559 suites and 9,560 cases. The common bond/staking prefix ran 30 suites and 372 cases. The explicitly Weighted-named subset of the V4 DETF prefix ran 103 suites and 2,272 cases; this is a subset, not an additional total. Migration hermetic coverage ran 34 suites and 236 cases. All have zero failed or skipped cases. Both mandatory prefixes are present, so the conditional P section 10 focused commands were not rerun. No second full-tree test was started.

fork-suite-summary.json maps all 26 K .t.sol files to 30 selected suite summaries, with zero missing files. It preserves the helper's full emitted build and test commands, including its compile-selection exclusions. The real archive capability was supplied through the existing zsh configuration; no credential value was written to task evidence.

## Versions and exact source binding

The approved toolchain is Forge 1.9.1-nightly, commit 430523103f3e2f9ba432ffdd2031a9f966153d0d, and Solar 0.3.0-dev commit e7a91fc70f29dc8d0c236d56a2aa7706dc2555cf, Solidity-compatible 0.8.38. Bun CLI is 1.4.2, Node CLI v26.11.1 and Python 3.15.2. Recorder environment.json files preserve their actual runtime versions. Initial runtime-versions.log also records the inherited Homebrew Anvil 1.9.0; that probe is not substituted for the approved Forge/Solar logs. TypeScript is 5.9.2, ethers 6.17.0, zod 3.25.74 and @types/node 26.6.5. dependency-versions.json contains all 52 declared direct dependency versions and package metadata hashes; invocation-inventory.json contains helper hashes, command inventory and environment correction.

source-before.json and source-final.json contain raw SHA-256 hashes for 16,409 source/configuration entries under contracts, test, scripts, lib/crane/contracts and root package/Foundry configuration and lockfiles. There are zero changed, added or removed entries across the runs. Five separately bound helper/receipt files also match. This is an explicit scoped content manifest, not a Git cleanliness claim or a hash of unrelated repository data. The final evidence index binds the task-13 raw logs and authored records separately.

build-artifact-audit.json records the exact exit-0 build sidecar, build-log hash and the witness artifact's metadata/compiler/source hash. Its current bytecode still matches the operator's failing actual hash. The build output's final lint warning was never treated as an exit receipt; the actual sidecar and recorder transition establish exit 0. Embedded unsuccessful Forge dependency bootstrap messages and compiler/lint warnings remain visible and qualified.

## Existing evidence reuse

Task 11 signed gas receipts are reused only for their measured gas surfaces. Its accepting command manifest contains 221 sources: 219 match current bytes and the two changed files are bundle.test.ts and rehearsal-portable.ts from task 12. Neither is reachable through the signed helper's 28 local imported modules; there are zero unresolved local imports. The product contracts, gas generation script, signed helper and reachable modules in that source map are unchanged. task-11-reuse-audit.json records this comparison without pretending the entire historical source fingerprint is still equal. task-11-receipt-hashes.json independently matches the signed raw log, gas-negative witness and two repaired provenance supplements to their retained verification pins.

Reuse retains the four construction receipts for two parents, 51 operation/recovery samples and the historical snapshot-branch qualifications. It does not assert a fresh rerun, simultaneous survival of all branch receipts, arbitrary batch shapes, or a complete lifecycle. No affecting source change was found within the recorded gas surface, so no signed-gas rerun was needed. The current pinned fork gas cases also ran in the full K check.

## Met items

- Exact production build and full hermetic commands exited 0, with real nonzero cases and explicit ordinary-family summaries.
- The all-K artifact-helper command exited 0 and selected every migration fork test file.
- Both required TypeScript checks exited 0. The full operator command ran without excluding the failing test.
- Full raw logs, actual command sidecars, environment records, dependency/compiler/runtime versions and before/final source hashes are retained.
- The operator failure was independently tied to task 7's prior raw failure and unchanged witness sources; the pin was preserved.
- Task 11 gas evidence was source-qualified and reused only for the unchanged measured surface.
- Failed startup attempts were preserved and resolved through the toolchain environment alone. No tests, product sources or witness pins changed.

## Unmet items

- Required full operator test success: exit 1 for the fixed witness-pin mismatch. Task 7's claimed-SY witness remains red and is an in-scope authentication gap.
- Task 10's complete current-chain rehearsal: no admissible 10,000 DTF donor, no rehearsal, no mixed-pricing/same-block/donation/NFT 3 real lifecycle receipts. Reuse is unmet. The prohibited rehearsal was not run.
- Task 12's real portable current-chain proof and actual current-owner purchase/donation lifecycle reconciliation. The offline relocation and 23 tamper rejections are not substituted for those proofs.
- Consequently the conjunctive task 13 acceptance criterion, all required commands passing and all required lifecycle evidence bound, is not met. Passing Foundry tests do not close the missing external rehearsal.

## Scope and diagnostics

Only task-13 evidence and test-generated local artifacts were written before the explicitly requested final task-13-done.json claim. No cause-fix source edit was necessary or made. No delegation, commit, public transaction, financial allocation, DTF mint/etch, witness-pin retune, or task-10 rehearsal occurred. The plan checkbox remains untouched; Commit N is retained. The configured Biome executable is absent; no LSP run or installation is claimed. Evidence JSON is locally parsed and log/receipt joins are checked before the final claim.
