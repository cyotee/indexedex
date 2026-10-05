# Orbital raw-liquidity validation

**Date:** 2026-10-04  
**Labels:** bounded correction implemented; OD-1 unresolved; OD-2 deferred; not full release acceptance.

## Requirement map

| ID | Result |
|---|---|
| A1 | Independent raw floor reference in `rawLiquidity/OrbitalRawLiquidityRef.sol`. Proxy subsequent full-book join at rate 1.5e18 matches that reference, not a second call to the hook helper. 0–3 buffered-leg matrix and mixed decimals were not rerun as a full decimal book. |
| A2 | Ceil-backing unit vector (`S=10,B=3,C=1` mints 3; floor pull is 0 and does not back; ceil required is 1 and backs). Proxy settlement checks `delivered * S >= minted * incumbent` after the join. Overflowing `rawLegFloorShares` reverts via an external call. |
| A3 | B6 flexible share deposit/withdraw passed, including three-leg share input and raw-leg share-flag revert. Zero-conversion is no ownership credit in `previewBufferSharesIn` / `_rawOffer`. Refund path unchanged. |
| A4 | Full-book mint no longer reads the rate for the ratio. Rated `effectiveReserve` remains `shares * rate / 1e18`. A rate-only two-hook comparison was not run. Default dex fee still falls back to 5e16 when the per-vault fee is set to 0, so fee-on supply can still move `S`. |
| A5 | Zap terminal mint uses projected post-swap raw shares / raw reserves. ZapIn preview==exec passed (8 tests), including fee and asymmetric cases. Swap split stays rated. |
| A6 | Liquidity remove preview==exec, swap preview==exec, and fee growth-on-add passed. Proportional payout formula was not changed. |
| A7 | Fees on and off, provider revert, zero rate, and short return roll back LP, token1, supply, and raw reserve. No outage success was invented. |
| A8 | OD-1 note written. Partial formulas were not changed. |
| A9 | Production TestBase. No SUT mocks. Tallies below. Not a truncated green. |
| A10 | No matched pre-change gas denominator. Not accepted as a no-regression claim. Runtime sizes of changed facets fit 24,576. |

## Patch

Production allowlist only:

