# Grok plan — legacy V4 ERC-5115

- **Date:** 2026-10-15
- **PRD:** `docs/reviews/legacy-v4-erc5115-interface/REMEDIATION_PRD.md`, read in full.
- **Interface:** `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`, read in full.
- **Choice:** No choice remains.

Do not split facets. Do not edit `contracts/vaults/standard/sy/` or the vendored Pendle interface. Do not edit V3, hookless, Pons, or any other family's yield target. Do not create a parallel execution class. Do not add `LocalCreditLib.requirePretransferCaller` to the token deposit path.

## Order

| Step | Work |
|---|---|
| 1 | Rewrite the existing yield target. |
| 2 | Rewrite the IN facet selector list. |
| 3 | Rewrite the OUT multi-query target, then its facet. |
| 4 | Replace the package interface id in place. |
| 5 | Retarget the six legacy V4 tests. |
| 6 | Refresh artifacts, measure the two named facets, and run those tests. |

## Step 1 — existing yield target

Edit `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` only. Stop inheriting `NativeStandardYieldExecutionTarget`. Keep the `UniswapV4StandardExchangeInTarget` inheritance. Do not add a second contract.

Implement `IERC5115_StandardizedYield.deposit` and `redeem` on this contract.

`redeem(address,uint256,address,uint256,bool)` keeps the current body, including `Config._requireNotDisabled()` and the existing internal-balance caller gate when `burnFromInternalBalance` is true. Keep `_redeemVaultHeld`, `_standardRoute`, and `_settleNamedHolder`.

Replace the four-argument payable `deposit` with:

`deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 minSharesOut, bool depositFromInternalBalance)`

It is not payable. Do not keep the `msg.value` check. Keep the receiver, amount, and token checks, and `Config._requireNotDisabled()` before movement.

- `depositFromInternalBalance == false`: use the current token pull, the existing `_exchangeIn` path with `pretransferred` false.
- `depositFromInternalBalance == true`: call `UniswapV4StandardExchangeCustody._secureTokenTransfer(IERC20(tokenIn), amountTokenToDeposit, true)`, then mint with the existing zap-in deposit using that returned amount. Do not pull a second time. Do not call `LocalCreditLib.requirePretransferCaller`.

Emit `IERC5115_StandardizedYield.Deposit` and `Redeem` with the current argument order. Do not emit `ClaimRewards`.

## Step 2 — IN facet

Edit `UniswapV4StandardExchangeInFacet.sol`. Remove the `NativeStandardYieldSelectors` import and the `_appendExecution` call. `facetFuncs` is exactly:

1. `IStandardExchangeIn.exchangeIn.selector`
2. `IERC5115_StandardizedYield.deposit.selector`
3. `IERC5115_StandardizedYield.redeem.selector`

Do not add `rewardIndexesCurrent` or `claimRewards`. Do not add an interface-id slot. The facet still declares only `IStandardExchangeIn`.

## Step 3 — query target, then facet

Edit `UniswapV4StandardExchangeOutMultiQueryTarget.sol`. Stop inheriting the Pendle preview and discovery targets. Delete `assetInfo`, `isValidTokenIn`, and `isValidTokenOut`. Keep `previewExchangeOutOneToMany`, `getTokensIn`, `getTokensOut`, `yieldToken` returning `address(0)`, and `exchangeRate` with the current zero-supply and book math.

Add `previewDeposit` and `previewRedeem` on this same contract. An invalid token returns 0. A valid token calls the current `Accounting._previewExchangeIn` route. Do not install those two functions on another facet.

Then edit `UniswapV4StandardExchangeOutMultiQueryFacet.sol`. Replace `type(IStandardizedYield).interfaceId` with `type(IERC5115_StandardizedYield).interfaceId`. Do not add or drop a slot. `facetFuncs` is exactly:

1. `IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector`
2. `IERC5115_StandardizedYield.exchangeRate.selector`
3. `IERC5115_StandardizedYield.yieldToken.selector`
4. `IERC5115_StandardizedYield.getTokensIn.selector`
5. `IERC5115_StandardizedYield.getTokensOut.selector`
6. `IERC5115_StandardizedYield.previewDeposit.selector`
7. `IERC5115_StandardizedYield.previewRedeem.selector`

Do not call `_appendQuery`.

## Step 4 — package id

In `UniswapV4StandardExchangeDFPkg.sol`, replace the Pendle import and `interfaces[13] = type(IStandardizedYield).interfaceId` with `type(IERC5115_StandardizedYield).interfaceId`. The array length stays 15. Do not change `facetCuts` or add a facet.

## Step 5 — tests

Retarget only these legacy V4 files from `IStandardizedYield` to `IERC5115_StandardizedYield`:

- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol`
- `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol`

A `deposit` call on this vault gains the bool. Use `false` for the current pull. Do not weaken holder, minimum, or no-self-call assertions. Delete assertions that call `assetInfo` or the removed reward selectors. Do not edit another family's tests.

## Step 6 — commands

From the repository root, default profile. Do not set `FOUNDRY_PROFILE=fork`. Do not enable `via_ir`.

```bash
python3 scripts/forge-artifacts.py plan \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol \
  -- -vv
```

After that refresh, report the runtime size of `UniswapV4StandardExchangeInFacet` and `UniswapV4StandardExchangeOutFacet`. If either exceeds 24,576 bytes, stop and report the size. Do not restore a delegate hop, a self-call, or `via_ir`. Do not split facets.

I did not run Forge.
