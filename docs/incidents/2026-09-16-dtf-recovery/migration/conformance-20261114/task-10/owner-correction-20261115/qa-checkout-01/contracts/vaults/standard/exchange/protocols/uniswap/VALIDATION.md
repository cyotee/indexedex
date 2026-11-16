# FullSpread implementation validation

Date: 2026-09-16. Local hermetic fixtures; no live transactions.

**654 passed, 0 failed, 0 skipped, across 49 suites.** This is the final FullSpread artifact-build/test gate, including the named-facet ownership controls. Exit status: **0**.

- Fuzz tests use **128 runs**. Each V3/V4 invariant campaign completed **64 × 96 = 6,144 operations**, totaling **12,288 operations**, with zero unexpected reverts. Six funded/stateful operations retain ghost supply and custody reconciliation.
- Solidity **0.8.35**, optimizer runs **1**, default hermetic profile, **no viaIR**. Artifact build precedes test execution. Forge ran outside the macOS sandbox because its system-proxy discovery crashed inside it; no fork or RPC was used.
- All **26** deployed facets/delegates/packages fit **24,576 bytes**. Largest: **UniswapV3FullSpreadStandardExchangeVaultInQueryFacet, 24,099 bytes**. No D25 split was necessary. [VALIDATED_ARTIFACTS.json](VALIDATED_ARTIFACTS.json) records sizes and SHA-256 over each unlinked runtime object string including `0x`.
- All **96** preserved-source hashes match. The preserved manifest/build-context files remain byte-identical to the execution baseline. Preserved-baseline test files, storage-slot literals, and Repo struct field ordering are unchanged. All 69 source-map keys are retained with valid FullSpread targets.

[REGRESSION_RESULTS.txt](REGRESSION_RESULTS.txt) records the exact command, artifact build, test command, and complete final output. The working-tree implementation is based on `ee7827f137e2a4d7d9a8fee65902f9ba930819bc`; it has not been committed or deployed. Production-source fingerprint: `c9daacfcc2e45ded8c47124373254928dd668b1611e1851204e695c74eca3b14`. Test-source fingerprint: `468ebea45af71dc6e260907754e738ce4e74966f8d48b91093fa51023b811cbb`. Each fingerprint is SHA-256 over path-sorted lines `<file SHA-256>  <repository-relative path>\n`; production covers the shared CP file and all V3/V4 Solidity sources, and tests cover all Solidity files under the feature test tree.

FullSpread scope includes Native SY on the vault itself, local production registry deployments, V3 bound-pool locks and V4 outer unlock sessions. It excludes DETF, Pendle market/external SY wrappers, arbitrary consuming hooks, and live-instance coverage. Old vaults are not deprecated or upgraded here. **CP-09 production consuming-hook integration remains open. CP-07 historical Robinhood transactions were not replayed.** No repository-wide PR gate or live deployment is claimed.

Reproduce the final artifact-aware command from the repository root:

```python
from pathlib import Path
import subprocess
base = Path("contracts/vaults/standard/exchange/protocols/uniswap")
sources = [str(base / "StandardExchangeConstantProduct.sol")]
for family in ("v3", "v4"):
    sources += sorted(str(p) for p in (base / family).rglob("*.sol"))
subprocess.run([
    "python3", "scripts/forge-artifacts.py", "test", *sources,
    "--test-root", "test/foundry/spec/vaults/standard/exchange/protocols/uniswap",
    "--", "--fuzz-runs", "128",
], check=True)
```

The final expansion found and fixed missing reserve booking on no-movement rebalance paths, including V4 fee collection within the target tolerance. FullSpread pulls preserve propagated token callback errors through Crane's address-call helper while retaining optional ERC-20 return validation and exact balance-delta checks. Shared transfer/SY helpers remain unchanged.

The historical section below preserves the earlier V2 results. Its preparation/binding tests and counts are **not FullSpread evidence or current integration guidance**. Current push usage is transfer to the vault followed by `pretransferred=true`; no preparation call exists.

## FullSpread acceptance map

Paths below are relative to `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`. `adversarial/StandardExchangeFullSpreadAdversarialBehavior.sol` runs on independent V3, V4 ERC-20 and V4 native/WETH registry proxies. Family-specific imports are in the retained release suites. All mapped runtime controls passed the final gate recorded above.

