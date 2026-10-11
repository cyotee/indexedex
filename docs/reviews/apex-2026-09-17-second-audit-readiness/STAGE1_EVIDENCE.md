# Stage 1 evidence

## Owner acceptance recorded 2026-10-07

The owner explicitly confirmed Stage 1 is complete and directed execution of `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`. Stage-1 acceptance and Stage-2 launch authorization are established. Do not ask the owner to reconfirm them. The historical statements below that Stage 2 has not started describe the evidence-authoring session, not the current authorization. Stage-2 reviewers may inspect source with read-only shell tools and write their reports; no builds, tests or code fixes are authorized by that review request.

- **Date:** 2026-10-07
- **Tree:** `5709cb35` plus uncommitted stage-1 edits. This note is not a release identity.
- **Stage 1 passing is not audit submission.** Stage 2 has not started. No matrix row count is recorded here, because this session did not count one.

## Source map

The hookless and Pons-family FullSpread packages were not merged.

| Package | Source root | Outside-trade test |
| --- | --- | --- |
| V3 FullSpread | `contracts/vaults/standard/exchange/protocols/uniswap/v3/` | `test_outsidePoolTradeDoesNotRefreshVaultBook` in `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol` |
| V4 hookless FullSpread | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/` | same test name in `hookless/AttributionAndBooking.t.sol` |
| V4 Pons-family FullSpread | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/` | same test name in `ponsFamilyV2Hook/AttributionAndBooking.t.sol` |
| Wings | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` | same test name in `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` |

`UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` remains a local-reserve supplement. It is not the outside-trade proof.

## Production repairs

- Residual joins in `UniswapV4DetfCommon.sol` are hard calls. Book-and-wait remains only for a successful Standard Exchange preview of `0`. The `supportsInterface` probe was not edited.
- `ReceiptBackedERC4626Target.maxRedeem` is a share cap. `maxWithdraw` is `previewRedeem` of that cap.
- `StandardExchangeRateProviderFacet._getRate` no longer calls `quoteState` on an empty state. Caller-supplied `quoteRate` remains.

## Runs that passed

Commands used `python3 scripts/forge-artifacts.py test` with a named `--test-root` and `--match-test`. Compiler runs were not cancelled.

- Custody: `test_ADV_cannotBurnOtherHolderViaInternalSy`, `test_ADV03_reentrancyDuringDepositReverts`, `testFuzz_FUZZ02_exactOutMinimals`.
- Receipt cap, both families: `test_maxRedeem_fullBalancePayableAtNonIntegralRate`, `test_maxRedeem_capsWhenHeldReceiptsCannotPayFullBalance`, `test_maxRedeem_zeroPreviewIsNotAdvertised`.
- Rate provider: `test_emptyGetRate_ignoresQuoteStateFailure`, `test_failedCallerSnapshot_isNotReportedAsLiveRate`.
- Residual sweep: `test_residualSweep_nativeUnit`, `test_residualSweep_localRehearsalAmount`. The larger amount rolls back with `ZeroAmount()` and does not book a holder reserve.
- Outside-trade credit: the four tests named above.
- Rounding control `test_row_partialConsumption_bookedNotRefunded` on the simple-yield host for weighted, dual, constant-product, curve, balancer, orbital, and single. A dust rejection must be `ZeroAmount()` or `InsufficientTokenOut()`, or the same selector the preview returned. An arbitrary revert does not pass.
- The same test name on the ERC4626 host for constant-product, orbital, and single.
- Weighted FullSpread `test_row_ammCallerFundSeparation`.

No matrix row count is recorded. This session did not count one.

## Selector and size check

`python3 scripts/r12_selector_size_compare.py` wrote `selector-size-compare-stage1-current.json` in this directory and exited 0. It did not overwrite `docs/audits/apex-2026-09-17-evidence/selector-size-compare.json` or the baseline. No new compiler profile was added. The earlier compare files in this directory are stale.

The current summary is `compared` 540, `missingArtifacts` 0, `oversizeCount` 0, `selectorDiffCount` 52, `proxySelectorDiffCount` 13, `skippedStaleCount` 32. The 32 skipped rows are baseline entries whose source files no longer exist: the pre-split `UniswapV4FullSpreadStandardExchangeVault*` paths. The script no longer treats a deleted baseline source as a failure. A source that still exists with a missing or oversized artifact still fails the run. The hookless and Pons-family packages above replace that citation. They were not merged.

`ERC4626StandardExchangeInFacet` was 23632 bytes in the 2026-09-17 baseline and 24922 bytes before the split. The EIP-170 limit used by the script is 24576. `previewExchangeIn` now lives on `ERC4626StandardExchangeInFacetExt`. After that split the execution facet is 24009 bytes and the preview facet is 14815 bytes. The package installs both. `test_SE1_wrapExactIn_previewEqualsExecution_zeroFee` and `test_SE2_unwrapExactIn_previewEqualsExecution` passed. The post-split compare reports no oversized artifact.

Stage-1 size notes, not a certification:

- `StandardExchangeRateProviderFacet`: 3580 to 4288 bytes. Its method identifiers did not change.
- `UniswapV4DetfMaintenanceFacet`: 12959 to 14754 bytes. `joinResidualAtomic(address,uint256,bool)` is in the committed facet. Stage 1 changed the caller from `try/catch` to a hard call.
- `ReceiptBackedERC4626Facet`: 6980 bytes. It has no historical baseline row.

Nine selector diffs had no prior label. They were labeled only as added or removed versus the baseline in committed source, except the maintenance selector, whose caller this stage changed. Those labels do not certify an installed proxy cut.

## Still open

- The current selector and size run exited 0. Stage 1 is not audit submission.
- The bare-revert scanner includes the two custody files even without an APEX marker. Those two files have no bare `vm.expectRevert()`. The wider inventory still has pre-existing bare expectations, so `scripts/apex_bare_expectrevert_scan.sh --check` exits 1. That is not a clean inventory.
- Stage 2 has not started.
