# Grok design — legacy V4 flatten

- **Date:** 2026-10-15
- **Controlling direction:** `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md`, with the owner rulings in this request.
- **This is the design.** An implementer does not rename a component, move a selector, or keep a delegate.

Size does not decide the shape. 24,576 bytes is the hard runtime limit. 23,000 bytes is advisory: record a miss below the hard limit; exceeding 24,576 stops the work. Do not restore a hop, a self-call, or `via_ir` to get under either number.

## Successor components

Each file has one responsibility. Facets declare selectors only. They do not inherit `UniswapV4StandardExchangeCommon`, `UniswapV4StandardExchangeInBase`, or `UniswapV4StandardExchangeOutBase`. Query targets do not inherit execution targets.

| Path | Responsibility |
|---|---|
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeConfig.sol` | Read the already-initialized pool key, token faces, managers, and TWAP oracle. No new storage slot. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeAccounting.sol` | The one book and quote implementation: sleeve, exact deployed amounts, and earned fees counted once. The one `_quoteZapOutAmount`. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeCustody.sol` | Pull, credit, burn-by-holder, and refund. Calls the existing `_requireNotDisabled` before a money entry burns or moves tokens. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangePoolOps.sol` | The one swap, liquidity add/remove, fee collect, and zap-out withdrawal body. No installed callback. |
| `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeReserve.sol` | Deadband and ratio-limited rebalance. No swap to force a ratio. An unexpected external failure propagates. |
| `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` | The existing SY error declarations, signatures unchanged. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` | The one `unlockCallback` body. Validates the PoolManager caller and settles the decoded operation. |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` | Declares that one selector. |

The other current facet and target file names stay. Their bodies call the five internal libraries. They do not grow a second copy of a settlement function.

Existing repos stay the storage owners: `ERC20Repo`, `EIP712Repo`, `Permit2AwareRepo`, `StandardVaultRepo`, `MultiAssetBasicVaultRepo`, `VaultFeeOracleQueryAwareRepo`, `UniswapV4PoolManagerAwareRepo`, `UniswapV4PoolKeyAwareRepo`, `UniswapV4PositionRepo`, `UniswapV4TwapOracleAwareRepo`, and `WETHAwareRepo`. Do not add a family slot for a value those repos already store.

## Selector owners

One selector, one facet. Do not merge these groups. Do not split `exchangeIn` across facets. Shared facets are not redesigned.

| Selector | Owner |
|---|---|
| `IERC20Metadata.name` | `ERC20Facet` |
| `IERC20Metadata.symbol` | `ERC20Facet` |
| `IERC20Metadata.decimals` | `ERC20Facet` |
| `IERC20.totalSupply` | `ERC20Facet` |
| `IERC20.balanceOf` | `ERC20Facet` |
| `IERC20.allowance` | `ERC20Facet` |
| `IERC20.approve` | `ERC20Facet` |
| `IERC20.transfer` | `ERC20Facet` |
| `IERC20.transferFrom` | `ERC20Facet` |
| `IERC5267.eip712Domain` | `ERC5267Facet` |
| `IERC20Permit.permit` | `ERC2612Facet` |
| `IERC20Permit.nonces` | `ERC2612Facet` |
| `IERC20Permit.DOMAIN_SEPARATOR` | `ERC2612Facet` |
| `IBasicVault.vaultTokens` | `MultiAssetBasicVaultFacet` |
| `IBasicVault.reserveOfToken` | `MultiAssetBasicVaultFacet` |
| `IBasicVault.reserves` | `MultiAssetBasicVaultFacet` |
| `IStandardVault.vaultFeeTypeIds` | `MultiAssetStandardVaultFacet` |
| `IStandardVault.contentsId` | `MultiAssetStandardVaultFacet` |
| `IStandardVault.vaultTypes` | `MultiAssetStandardVaultFacet` |
| `IStandardVault.vaultConfig` | `MultiAssetStandardVaultFacet` |
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

`UniswapV4StandardExchangeDFPkg.facetCuts` installs those sixteen facets in this order: the five shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. No other family facet is added.

## Calls that replace the hops

- `exchangeIn` deposit calls the existing `_executeZapInDeposit`. It does not `delegatecall`.
- `exchangeIn` share exit keeps the current internal `_executeZapOutExactIn(..., address(this))`.
- Yield redemption keeps the current internal `_executeZapOutExactIn` and the following `_pokeBoundPoolTwap`.
- `exchangeOut` calls internal quote and withdrawal functions. It does not call `previewExchangeOut` on `address(this)`. The withdrawal body moves once from `UniswapV4StandardExchangeOutExecutionDelegate.executeZapOutWithdrawal` into `UniswapV4StandardExchangePoolOps`. Do not write a second copy.
- SY `deposit` and `redeem` call the existing `_requireNotDisabled` before burn or token movement. That is the REQ-V4-02 check. Do not import a V3 or FullSpread exemption. Do not add that check to a view selector.
- `rebalanceLiquidReserve` may no-op or partially adjust for deadband, rounding, or an insufficient deployable ratio. Any other external failure reverts the transaction. Do not add a catch-all.

Vault-held yield still passes `address(this)`. Ordinary yield still passes `msg.sender`. Public share exchange still burns the vault after the pull. The full-range managed book and the funded sleeve stay the asset model. Do not add a share token, a NAV formula, or a migration of existing instances.

## Keep, move, delete

**Keep, and do not redesign:** the five shared facets above, their repos, `UniswapV4StandardExchangeDFPkg` package identity, and the V3, hookless, and Pons trees.

**Move:** `unlockCallback` from `UniswapV4StandardExchangeInTarget` to the callback target. The zap-out withdrawal body from the OUT delegate to `UniswapV4StandardExchangePoolOps`. Common's quote, custody, pool, and reserve functions into the five internal libraries, one responsibility each. SY error declarations into `NativeStandardYieldErrors.sol` with the same signatures. Other families change only the import path from the deleted shim to `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol`.

**Delete:** `UniswapV4StandardExchangeInExecutionDelegate.sol`, `UniswapV4StandardExchangeOutExecutionDelegate.sol`, both delegate constructor arguments, `_delegateExecuteZapInDeposit`, `_delegateExecuteZapOutWithdrawal`, `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol`, `UniswapV4StandardExchangeCommon.sol` after the move, `UniswapV4StandardExchangeInBase.sol` after the move, `UniswapV4StandardExchangeOutBase.sol` after the move, `_deployExcessImported`, `_increaseImportedPositionCommon`, and `_increaseImportedPosition`. Delete family storage fields that only those three functions write. Do not delete the import decrease and collect used by `importPosition`. Do not delete a shared repo field.

`UniswapV4_Component_FactoryService.sol` drops the two delegate deployments and deploys `UniswapV4StandardExchangeCallbackFacet`. It does not deploy a replacement delegate.

I did not run Forge.
