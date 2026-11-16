# Independent combined pricing and preparation verification

Date: 2026-11-10. **AdversarialVerify: confirmed.**

The combined checkpoint executed **10,035 passing tests in 602 suites, 0 failed, 0 skipped**, with helper, Forge pipeline, tee, and completion-monitor exits **0**. All **882 checked runtime/test artifacts** bind to **2,435 unique current source dependencies**, with **zero metadata mismatches**. All **24 admitted committed/staged paths**, including corrected QA source, guard and quote evidence, match their accepted hashes and original commit/index/current bytes. The five-path preparation stage is unchanged. Owned runtime is removed; warm artifacts are retained. **No commit was made.**

This verdict covers the combined source/artifact/regression checkpoint only. It does not close original task 10, full Migration, actual-recovery E3, legacy acceptance, receipt/egress accounting, pooled-genesis authority, lifecycle, release readiness, or target-chain gas feasibility.

## 1. Authority, inputs and immutable source boundary

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration`. Branch: `work/dtf-migration`.

HEAD remains pricing commit `215c2bba6aa75e3e79bf68b7980b730927a85817`. Preparation commit `6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd` remains applied without commit. Both original commits have sole parent `90ff0307a7a8e084aa073e02eff125e9c7973933`; their actual changed-path inventories are disjoint: **19 pricing paths and five preparation paths**. Main remains at that base.

Read the complete integration brief, current repo router and applicable assistant/Foundry/Git/runtime instructions; both upstream commit receipts; original pricing independent report; independent F1/F2 correction report and applicable binding rows; original preparation independent report and both manifests; pricing-final recorded argv; preparation broad recorded argv and recorder; both current integration receipts; and the entire artifact-aware Python helper. The creation-code loader and production FactoryServices were also inspected. No new production behavior or policy was selected.

Upstream paths and exact file hashes are in `upstream-evidence.json`. The original pricing report remains historical **needs-fix**; its later correction report confirms F1/F2. Neither history nor failures were overwritten. The corrected Solidity QA script supersedes its original manifest hash, and the new guard plus corrected quote document use correction-verification hashes. No unchanged RPC QA was rerun.

`initial-binding.json` records the actual Git argv, stdout, stderr, exit values and SHA-256 comparisons. For every admitted path, accepted SHA-256 = original increment commit blob = staged index blob = current file bytes. Result: **24/24 match**. The preparation paths are exactly:

```text
contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol
contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol
```

No unrelated tracked change or unstaged tracked diff exists. `git ls-files --stage` and the complete staged binary diff are byte-identical before and after execution. Their initial SHA-256 values are `6f89eed8752023335d4f0b2463c02346f3ef9c710ce94ed2b6f4683c51ef5c08` and `54d099dd08204b1c1a67f77a35cff993b69d300eda866ffc9e103a1b2cbc3fe2`, respectively. All Git commands were prefixed with `GIT_MASTER=1`; intentional shared Crane gitlink traversal was excluded explicitly with `--ignore-submodules=all`. No index, branch, source, test or configuration edits were made.

## 2. Setup and exact command selection before execution

`foundry.toml` was read: default source `contracts`, tests `test/foundry/spec`, output `out`, cache `cache_forge`, and `via_ir = false`. Initially, `lib/crane` was an empty non-symlink directory; `node_modules`, `out` and `cache_forge` were absent. Only the empty Crane directory was removed with `rmdir`, and only absent/empty integration-owned paths were initialized. Dependency links point to main for read-only use. No populated directory was replaced and no install occurred.

Before the first compile, `cp -a` seeded integration-owned `out/` and `cache_forge/` from green phase03. Seed inventory: **7,184 output files / 4,755,983,279 bytes** and **3,850 cache files / 107,814,813 bytes**. The setup monitor emitted `INTEGRATION_WARM_SEED_READY` and exited **0**. Exact setup command and output are in `setup-command.txt` and `setup-result.txt`. No other Forge writer was found by the process probe; its final grep exit 1 meant no matching process, not a compiler failure.

`command-selection.json` was authored **before compilation**. Build sources are exactly the union of both manifests' Solidity paths under `contracts/`: **18**. Test/script roots were not passed as changed build sources. Test roots are source-derived from the exact recorded pricing-final and preparation-broad argv, plus the mandated migration directory. Directory containment removes three redundant file roots, including both original weighted DETF suites, without removing their execution. Final selection: **13 roots**, **589 test files**. The original pricing verbosity was `-vvv`; this authorized combined invocation uses `-- -vv`.

Exact helper invocation:

```sh
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol \
  contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol \
  contracts/utils/StandardExchangeFrozenQuoteLib.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol \
  contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol \
  contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf \
  --test-root test/foundry/spec/vaults/detf/common \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Swap.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Fees.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_RefundCallback.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_FullRangeBook.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Previews.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol \
  -- -vv
