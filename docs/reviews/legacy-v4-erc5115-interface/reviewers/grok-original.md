# Grok notes — legacy V4 ERC-5115 interface

- **Date:** 2026-10-15
- **Question:** What must a PRD say to remove the Pendle SY surface from the legacy V4 vault and implement `IERC5115_StandardizedYield`?
- **Answer:** No owner question. Other families keep Pendle. Do not edit their shared implementations. Do not choose a later facet split. Measure size after this interface change.

## Closed rule

`NativeStandardYieldMoneyTarget`, `NativeStandardYieldRewardsTarget`, `NativeStandardYieldPreviewTarget`, `NativeStandardYieldDiscoveryTarget`, `NativeStandardYieldSelectors`, and `NativeStandardYieldTarget` serve other families, including V3 FullSpread, hookless, Pons, hooks, staking, and ERC-4626. Those files keep the Pendle `IStandardizedYield` signatures. The legacy V4 package stops advertising that interface and stops installing its selectors.

## Remove from the legacy V4 package

These selectors are installed now and are absent from `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`.

| Selector | Current owner | Implementation inherited from |
|---|---|---|
| `rewardIndexesCurrent()` | `UniswapV4StandardExchangeInFacet` through `NativeStandardYieldSelectors._appendExecution` | `NativeStandardYieldRewardsTarget` |
| `claimRewards(address)` | same IN facet | `NativeStandardYieldRewardsTarget` |
| `deposit(address,address,uint256,uint256)` payable | same IN facet | `NativeStandardYieldMoneyTarget.deposit` at `NativeStandardYieldTarget.sol:18-28`, overridden by `UniswapV4StandardYieldExecutionTarget.sol:17-25` |
| `assetInfo()` | `UniswapV4StandardExchangeOutMultiQueryFacet` through `_appendQuery` | `UniswapV4StandardExchangeOutMultiQueryTarget.sol:40` |
| `isValidTokenIn(address)` | same query facet | shared discovery target; V4 override at `UniswapV4StandardYieldExecutionTarget.sol:36-38` is not the installed query selector |
| `isValidTokenOut(address)` | same query facet | shared discovery target |
| `getRewardTokens()` | same query facet | shared preview/discovery target |
| `accruedRewards(address)` | same query facet | shared preview/discovery target |
| `rewardIndexesStored()` | same query facet | shared preview/discovery target |

Also remove `type(IStandardizedYield).interfaceId` from `UniswapV4StandardExchangeDFPkg.sol:162` and from `UniswapV4StandardExchangeOutMultiQueryFacet.sol:20`. Do not emit `IStandardizedYield.ClaimRewards` from this package.

## Add or change

| Selector | Change | Owner |
|---|---|---|
| `deposit(address,address,uint256,uint256,bool)` | New selector. Not payable. The fifth argument is `depositFromInternalBalance`. | `UniswapV4StandardExchangeInFacet` declares it. `UniswapV4StandardYieldExecutionTarget` implements it. |
| `redeem(address,uint256,address,uint256,bool)` | Same parameter types as the current Pendle redeem. Keep the selector. Declare it from `IERC5115_StandardizedYield`, not `IStandardizedYield`. | Same IN facet and yield execution target. |
| `exchangeRate()` | Same signature. Declare it from `IERC5115_StandardizedYield`. | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| `yieldToken()` | Same signature. | same query facet and `UniswapV4StandardExchangeOutMultiQueryTarget.sol:36-38` |
| `getTokensIn()` | Same signature. | same query facet and target `:26-30` |
| `getTokensOut()` | Same signature. | same query facet and target `:32-34` |
| `previewDeposit(address,uint256)` | Same signature. | same query facet and its preview target |
| `previewRedeem(address,uint256)` | Same signature. | same query facet and its preview target |

`Deposit` and `Redeem` stay, with the same indexed fields. Emit them from the ERC-5115 interface. Do not add `name`, `symbol`, or `decimals` from this interface. Those functions are commented out in the ERC-5115 file and already belong to `ERC20Facet`.

## Behavior the implementer does not choose

- `depositFromInternalBalance == false` uses the current pull path. `true` uses the existing true-flag pretransfer credit path. Do not add a credit rule.
- `burnFromInternalBalance` keeps its current meaning: `true` burns vault-held shares after the existing caller check; `false` burns the original caller.
- `yieldToken()` keeps its current return, `address(0)`.
- The internal token check stays. It is not installed as `isValidTokenIn` or `isValidTokenOut`.
- The legacy V4 yield and query targets stop inheriting the shared Pendle money, rewards, and discovery contracts. They implement only the ERC-5115 functions above, calling the current Config and Accounting reads. That is not a facet split.
- Do not edit `NativeStandardYieldSelectors.sol`. The two legacy V4 facets list their own selectors.
- Do not move `exchangeIn` or `previewExchangeOutOneToMany`.
- Measure every deployed legacy V4 facet after this change. A size result does not authorize a facet split in this item.

I did not run Forge.
