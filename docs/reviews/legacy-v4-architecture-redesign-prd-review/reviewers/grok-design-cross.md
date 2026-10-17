# Grok design cross-review — legacy V4 flatten

- **Date:** 2026-10-15
- **Peers:** `astra-design.md`, `minimax-design.md`, `kimi-design.md`. Untrusted. Not edited.
- **Closed design:** the component list and selector table below. An implementer does not pick another partition.

## Rejected

MiniMax's selector table is rejected. It keeps `UniswapV4StandardExchangeInExecutionDelegate` and `UniswapV4StandardExchangeOutExecutionDelegate`, and it keeps the deposit and zap-out delegate hops. The controlling draft requires both execution delegates removed and no replacement hop.

Astra's selector table is not adopted. It splits the current groups into sixteen family facets and adds `UniswapV4StandardExchangeLocalCreditRepo`. That repo is a new credit store. The owner did not ask for new economics.

Kimi's selector table is not adopted. It merges `exchangeInManyToOne` into the IN facet and `exchangeOutOneToMany` into the OUT facet. The controlling draft keeps the exact-in, exact-out, and dual-token entrypoints distinct.

## Sentence that replaces those tables

Delete both execution delegates and do not add another; install `unlockCallback` only on `UniswapV4StandardExchangeCallbackFacet`; every other installed selector keeps its current facet owner.

## Closed component list

| Path | One responsibility |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeConfig.sol` | Read the existing pool, token, manager, and oracle configuration. No new slot. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeAccounting.sol` | The one book and the one `_quoteZapOutAmount`. Sleeve, deployed amounts, and fees counted once. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeCustody.sol` | Pull, credit, named-holder burn, and refund. Calls the existing `_requireNotDisabled` before a money entry burns or moves tokens. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangePoolOps.sol` | The one swap, liquidity change, fee collect, deposit, and zap-out withdrawal body. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeReserve.sol` | Deadband and ratio-limited rebalance. No swap to force a ratio. An unexpected external failure propagates. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` | The one `unlockCallback` body. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` | Declares that one selector. |
| `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` | The existing SY errors, signatures unchanged. |

Delete `UniswapV4StandardExchangeInExecutionDelegate.sol`, `UniswapV4StandardExchangeOutExecutionDelegate.sol`, `UniswapV4StandardExchangeCommon.sol`, `UniswapV4StandardExchangeInBase.sol`, `UniswapV4StandardExchangeOutBase.sol`, and `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` after those moves. Other families change only the import. Do not redesign V3, hookless, or Pons.

## Closed selector table

Shared facets stay the owners of their current `facetFuncs`: `ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`, `MultiAssetBasicVaultFacet`, and `MultiAssetStandardVaultFacet`.

| Selector | Owner |
|---|---|
| `IUnlockCallback.unlockCallback` | `UniswapV4StandardExchangeCallbackFacet` |
| `IStandardExchangeIn.exchangeIn` | `UniswapV4StandardExchangeInFacet` |
| `IStandardizedYield.deposit` | `UniswapV4StandardExchangeInFacet` |
| `IStandardizedYield.redeem` | `UniswapV4StandardExchangeInFacet` |
| `IStandardizedYield.rewardIndexesCurrent` | `UniswapV4StandardExchangeInFacet` |
| `IStandardizedYield.claimRewards` | `UniswapV4StandardExchangeInFacet` |
| `IStandardExchangeTransitionQuote.quoteAssets` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeTransitionQuote.quoteShareBalance` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeTransitionQuote.quoteTransition` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeExternalQuote.quoteExternalExchange` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeTransitionQuote.quoteTotalSupply` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeExternalQuote.quoteExternalDeposit` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeIn.previewExchangeIn` | `UniswapV4StandardExchangeInMultiQueryFacet` |
| `IStandardExchangeInMulti.previewExchangeInManyToOne` | `UniswapV4StandardExchangeInMultiQueryFacet` |
| `IStandardExchangeInMulti.exchangeInManyToOne` | `UniswapV4StandardExchangeInMultiFacet` |
| `IStandardExchangeOut.exchangeOut` | `UniswapV4StandardExchangeOutFacet` |
| `IStandardExchangeOut.previewExchangeOut` | `UniswapV4StandardExchangeOutQueryFacet` |
| `IStandardExchangeTransitionQuote.quoteState` | `UniswapV4StandardExchangeOutQueryFacet` |
| `IStandardExchangeOutMulti.exchangeOutOneToMany` | `UniswapV4StandardExchangeOutMultiFacet` |
| `IStandardExchangeOutMulti.previewExchangeOutOneToMany` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.exchangeRate` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.yieldToken` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.assetInfo` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.getTokensIn` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.getTokensOut` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.isValidTokenIn` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.isValidTokenOut` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.previewDeposit` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.previewRedeem` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.getRewardTokens` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.accruedRewards` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IStandardizedYield.rewardIndexesStored` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.canOpenPoolManagerUnlock` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.localReserve` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.deployedReserve` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.targetLiquidReservePercentage` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.actualLiquidReservePercentage` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.rebalanceLiquidReserve` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangeLiquidReserve.twapOracle` | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangePositionImport.importPosition` | `UniswapV4StandardExchangePositionImportFacet` |

SY `deposit` and `redeem` call `_requireNotDisabled` before burn or movement. That is the only added check. No selector in this table is owned twice.

I did not run Forge.