| Plan criteria | Implementation / executable controls |
|---|---|
| AC01–04 | Shared `StandardExchangeConstantProduct._minimumLiquidity/_initialShares`; `test_A0_dustFirstMint_reverts`, decimal boundary cases, V3 `test_A0_importBelowFloor_previewAndExecutionRollback`, V4 `test_A0_importBelowFloor_rollsBack`; real principal/fee imports assert independently collected entitlement. |
| AC05–11 | `test_A0_residualDeadShares_firstMinterNotWhole`, `test_A0_minimumPlusOne_previewAndExecution_*`, `test_A0_dustFirstMint_thenDonate_victimJoin_attackerCannotTakeHalf`, existing multi-join/invalid activation suites. |
| AC12–14 | Both Common `_syncVaultReserves` write the three diamond ERC-20 balances; `_totalVaultReservesForShareMath` retains live inventory/fees. `test_I_reserveOfTokenWrittenAfterRebalanceAndSwap`, E6 postconditions, fee/import/native release routes and invariant custody accounting. |
| AC15–16 | `test_pullDualExit_maxAllowanceAndBalance_idle/blocked`: finite-max pull/refund, insufficient allowance, insufficient balance, direct single-output burn with zero allowance; existing token exact-output route controls retain protocol-specific pull sizes. |
| AC17–22 | Exact delivery captured at entry; `test_I1_*`, `test_I2_*`, `test_I3_*`, and E6 route matrices; `test_proxyRemovedPreparationSurface`. |
| AC23–26 | `test_nativeSYCallerRedemptionNeedsNoAllowance`, `test_nativeSYInternalHolderBurnAndInsufficientBalance`, `test_nativeSYRequestedRecipientAndOrdinaryCallerDenied`, `test_nativeSYInternalMinimumRollbackAndContextRestored`, `test_SYFailureRollsBackAndCanRetry`. Shared Native SY implementation remains untouched. |
| AC27–35 | `test_I_routerTransferFromUserToVault`, `test_I1_*`, `test_I2_*`, `test_I3_*`, `test_L1_poolTradeThenFalsePretransfer_noCredit`, `test_I_reserveOfTokenWrittenAfterRebalanceAndSwap`; K1 disposition is explicit in suite NatSpec. |
| AC36–39 | V4 imported-increase functions removed; `test_M3_noImportedIncrease_permit2AllowanceToPositionManagerStaysZero` uses the actual PositionManager and Permit2 after import and rebalance, checks ERC-20 allowances and empty NFT custody. |
| AC40–47 | `test_F5_rebalancePaysCallerNothing`, `test_H_lockedExitAfterPermissionlessRebalance`, `test_H_lockedExit_onePercentOfSupply`, `test_H_zeroSleeveCanBlockLockedExit`, `test_H_positiveSleeveInsufficientCapacity_rollsBack`; permissionless/zero-target NatSpec in each LiquidReserveTarget. |
| AC48–49 | `test_L2_FoT_forbidden` enables fees after real external pool seeding but before first join; retained `test_feeOnTransferInputRejectedAndRolledBack`. |
| AC50–54 | Dedicated adversarial bases/suites; `test_C1_nestedMoneyPaths_recordedAndPropagating`, J1/J2/J3, `test_L3_spotSkew_noUnfundedMint`, `test_CROPS_disableInboundStillAllowsExitAndSY`; explicit deferred catalog IDs in shared NatSpec. |
| AC55–57 | Migrated remediation/release/invariant calls use transfer then push; legacy selector loupe/unsupported ERC-165/exact `Proxy.NoTargetFor` test. Preserved targets/assertions retained. |
| AC58–63 | E6 matrix covers token exact-output, share zap-out, dual exit, delivery equal to used/between used and max/at max/above max, short input, next unfunded claim, separate refund/output recipients, both idle and blocked share paths. |
| AC64–65 | V3 empty NFT liquidity/owed/ownership/approval assertions and `test_import_emptyNft_originalOwnerCannotCollect`; exact NPM authorization revert and unchanged vault custody. |
| AC66–70 | In-place component/TestBase/test rename, unchanged storage slots, FullSpread-only name salts; both `DFPkg_Deploy` suites assert actual factory/registry call arguments for all 26 deployed artifacts. |
| AC71–73 | README, this document, source map and final runtime/regression evidence; historical V2 preparation results are explicitly historical. |
| AC74 | Conditional split only if a deployed runtime exceeds 24,576 bytes; current size gate determines applicability. |
| AC75–76 | Final 96-file hash gate, unchanged preserved manifest/build context, and recorded artifact-aware full feature command. |

### Product selector calls (J3)

