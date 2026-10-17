# Grok questions — rewritten legacy V4 redesign

- **Date:** 2026-10-15
- **Document:** `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md`, read in full.
- **Question:** Does this design still need an owner decision before an implementation plan?
- **Answer:** No owner question remains.

D1 through D9 are marked decided. The component paths, selector owners, facet-cut order, and deletion list are named. The stored-reserve credit residual is explicitly out of this item. Do not reopen it.

## Mechanical closures a later plan must state

- Name the twelve SY selectors that stay on `UniswapV4StandardExchangeOutMultiQueryFacet`: `exchangeRate`, `yieldToken`, `assetInfo`, `getTokensIn`, `getTokensOut`, `isValidTokenIn`, `isValidTokenOut`, `previewDeposit`, `previewRedeem`, `getRewardTokens`, `accruedRewards`, and `rewardIndexesStored`.
- Name the seven reserve selectors that stay on `UniswapV4StandardExchangeLiquidReserveFacet`: `canOpenPoolManagerUnlock`, `localReserve`, `deployedReserve`, `targetLiquidReservePercentage`, `actualLiquidReservePercentage`, `rebalanceLiquidReserve`, and `twapOracle`.
- Move bodies into the named libraries before deleting `Common`, `InBase`, and `OutBase`. Rewire deposit, share exit, yield redemption, and `exchangeOut` off both delegates before deleting those delegates.
- Deposit calls the existing `_executeZapInDeposit`. Share exit and yield redemption call the existing `_executeZapOutExactIn`. Yield redemption then calls `_pokeBoundPoolTwap`. The OUT withdrawal body moves once from `executeZapOutWithdrawal` into `UniswapV4StandardExchangePoolOps`.
- Search again for importers of `UniswapV4StandardExchangeOutTarget.sol` and for consumers of each quote helper. Delete only when the search shows none. If a consumer exists, stop and report it.
- Add `UniswapV4StandardExchangeCallbackFacet` to `PkgInit` and `facetCuts` in the order the PRD names. Remove both delegate constructor arguments and both delegate factory deployments. Do not add another family facet.
- Each remaining family facet keeps its current target file, rewritten to call the named libraries and not to inherit `Common`, `InBase`, or `OutBase`. That is layout, not a new component.
- SY `deposit` and `redeem` call the existing `_requireNotDisabled` before burn or token movement. Do not add that check to a view selector.
- After artifact refresh, measure every deployed facet. Stop if any runtime exceeds 24,576 bytes. Record a miss of the 23,000-byte advisory target. Do not restore a hop, a self-call, or `via_ir`.
- Run the existing legacy V4 suites through the production TestBase. Do not add an economic assertion this PRD does not already state.

I did not run Forge.