```

Actual wrapper: `/bin/bash /Users/cyotee/Projects/indexedex-wt/dtf-migration-integration/docs/incidents/2026-09-16-dtf-recovery/migration/integration-increments/verification/run.sh`. The wrapper passed `bash -n` with exit **0**. It selects `/Users/cyotee/.foundry/bin` first on PATH, default profile, explicit task-owned TMPDIR/XDG/Node/Bun/npm runtime caches, and `PYTHONDONTWRITEBYTECODE=1`. Inherited Foundry override probe found none; the wrapper also explicitly unsets source/output/cache/compiler/match/fork overrides. No source-path retarget, package profile, viaIR, warning suppression, node, fork, broadcast, public action or delegation was used.

The helper was inspected rather than trusted by name: it discovers source/import and literal runtime-artifact dependencies, builds concrete dependents and runtime roots, stops on build failure, then runs Solar tests with generated skips for unrelated roots while preserving configured paths. `ArtifactCreationCode` reads local JSON creation code and recursively links libraries; production FactoryServices consume those artifacts. Therefore the build-before-test step is load-bearing, not an optional warm-up.

## 3. Actual build and test receipts

`combined.log` is the complete **1,655,576-byte, 26,953-line** raw stdout/stderr capture, archived byte-for-byte with `apply_patch`, SHA-256 **`cf835cab6754df1072d64ac7c6c0f8b8eebdf868c4e4a9263fb047529c4ce5b2`**. It is intentionally retained even though Git ignores log files. The log contains the literal helper command at line 16 and full actual expanded Forge argv at lines **18-19**; `artifact-plan.json` additionally preserves the matching structured commands. Both compiling commands explicitly use **`--use solar`**.

| Step | Actual result |
| --- | --- |
| Start | `2026-11-10T19:47:50Z` |
| Artifact-first build | 275 build roots, 1,501-source import closure, 280 runtime artifact IDs; **34 files** compiled successfully with Solar 0.8.38, 191.88 ms; raw lines 17-25. |
| Test compilation | **698 files** compiled successfully with Solar 0.8.38, 20.54 s; raw lines 8362-8364. |
| Test execution | **602 suites, 10,035 PASS records, zero failed/skipped**; 71.23 s wall / 1,213.77 s CPU; raw line 26951. |
| Helper and capture exits | `COMMAND_EXIT=0`; `PIPE_COMMAND_EXIT=0 TEE_EXIT=0`; monitor exited **0**. |
| End | `2026-11-10T19:49:37Z` |

Exact final output:

```text
Ran 602 test suites in 71.23s (1213.77s CPU time): 10035 tests passed, 0 failed, 0 skipped (10035 total tests)
COMMAND_EXIT=0
END 2026-11-10T19:49:37Z
PIPE_COMMAND_EXIT=0 TEE_EXIT=0
watcher completed (exit code 0)
```

The final two lines are the monitor/pipeline receipt, recorded separately in `command-exits.json` and `results.json`; they are not falsely presented as part of the tee file. Both finite monitors exited naturally. The durable subscription had no kill deadline; the monitor description's four-hour wording did not impose one. No impatient cancellation or duplicate test invocation occurred. There was exactly **one artifact-first helper test invocation**. A separate helper **plan**, not build/test, exited 0 to capture machine-readable selection.

Counts were independently reconstructed from every `Ran ... for`, `[PASS]`, and `Suite result` row, not merely copied from the final summary. Ordinary DETF tree: **559 suites / 9,560 passes**. Common tree: **30 suites / 372 passes**. The remaining **13 suites / 103 passes** are:

| Actual named suite | PASS count | Raw location |
| --- | ---: | --- |
| `ERC4626StandardExchange_TransitionQuote` | 13 | `combined.log:8778-8792` |
| `UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test` | 5 | `combined.log:8815-8930` |
| `UniswapV3FullSpreadStandardExchangeVault_FullRangeBook_Test` | 18 | `combined.log:9367-9386` |
| `UniswapV3FullSpreadStandardExchangeVault_Previews_Test` | 9 | `combined.log:9404-9414` |
| `UniswapV4DetfMigrationSnapshotReceiptExclusionTest` | 1 | `combined.log:9681-9683` |
| `UniswapV4DetfMigrationSnapshotDecimalsTest` | 1 | `combined.log:9822-9824` |
| `UniswapV4DetfMigrationSnapshotTest` | 14 | `combined.log:10414-10435` |
| `UniswapV4StandardExchangeWeightedBufferHook_Fees` | 2 | `combined.log:20223-20226` |
| `UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock_Test` | 6 | `combined.log:20354-20361` |
| `UniswapV4StandardExchangeWeightedBufferHook_RefundCallback` | 1 | `combined.log:20561-20563` |
| `UniswapV4StandardExchangeWeightedBufferHook_Scale` | 16 | `combined.log:20920-20937` |
| `UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi` | 10 | `combined.log:21082-21093` |
| `UniswapV4StandardExchangeWeightedBufferHook_Swap` | 7 | `combined.log:21272-21280` |

The combined distinct total also reconciles as **9,932 preparation-broad + 111 pricing-final - eight overlapping weighted-DETF tests = 10,035**, not the sum of overlapping prior scopes. The prior 24 focused tests are not added again.

Actual named integration witnesses include:

- `test_MigrationSnapshot_RealProxyCaptureAndFreeze()`: PASS, gas **13,063,518**, `combined.log:10422`.
- `test_deploy_customRoutesMetadataAndChildBindings()`: PASS, gas **48,534,520**, `combined.log:15789`.
- `test_deploy_parentMetadataDeclarationsAndDefaults()`: PASS, gas **229,134**, `combined.log:15791`.
- `test_deploy_sameArgsPreserveFundedStateAndNoInitializerRouting()`: PASS, gas **2,197,626**, `combined.log:15792`.

The deployment suite actually executes all six tests. FundedStakingSequence executes two; RebasingClaimToken_Accounting executes three; DETFNFTVaultDFPkg_Deploy_Test executes nine. Every suite, test name, count and raw line is retained in `results.json`. There is no empty-selection exit-zero coverage claim.

## 4. Current artifact binding

Forge is **1.9.1-nightly**, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`, built `2026-11-03T06:12:02.538056000Z`. Checked artifact compiler metadata reports `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`; it is not relabelled as configured solc 0.8.35.