J1 independently reads compiled Target method identifiers and matches each to its named owning facet and that facet's declaration. Inherited Common callbacks are owned by InFacet; Common pool-state/TWAP views are owned by LiquidReserveFacet, so repeated inherited ABI entries do not produce duplicate diamond cuts. J2 checks every Target selector on the registry proxy. J3 exercises query and SY selectors in `test_J3_queryAndNativeSYProductSelectors`, funded single routes in `test_J3_proxyFundedMoneyPathsAndRemovedPrepare`, and dual routes in A0/E6. `quoteState`, every transition quote, reserve/metadata/reward/token-validity view, SY deposit/redeem and rebalance are called through the proxy. Family release import tests exercise import and V3 import preview. Funded protocol mint/swap/settlement operations exercise authenticated V3 callbacks and V4 `unlockCallback`. The deleted preparation selector has its separate exact routing-error negative.

# Historical V2 implementation validation

Date: 2026-09-15. Local hermetic fixtures; no live transactions.

## Result

**419 passed, 0 failed, 0 skipped, across 46 suites.** This expands the initial 86-test remediation run with feature suites, additional regressions, mixed-decimal cases, and stateful campaigns.

- Fuzz cases: **128 runs per fuzz test**; Foundry also replays cached counterexamples where present.
- Stateful campaigns: **64 runs × 96 operations for each of V3 and V4**, totaling **12,288 operations**. Unexpected handler reverts fail the campaign. Each operation probes both raw and prepared zero-delivery claims for both tokens; ghost accounting reconciles issued/burned shares and all asset custody. Deterministic sequences ensure every handler is exercised.
- Solidity **0.8.35**, optimizer runs **1**, **no viaIR**, repository default hermetic profile.
- **26** facet/delegate/package runtimes fit EIP-170; largest **23,737 bytes**. [VALIDATED_ARTIFACTS.json](VALIDATED_ARTIFACTS.json) records sizes and SHA-256 of the exact unlinked runtime object strings, including their `0x` prefix.
- All **96** hashes in [PRESERVED_SOURCE_SHA256.json](PRESERVED_SOURCE_SHA256.json) still match. Original implementations and their tests remain in place.

