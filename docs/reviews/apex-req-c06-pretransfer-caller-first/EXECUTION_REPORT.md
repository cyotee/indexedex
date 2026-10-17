# REQ-C06 execution report

Status: implemented and scoped validation passed on 2026-10-16. All 21 sites are repaired and all 86 added controls passed. The seven complete suites passed 176/176 tests. The repository-wide bare-expectation scanner remains red on 317 pre-existing sites; this task added none. User explicitly requested execution of the 2026-10-16 plan.

## Preflight and source inspection

All 21 original measurement lines matched the PRD before editing. The seven production files and seven named test files were saved before editing under `.scratch/c06-caller-first/before/`. The existing dirty worktree was recorded in `.scratch/c06-caller-first/status-before.txt`; unrelated changes, including the retired legacy V4 deletion, are preserved.

Inspected the full production diff before running tests (`.scratch/c06-caller-first/production.diff`). It contains exactly 20 new guarded insertions, the guarded V3 mint move, and four imports. Each check immediately precedes measurement and all consumers of that measurement. The existing credit comparisons, input ceilings, quotes, refunds, settlement statements, and internal secure-transfer helpers remain unchanged. V3 withdrawal is unchanged. No excluded site was edited.

## Validation

Default Foundry profile, Forge 1.5.1-stable (`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`), solc 0.8.35, Python 3.10.5. Optimizer enabled with one run; `via_ir = false`. Existing warm `out/` and `cache_forge/` retained.

Artifact planning output: `.scratch/c06-caller-first/plan.log`.
Build/test output: `.scratch/c06-caller-first/test.log`.

Full build-before-test command (all seven named files, without a test-name filter):

```sh
python3 scripts/forge-artifacts.py test contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol --test-root test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol --test-root test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol -- -vv
```

The corresponding artifact plan uses the same arguments without `-- -vv`, with `plan` replacing `test`.

Required scanner command: `bash scripts/apex_bare_expectrevert_scan.sh --check`.

No test is claimed passed until its result is recorded below.

## Initial validation results

- Artifact plan: exit 0, 97 build roots / 529-source import closure / 90 runtime artifact IDs.
- First artifact build: passed; 13 files, solc 37.62 seconds. Existing unreachable-code warnings in `NativeStandardYieldTarget.sol` and hash-style lint notices remain.
- First test compilation: passed; seven files, solc 115.26 seconds. Forge then crashed before runtime tests, exit 250, in macOS `system-configuration` / `SCDynamicStoreBuilder` (`Attempted to create a NULL object`). No runtime pass is claimed from that invocation.
- Retrying the identical build/test command outside the sandbox using the approved `.scratch/c06-caller-first/run.py test-unsandboxed` wrapper. It changes no Foundry settings. Log: `.scratch/c06-caller-first/test-unsandboxed.log`.
- Bare-expectation scanner: exit 1, 317 existing bare expectations in 3,160 scanned files. Each selected test file contained zero bare expectations before this task and still contains zero. This item added no scanner site. Unrelated expectations were not changed. Log: `.scratch/c06-caller-first/scanner.log`.
- `git diff --check`: passed.
- Refreshed affected execution artifacts are under 24,576 runtime bytes: hookless OutFacet 21,161; Pons OutFacet 21,130; V3 OutExecutionDelegate 23,365; Uniswap V2 OutFacet 19,433; Camelot OutFacet 15,962; Rocket Pool OutFacet 11,229; Lido OutFacet 15,483.

The added controls are 28 Uniswap V2, 20 Camelot, 8 Rocket Pool, 8 Lido, 4 V3, and 9 each hookless/Pons (86 total). The extra V4 controls distinguish successful nested false-flag minting from the idle false-flag route rejection. Tests use the existing production registry fixtures, never mock the SUT or unlock, and use `AtomicPretransferCaller` for direct allowed-contract calls.

## First runtime run and test corrections

The unsandboxed run exited 1: 176 tests across all seven suites, 160 passed and 16 failed. All original tests passed. Camelot (28/28), V3 (15/15), hookless (15/15), and Pons (15/15) were green. Uniswap V2 passed 27/39; Lido passed 37/39; Rocket Pool passed 23/25.