`source-artifact-binding.json` enumerates every one of the helper's **280 runtime IDs** plus the **602 actually executed suite artifacts**: **882 artifacts**. For each, the check resolves its output path, checks compilation target identity, nonempty creation/runtime bytecode, Solar compiler metadata, absence of viaIR=true, full artifact SHA-256, and every metadata source's Keccak-256 against exact current bytes. **2,435 unique dependencies were checked; zero artifact issues and zero source mismatches.** This is current-source binding, not reliance on mtime, a copied cache, or another worktree's success.

Corrected QA script/guard/document bytes are separately bound among the 24 admitted paths. No new QA-script artifact build or RPC replay is claimed; the prescribed build inputs exclude scripts, and unchanged QA behavior relies on the accepted correction receipt. Existing occupied CREATE3 instances are not upgraded by these source/artifact checks.

## 5. Diagnostics and preserved failures

Both compiler steps succeeded **with warnings**, not warning-free. The full unfiltered log and `results.json` retain **946 emitted warning headers**, including repeated diagnostics across build and test compilation. Counts are emissions, not unique defects:

| Header/category | Emissions |
| --- | ---: |
| `Warning:` | 4 |
| `warning[5740]` | 4 |
| `warning[2018]` | 41 |
| `warning[reentrancy-events]` | 53 |
| `warning[block-timestamp]` | 4 |
| `warning[uninitialized-local]` | 67 |
| `warning[unsafe-typecast]` | 162 |
| `warning[calls-loop]` | 219 |
| `warning[require-revert-in-loop]` | 222 |
| `warning[unused-return]` | 133 |
| `warning[incorrect-strict-equality]` | 3 |
| `warning[non-reentrant-not-first]` | 13 |
| `warning[arbitrary-send-erc20]` | 1 |
| `warning[weak-prng]` | 2 |
| `warning[divide-before-multiply]` | 13 |
| `warning[missing-zero-check]` | 1 |
| `warning[reentrancy-no-eth]` | 4 |