[REGRESSION_RESULTS.txt](REGRESSION_RESULTS.txt) contains the test runner output. The [README](README.md#validation-scope) records the complete build-before-test command. Forge required execution outside the macOS sandbox because system-proxy discovery crashed inside it; tests used local protocol deployments and no RPC. No unrelated monorepo suite or live-chain replay is included in this count.

## Suites and independent controls

Tests live under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`:

| Directory / suite | Evidence |
|---|---|
| `remediation/*PreservedBaseline*` | Real old registry packages mint unfunded shares after trades in both directions, then redeem real assets. A no-movement control rejects the same claim. The old locked exit quotes approximately 100 for a tenth of the `(1000,1000)` book; the paired new test quotes approximately 190. |
| `remediation/StandardExchangeDeliveryBehavior.sol` | Shared public-route assertions run on V3, V4 ERC20 and V4 native currency/WETH. Exact delivery, caller/calldata binding, donations, missing/short/excess delivery, replay, all input/output modes, refunds, locks, FoT rejection and rollback. |
| `remediation/StandardExchangeReleaseBehavior.sol` | SY own-share and prepared internal redemption; donated-share isolation; callback attacks against preparation, exchange and SY; permit replay/allowance consumption; disabled vault/package exits; malformed preparations; sleeve ratios; every compiled Target ABI selector installed on the actual registry proxy. |
| `remediation/StandardExchangeConstantProduct.t.sol` | Independently worked swap-plus-mint and burn-plus-swap references, limiting-side dual mint, surplus donations, inverse minimality, dust, empty backing, exhaustion and >256-bit reserve products. |
| `release/v3/` | Real V3 pool, NPM imports, fees, full-range placement, sleeve rebalance, routes, limits, previews, projected transitions, multi-input/output, registry metadata, and Crane facet behavior checks. Mixed-decimal pools use whole-token price parity for 6/18, 9/18 and 6/6 assets. |
| `release/v4/` | Real PoolManager and PositionManager, ERC20/native settlement, imports including earned fees and ownership/minimum failures, full-range placement, fees, sleeve rebalance, routes, limits, transition quotes, TWAP writes/failure handling, multi-input/output, registry and facet declarations. Four decimal fixture variants include 6/18, 18/6, 9/18 and both-six-decimal assets. |
| `release/sy/` | Native SY metadata, allowance-free caller redemption, fresh internal share delivery, slippage rollback, rewards views, and locked-pool use. |
| `invariants/` | Real deployments, separate funded trader, six stateful operations: deposit, withdrawal, market trade, donation, rebalance, and sleeve configuration. The attacker owns no input tokens. All successful supply changes have an identified funding/burn operation. |

Feature suites were ported to the distinct V2 packages. At that historical revision, their legitimate push calls prepared exact inputs. Blocked withdrawal expectations use an independent proportional-burn-plus-swap reference, not the new production math helper. Existing old-version test files were not edited.

The SUT vaults, manager, registry, fee oracle, facets, pools and position managers are real. External helper contracts supply tokens, protocol callbacks, NFT metadata, and an intentionally reverting advisory TWAP dependency. Constructor-error tests inspect actual package creation-code reverts; all successful vault deployment uses the manager registry.

## Shared pretransfer acceptance matrix

| Gate | Concrete coverage |
|---|---|
| PT-01 | Old/new price-movement regressions for both protocols, with actual redeemable baseline profit and zero new-version claims. |
| PT-02 | Both movement/input directions, bounded trade-size fuzzing, imported-position probes, and 2%/20%/50%/100% sleeve choices. Imported probes run on the new packages; old profitable reproduction uses ordinary positions. |
| PT-03 | Old no-movement control, new no-position/donation control, and honest pull/prepared funding after trades. |
| PT-04 | Exact-in/out asset swaps, single/multi joins, share withdrawals and two-token exits; execution through installed proxies/delegates. |
| PT-05 | Malformed/zero/short/excess input, replay, donor balances, share refunds, recipient/caller/calldata binding, partial-failure retry. |
| PT-06 | Earned fees, import, collection through public operations, add/remove rebalance, price movement and native settlement; pending funding blocks interleaved rebalance. |
| PT-07 | Real V3 flash locks and V4 outer unlock sessions; valid funded callbacks plus preparation/exchange/SY callback attacks. |
| PT-08 | Both stateful campaigns described above, including collection through rebalance/deposits/withdrawals. |
| PT-09 | Decimal fixtures, dust/empty backing, exhausted reserves, integer inverse minimality, large products and atomic failures. Fuzz domains are bounded, not exhaustive proofs over uint256. |
| PT-10 | Shared behavior and stateful assertions on both families, independent math examples, and family-specific fee/position tests. |
| PT-11 | Crane declaration controls, registry metadata, all Target ABI selectors on the proxy, exact public routes, preserved hashes and refreshed artifacts. |

## Constant-product acceptance and remaining boundaries

| Gates | Evidence / boundary |
|---|---|
| CP-01–03 | Preserved hashes and distinct artifacts; two-token activation/donation cases; proportional and limiting-side issuance. |
| CP-04–06 | Independent zero-fee example, skew fuzzing, fee-bearing real-pool exits, exact-output minimality and rollback, large-number and near-empty pure math. |
| CP-07 | Reconstructed hermetic accounting examples and old/new locked-exit comparison. **No exact replay of the historical user's transaction or intervening chain state.** |
| CP-08 | Same/opposite-token round trips, projected sequences, separately funded market trades, stateful deposits/withdrawals and explicit donor/incumbent accounting. These are bounded campaigns, not an exhaustive economic proof. |
| CP-09 | Real pool-session callers and SY routes are covered. **A release-specific production consuming hook/router integration remains open.** The historical V2 implementation required preparation changes; FullSpread restores transfer-then-call push. Consumers must not be repointed automatically. |
| CP-10–11 | Sleeve choices, public fee collection/rebalance, complete-book transitions, quote/execute parity, refunds, native SY and invalid routes. |
| CP-12–14 | Decimal/native/import/full-range/rounding tests; callback and permit negatives; complete deployed Target surface. Tick walks are bounded, not every possible tick. |
| CP-15 | Local vault/package disable blocks inbound operations and preserves withdrawals. No deployed old-instance control was exercised. |
| CP-16–17 | Shared PT matrix and independently deployed V3/V4 fixtures above. |

These tests provide reproducible regression and feature evidence. They do not certify arbitrary existing DETF, Pendle, router, or hook compositions, and do not replace review of the new implementation or deployment-specific integration testing.

## Fixes exposed by this expansion

The broader suites found two new-version integration issues, fixed in this change:

1. SY redemption now validates a fresh transfer of the caller's own shares, or a prepared internal-balance redemption, through the common delivery path. Existing donated shares remain unclaimable.
2. New vault/package disable controls preserve share withdrawals, including prepared exact-output exits, while continuing to gate inbound operations.

Both fixes apply only to the new V2 trees and have direct regression coverage.