The twelve V2 failures were all four C06 controls for each of token swap, token-to-share, and token-to-LP. The added fixture incorrectly assumed the base left token A on the payer; its balance was zero. The selected test now mints the needed payer tokens using the existing mintable fixture token, with no transfer into the vault until the tested call. The supported route, quote, ceiling, deadline, zero-credit assertion, and exact errors are unchanged.

The four LST failures were `test_C06_wethToShare_eoaPull` and `test_C06_wethToShare_contractFunded` in both Rocket Pool and Lido. The added supply assertion incorrectly omitted the existing usage-fee issue. It now reconciles total supply as requested user shares plus the configured fee shares, and asserts the fee collector's exact balance delta. The user's exact output assertion remains unchanged; no fee configuration or production rounding was changed.

Additional assertion review strengthened V2/Camelot zap payouts to reconcile recipient output against all output tokens released by the underlying pool (or at least the requested LP for token-to-LP). V3 and both V4 snapshots now also include deployed reserves. No error expectation was relaxed, caught, or moved to another test file. No fixed fixture was found unable to reach its named comparison.

The full artifact build plus all seven files was repeated with `.scratch/c06-caller-first/run.py test-final`; log `.scratch/c06-caller-first/test-final.log`.

## Final results

`.scratch/c06-caller-first/run.py test-final` exited **0**. The wrapper ran the exact artifact-helper command above, including its mandatory production artifact build, followed by all seven named test files in full. The build reused current artifacts; the seven updated test files compiled successfully in 114.48 seconds. Runtime completed in 12.63 seconds: **176 passed, 0 failed, 0 skipped**. All **86 C06 controls passed**, as did all 90 existing tests.

| Family / named suite | Original measurement lines | Repaired branches | Added C06 controls passed | Whole suite passed |
| --- | --- | ---: | ---: | ---: |
| Hookless `ApexRecurrenceErrorOrder.t.sol` | 94, 165 | 2 | 9 | 15 |
| Pons `ApexRecurrenceErrorOrder.t.sol` | 94, 165 | 2 | 9 | 15 |
| V3 release `ApexRecurrenceErrorOrder.t.sol` | 102 (mint) | 1 | 4 | 15 |
| `UniswapV2StandardExchange_SecRemediation.t.sol` | 462, 547, 623, 693, 794, 905, 972 | 7 | 28 | 39 |
| `CamelotV2StandardExchange_SecRemediation.t.sol` | 411, 513, 596, 663, 766 | 5 | 20 | 28 |
| `Adversarial_RocketPoolRETH_P0.t.sol` | 60, 82 | 2 | 8 | 25 |
| `Adversarial_LidoWstETH_P0.t.sol` | 64, 85 | 2 | 8 | 39 |
| **Total** | | **21** | **86** | **176** |

Each branch covers code-less short-credit rejection, the allowed-contract exact credit error, unchanged false-flag behavior, and funded allowed-contract success. V4 mint additionally distinguishes idle `InvalidRoute` from supported nested pull success. Rejection snapshots cover caller, recipient, payer, and vault token/share balances, supply, and reserve books; FullSpread includes deployed reserves and LST snapshots include the fee collector. Successful calls reconcile quote, input debit, maximum, output, share issue/burn, and prepaid refunds. LST share issuance includes its unchanged fee policy. The constant-product zap paths retain their existing payout rounding.

Final scanner command `bash scripts/apex_bare_expectrevert_scan.sh --check` exited **1**. Its full output is byte-identical to the first scan: **317 existing bare expectations / 3,160 files**, zero sites in the seven selected files. Log: `.scratch/c06-caller-first/scanner-final.log`. No test was weakened or modified to mask these unrelated findings.

Final `git diff --check` passed. Worktree status before/after is saved in `.scratch/c06-caller-first/status-before.txt` and `status-after.txt`. Comparing status entries adds exactly the seven authorized production files, seven existing test files, and this report; no prior entry was removed. No excluded production site was changed, no test file was created, and existing unrelated edits/deletions were preserved. No deployment, commit, or push was performed.