Nightly and unknown `fmt.skip` warnings were not muted. Source-location/header comparison against the admitted pricing-final and preparation-broad raw logs matched **944/946** emissions after line/column normalization. The two unmatched fingerprints are ordinary mutability suggestions: weighted DFPkg `postDeploy` could be pure (line 40), and the original `test_deploy_inert_until_first_bond` could be view (line 8518). They are disclosed, not silently equated with clean diagnostics or fixed. This comparison is not a security disposition of every lint warning. No compiler error or failing test occurred.

Biome and bash-language-server are unavailable; no installation or LSP-clean claim is made. JSON evidence was constructed with JSON serialization; shell syntax passed `bash -n`. Solidity compilation and actual runtime tests are the gates used here. `command-exits.json` preserves minor non-execution audit-tool errors, including the truncated JSON-read parse and rejected wrong-parameter patch call; no test failure was removed or edited green. Original upstream failed/empty-selection receipts remain unchanged.

## 6. Preservation, writes and cleanup

`preservation.json` and `cleanup-result.json` record successful final read-only Git commands and exact outputs. All **24 source/evidence path hashes**, both pre-existing untracked integration receipts, and **11 upstream evidence inputs** remain unchanged. HEAD, main, the complete index and staged binary patch remain unchanged. Exactly the five admitted preparation paths are staged; the tracked unstaged diff is empty and staged whitespace check exits **0**. New authored evidence is confined to this `verification/` directory and remains unstaged. No commit, push, PR, merge, cherry-pick, rebase, amend, reset, discard, install or public action was performed by this verifier.

Owned runtime: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration/.integration-verification-runtime-st01a1c6fd`. The completed recorder PID **14115** is absent (`ps` exit **1**); runtime has no open handles (`lsof +D` exit **1**). No node or listener was created. The archived raw log was compared with `cmp`, then only its owned temporary duplicate was removed. All five created cache directories were inspected empty and removed with `rmdir`, followed by the owned parent. Cleanup command exited **0**, emitted `OWNED_RUNTIME_ABSENT_WARM_ARTIFACTS_RETAINED`, and verified the runtime absent.

Integration-owned warm `out/` and `cache_forge/` remain available. Read-only-use links remain `lib/crane -> /Users/cyotee/Projects/indexedex/lib/crane` and `node_modules -> /Users/cyotee/Projects/indexedex/node_modules`. No shared dependency or other worktree was written, no prior evidence was removed, and no cache was copied back into main. Temporary runtime and process cleanup is complete; retained worktree artifacts are deliberate, not a claim to close their separately tracked eventual cleanup.

**Final verdict: AdversarialVerify confirmed for this combined checkpoint; no source correction is requested and no commit was made.**