- `UniswapV4StandardExchangeOrbitalBufferHookMath.sol` — `rawLegFloorShares`, `rawRequiredInventory`, `rawInventoryBacks`, `rawFullBookShares`. `fullBookUsedWad` unchanged.
- `UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol` — `previewBufferSharesIn`. Rated `previewBufferClaimIn` still substitutes face for swaps.
- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` — subsequent full-book and flexible full-book ownership; execute backing check. Inherited planned-zap settlement kept.
- `UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol` — terminal admission after rated `_depositSales` / `_depositOutputs`. Inherited `redeemShares` plumbing kept. `_claimIn` face substitution kept for the rated sale path.

No new external selector, storage, or ABI field. Weighted was not edited.

## Commands and tallies

Compiler: solc 0.8.35, optimizer runs 1, `via_ir = false`. HEAD `92cdf89a`. Crane `b35609951`.

The short artifact id `UniswapV3Factory.sol:UniswapV3Factory` matches two sources. Both call sites now use `lib/crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol:UniswapV3Factory`. The planner then exits 0.

| Suite | Result |
|---|---|
| RawLiquidityConversions | 4 passed after the overflow case was moved to an external call |
| RawLiquidityPolicy | 2 passed (`test_subsequentFullBook_matchesRawReference_andBacks` gas 1,436,153; zap preview==exec gas 2,907,980) |
| RawLiquidityRateFailure | 4 passed |
| Liquidity | 11 passed. Subsequent full-book preview==exec gas 1,714,265 |
| ZapIn | 8 passed. `test_depositSingle_previewEqualsExec` gas 3,596,153 |
| B6 flexible | 6 passed |
| Preview | 2 passed |
| Fees | 3 passed |
| Buffer | 1 passed |
| Swap | 6 passed |
| Orbital FullSpread matrix | 10 passed, including `test_row_previewMatchesExecution` gas 940,674,090 |
| Weighted FullSpread matrix (unchanged control) | 13 passed |
| FullSpreadConsumerBurnGates | the four gate contracts in the tail passed (hookless and pons, primary and fallback). Not a claim that every contract in that file was separately counted beyond the run summary |
| V4FundedBindings `OrbitalV4PositionFundedBindingTest` | 8 passed, 4 failed |

Required command (orbital directory, V4FundedBindings, FullSpreadConsumerBurnGates, Weighted FullSpread control), after the factory-path fix and after removing the zap live backing check:

```text
Ran 76 test suites in 433.72s: 665 passed, 4 failed, 0 skipped (669 total). Exit 1.
```

The 4 failures are only `OrbitalV4PositionFundedBindingTest`. Weighted FullSpread control 13 passed. The four FullSpread consumer gate contracts passed. Fee-bearing matrix rows `CommonBufferMultiVaultWeightedPool` and `MultiPairStandardExchangeBufferPool` `test_row_previewMatchesExecution` passed (gas 96,152,183 and 138,842,390) after the zap execute backing check was removed. That check false-failed those rows by 24 share-wei on a live fee-bearing nested pool. A 1024-share quote cushion did not close the gap. Direct and flexible full-book execute still call `_requireRawBacking`.

Decimal books, invariant suites, and non-FullSpread SeMatrix rows were not selected. Deprecated Slipstream rows were not broadened back into scope.

## Runtime sizes (deployed bytecode, limit 24,576)

| Artifact | Bytes | Headroom |
|---|---:|---:|
| HooksFacet | 24,210 | 366 |
| DepositFacet | 22,401 | 2,175 |
| SeFacet | 22,269 | 2,307 |
| WithdrawFacet | 20,600 | 3,976 |
| DFPkg | 20,574 | 4,002 |
| DepositFlexibleFacet | 20,100 | 4,476 |
| DepositQueryFacet | 17,553 | 7,023 |
| DepositZapFacet | 17,386 | 7,190 |

Libraries are linked into those facets. Standalone library artifacts are smaller and are not the 24,576 gate.

## Gas

No matched before/after. The worktree was already dirty, including the zap settlement edit, and a pre-change suite was not completed. Post-change figures above are harness `gas` reports, not cold/warm transaction measurements and not a waiver of A10.

31M call stipends were not raised. The failing binding tests report harness gas of 199,380,647 to 215,967,587 and revert. That is not a stipend increase.

## Binding failure handoff (not fixed here)

`test_bindingV4LpPaymentKeepsBufferAssetsAndFitsChainGasBudget` reverts inside the concurrent Hookless analytic solver, not in the raw-ownership helper:

```text
UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath._candidate
  <- AnalyticComposition._plan
  <- TransitionPlanner._composition
  <- InQueryFacet.quoteTransition
  <- ExitQuoteLib.planDeposit
  <- joinSingleAssetExactIn
```

The parent reports empty `EvmError: Revert`. A `-vvvv` trace of `test_bindingPositionShareGasCounterexample` shows the inner frame is out of gas inside `AnalyticSwapMath._candidate` (Foundry prints that as `unrecognized function selector` on the library delegatecall). The same cluster fails `test_bindingPositionShareGasCounterexample`, `test_bindingPositionShareInputsRedeemThroughEveryNativeSyOutput`, and `testFuzz_bindingPositionShareDepositWithinChainGasLimit` (counterexample `amount = 79228162514264337593543950333`, `second = true`).

Swallowing the quote revert in `planDeposit` does not make these tests pass. Execution then fails in `ClaimLib.effectiveNative` because `StandardExchangeRateProviderFacet.getRate` calls `previewExchangeIn`, which hits the same solver out-of-gas and returns 0. Fail-closed rate reading turns that into `RateProviderFailed()`. That catch was reverted. This task does not edit the Hookless solver. The Orbital FullSpread matrix itself passed.

## Preserved

Rated swap split, sphere NAV partial pricing, fee mint, radius, L2, and reserve sync. Zero face substitution remains on rated swap helpers. First mint is still the effective-sum path. No OD-2 recovery.

## Remaining

- Owner decision on OD-1 before any partial-price edit.
- OD-2 stays fail-closed.
- Hookless analytic revert in the four binding tests.
- Matched gas denominator, if a clean pre-change tree is still required for A10.
- Decimal-book rerun was not part of the selected tally.
